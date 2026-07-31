from typing import Any, Dict, Optional

from app.services import embeddings, ingestion
from app.services.chroma_client import get_documents_collection

# Set to False once you're happy with the confidence numbers.
_CONFIDENCE_DEBUG = True


def _distance_to_confidence(distance: float) -> float:
    # Chroma's "cosine" space (see chroma_client.py — now set explicitly
    # instead of relying on the unstated "l2" default) returns
    # distance = 1 - cos_sim, range [0, 2]. So cos_sim = 1 - distance,
    # NOT 1 - distance/2 (that formula was only coincidentally correct
    # under the old, implicit "l2" default + normalized embeddings —
    # see CHANGES_V7.md for the derivation). If you ever change the
    # collection's hnsw:space again, this line needs to change with it.
    cos_sim = 1 - distance
    return max(0.0, min(1.0, cos_sim))


# Raw cosine similarity from this embedder (a MiniLM-class bi-encoder)
# rarely exceeds ~0.5-0.6 even for a genuinely correct, well-grounded
# match — averaging it directly and showing it as a percentage reads as
# "low confidence" for answers that are actually right.
#
# Rescale the raw average into a more representative 0-100% range using
# two anchors. These are hardcoded rather than pulled from .env — if you
# see confidence still looking off after testing a few real questions,
# adjust the two numbers directly below and re-run; the debug print two
# lines down shows you the raw number to tune against.
_LOW_ANCHOR = 0.10   # raw cos_sim treated as ~0% confidence
_HIGH_ANCHOR = 0.40  # raw cos_sim treated as ~100% confidence


def _rescale_confidence(raw: float) -> float:
    if _HIGH_ANCHOR <= _LOW_ANCHOR:
        return raw  # misconfigured anchors — fall back to raw rather than divide by zero
    scaled = (raw - _LOW_ANCHOR) / (_HIGH_ANCHOR - _LOW_ANCHOR)
    return max(0.0, min(1.0, scaled))


async def retrieve(
    query: str,
    equipment_id: Optional[str] = None,
    n_results: int = 8,
    top_k: int = 5,
    require_equipment_match: bool = False,
) -> Dict[str, Any]:
    collection = get_documents_collection()

    count = collection.count()
    if count == 0:
        return {
            "top": [],
            "context_block": "",
            "sources": [],
            "page_citations": [],
            "confidence": 0.0,
            "tags": set(),
        }

    query_vec = await embeddings.embed(query)

    results = collection.query(
        query_embeddings=[query_vec],
        n_results=min(n_results, count),
        include=["documents", "metadatas", "distances"],
    )

    docs = results["documents"][0]
    metas = results["metadatas"][0]
    dists = results["distances"][0]

    tags = set(tag.upper() for tag in ingestion.extract_equipment_tags(query))

    if equipment_id:
        tags.add(equipment_id.upper())

    ranked = list(zip(docs, metas, dists))

    if tags:
        matched = [
            item
            for item in ranked
            if item[1].get("equipment_id", "").upper() in tags
        ]

        if matched:
            ranked = matched

    top = ranked[:top_k]

    context_lines = []
    sources = []
    # New: structured (fileName, page) pairs alongside the human-readable
    # `sources` strings below — CitationChips (atlasai_app/lib/widgets/
    # citation_chips.dart) needs the page number as its own field to
    # build a clickable "[Page 14]" chip, not baked into a display string.
    page_citations = []

    for i, (doc_text, meta, _) in enumerate(top, start=1):
        context_lines.append(f"[{i}] {doc_text}")

        file_name = meta.get("file_name", "unknown")
        page = meta.get("page")
        sources.append(f"{file_name} (page {page if page is not None else '?'})")
        page_citations.append({"fileName": file_name, "page": page})

    scores = sorted(
        [_distance_to_confidence(d) for _, _, d in top],
        reverse=True,
    )

    # FIX: was a flat average of the top 3 scores. If the best chunk is
    # a strong, genuinely on-topic match but the 2nd/3rd are weaker
    # (common — top_k pulls in some marginal chunks as padding), a flat
    # average drags a good answer's confidence down to look like a bad
    # one. Weighting the best score more heavily is more representative
    # of "how good was the evidence this answer is actually grounded
    # in" than "how good was everything retrieved on average".
    #
    # Also added: an agreement term. Three consistently strong matches
    # (0.42, 0.41, 0.40) is a better signal than one strong match
    # surrounded by two irrelevant ones (0.42, 0.15, 0.12), even though
    # `best` is identical in both cases — agreement captures that
    # difference, `best` alone can't.
    if scores:
        best = scores[0]
        top3 = scores[:3]
        avg_top3 = sum(top3) / min(len(top3), 3)
        agreement = max(0.0, 1 - (max(top3) - min(top3)))
        raw_confidence = 0.7 * best + 0.2 * avg_top3 + 0.1 * agreement
    else:
        raw_confidence = 0.0
    confidence = _rescale_confidence(raw_confidence)

    # Always-on for now — watch your backend console while testing real
    # questions. If clearly-correct answers keep showing rescaled
    # confidence below ~50%, raise _HIGH_ANCHOR above; if clearly-wrong/
    # no-match questions still show above ~30%, raise _LOW_ANCHOR above.
    # Set _CONFIDENCE_DEBUG = False below once you're happy with it.
    if _CONFIDENCE_DEBUG:
        space = collection.metadata.get("hnsw:space") if collection.metadata else "l2 (Chroma default — no space set)"
        print(f"[confidence debug] space={space} raw_scores={scores} raw_confidence={raw_confidence:.3f} "
              f"-> rescaled={confidence:.3f} (anchors {_LOW_ANCHOR}-{_HIGH_ANCHOR})")

    return {
        "top": top,
        "context_block": "\n\n".join(context_lines),
        "sources": sources,
        "page_citations": page_citations,
        "confidence": round(confidence, 2),
        "tags": tags,
    }

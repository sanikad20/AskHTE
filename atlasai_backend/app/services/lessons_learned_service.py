"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Lessons-learned / historical-match service, adapted from AtlasAI's Day 5
"has something like this happened before" check. main.py calls this only
when a freshly ingested document classifies as doc_type == "incident" —
entity_extraction.classify_document_type() doesn't emit that label in the
HTE domain (it emits circular/gr/policy/notice/faq/form/general_document),
so this path is currently dormant here. Kept import-compatible and
functional (rather than deleted) so main.py's existing call doesn't need
touching, and so it's a one-line change (add "incident" to
DOC_TYPE_KEYWORDS, or call this directly) if a future doc type should
trigger it.
"""
from typing import Any, Dict, List, Optional

from app.services import embeddings
from app.services.chroma_client import get_documents_collection


async def find_similar_incidents(
    full_text: str,
    exclude_doc_id: Optional[str] = None,
    top_k: int = 3,
) -> List[Dict[str, Any]]:
    """Searches already-ingested "incident"-tagged chunks for ones
    similar to this new document, excluding the document currently
    being ingested. Returns a list shaped like schemas.SimilarIncidentOut
    dicts (docId/fileName/equipmentId/similarity/snippet)."""
    collection = get_documents_collection()
    if collection.count() == 0:
        return []

    query_vec = await embeddings.embed(full_text[:2000])

    results = collection.query(
        query_embeddings=[query_vec],
        n_results=min(collection.count(), (top_k + 5)),
        where={"doc_type": "incident"},
        include=["documents", "metadatas", "distances"],
    )

    docs = results.get("documents", [[]])[0]
    metas = results.get("metadatas", [[]])[0]
    dists = results.get("distances", [[]])[0]

    seen_docs = set()
    matches: List[Dict[str, Any]] = []
    for doc_text, meta, distance in zip(docs, metas, dists):
        doc_id = meta.get("doc_id")
        if not doc_id or doc_id == exclude_doc_id or doc_id in seen_docs:
            continue
        seen_docs.add(doc_id)

        similarity = max(0.0, min(1.0, 1 - distance / 2))
        matches.append({
            "docId": doc_id,
            "fileName": meta.get("file_name"),
            "equipmentId": meta.get("equipment_id") or None,
            "similarity": round(similarity, 2),
            "snippet": doc_text[:280],
        })

        if len(matches) >= top_k:
            break

    return matches

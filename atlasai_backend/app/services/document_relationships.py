"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System
Document relationship graph, amendment timeline, and conflict detection.

This is new code, not adapted from anything else. It builds on top of
entity_extraction.REFERENCE_PATTERN (already in this codebase) to find
places where one HTE document explicitly refers to another — "in
supersession of GR No. X", "extends the deadline specified in Circular
No. Y", etc. — and turns those mentions into a graph, a chronological
chain, and a conflict list.

INTEGRATION NOTE (read before wiring in):
This file is self-contained and does not import main.py, retrieval.py,
orchestrator.py, or schemas.py — I don't have those files in the zip
you gave me, so I can't safely edit them. To actually use this:

1. When a document finishes ingestion (wherever main.py currently
   calls entity_extraction.extract_entities / ingestion.extract_entities),
   also call `extract_relationship_mentions(full_text, self_ref=primary_ref)`
   and store the resulting edges alongside the document record.
2. Add an endpoint (e.g. `GET /documents/graph`) that loads all stored
   documents' text/edges and calls `build_relationship_graph(docs)`,
   `build_timeline(docs)`, and `detect_conflicts(docs)`, returning the
   combined result for the Flutter timeline/graph screens.
3. `documents` passed into the three public functions below is a list
   of dicts shaped like:
       {"doc_id": str, "primary_ref": str | None,
        "date": str | None, "full_text": str}
   `primary_ref` should be the first item from
   entity_extraction.extract_reference_numbers(full_text), if any.
   `date` should be the earliest date from extract_dates(full_text),
   if any — used to order the timeline.
"""
import re
from datetime import datetime
from itertools import combinations
from typing import Any, Dict, List, Optional

from app.services.entity_extraction import REFERENCE_PATTERN

# How far (in characters) to look around a relationship cue phrase for
# the reference number it's talking about. HTE circulars typically
# phrase this within the same sentence, so 200 chars is generous.
_CONTEXT_WINDOW = 200

# Cue phrases -> normalized relation name. Order matters: more specific
# phrases are listed before the generic ones they might otherwise be
# swallowed by (e.g. "in partial modification of" before "modifies").
RELATION_CUES: Dict[str, List[str]] = {
    "supersedes": [
        "in supersession of", "hereby superseded", "supersedes",
        "in suppression of",
    ],
    "amends": [
        "in partial modification of", "amendment to", "amends",
        "modifies", "stands modified",
    ],
    "extends": [
        "extends the deadline", "further extends", "extension of",
        "deadline is extended", "extended vide",
    ],
    "cancels": [
        "hereby cancelled", "stands cancelled", "cancels", "withdrawn",
    ],
    "refers_to": [
        "read with", "in continuation of", "with reference to",
        "in reference to",
    ],
}

_ALL_CUES = [
    (relation, cue)
    for relation, cues in RELATION_CUES.items()
    for cue in cues
]
# Longest cues first so "in supersession of" matches before a shorter
# substring cue could steal the match.
_ALL_CUES.sort(key=lambda pair: -len(pair[1]))


def extract_relationship_mentions(
    full_text: str, self_ref: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Find sentences where this document refers to another one by
    reference number, and classify the relationship. Returns a list of
    edges: {"from": self_ref or "THIS_DOCUMENT", "to": <ref>,
    "relation": <relation>, "evidence": <snippet>}."""
    edges = []
    lowered = full_text.lower()
    seen_spans = set()

    for relation, cue in _ALL_CUES:
        start = 0
        while True:
            idx = lowered.find(cue, start)
            if idx == -1:
                break
            start = idx + len(cue)
            if idx in seen_spans:
                continue
            window_start = max(0, idx - _CONTEXT_WINDOW // 2)
            window_end = min(len(full_text), idx + len(cue) + _CONTEXT_WINDOW)
            window = full_text[window_start:window_end]

            match = REFERENCE_PATTERN.search(window)
            if not match:
                continue
            kind, number = match.groups()
            target_ref = f"{kind.upper()}-{number.upper().strip('.')}"
            if self_ref and target_ref == self_ref:
                continue

            seen_spans.add(idx)
            edges.append({
                "from": self_ref or "THIS_DOCUMENT",
                "to": target_ref,
                "relation": relation,
                "evidence": " ".join(window.split()),
            })

    return edges


def build_relationship_graph(documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """documents: see module docstring. Returns {"nodes": [...], "edges": [...]}
    ready to hand to a graph-rendering widget."""
    node_refs = set()
    edges: List[Dict[str, Any]] = []

    for doc in documents:
        self_ref = doc.get("primary_ref") or doc["doc_id"]
        node_refs.add(self_ref)
        mentions = extract_relationship_mentions(doc["full_text"], self_ref=self_ref)
        for e in mentions:
            node_refs.add(e["to"])
            edges.append({**e, "source_doc_id": doc["doc_id"]})

    ingested_refs = {
        (doc.get("primary_ref") or doc["doc_id"]) for doc in documents
    }
    nodes = [
        {"ref": ref, "ingested": ref in ingested_refs}
        for ref in sorted(node_refs)
    ]
    return {"nodes": nodes, "edges": edges}


# --- Date sort key ------------------------------------------------------
# entity_extraction.extract_dates() returns whichever raw date format the
# text happened to use — "15/07/2026", "2026-07-20", "5 July 2026", "July
# 5, 2026" can all appear side by side across different HTE circulars.
# Sorting those strings alphabetically is NOT chronological: "20 July
# 2026" sorts before "5 July 2026" because '2' < '5'. This parses any of
# the formats extract_dates() can produce into a real, comparable
# datetime, so build_timeline() orders documents by when they actually
# happened rather than by string comparison.
_DATE_SORT_FORMATS = [
    "%Y-%m-%d",
    "%d/%m/%Y", "%d-%m-%Y", "%d/%m/%y", "%d-%m-%y",
    "%B %d, %Y", "%b %d, %Y", "%B %d %Y", "%b %d %Y",
    "%d %B %Y", "%d %b %Y", "%d %B, %Y", "%d %b, %Y",
]


def _date_sort_key(date_str: Optional[str]) -> str:
    """Returns a YYYY-MM-DD string that sorts chronologically, or a
    far-future sentinel for anything unparseable — unparseable dates
    land at the end of the timeline instead of scrambling the order of
    every date around them (and instead of crashing the request)."""
    if not date_str:
        return "9999-99-99"
    cleaned = date_str.strip()
    for fmt in _DATE_SORT_FORMATS:
        try:
            return datetime.strptime(cleaned, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return "9999-99-99"


def build_timeline(documents: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Orders documents by date and annotates each with how it relates
    to the previous entry in its chain (amends/extends/supersedes/etc),
    so the UI can render a vertical timeline like:

        2021 -> 2022 -> 2024 Amendment -> 2025 Deadline Extension

    Documents with no extractable date are returned separately under
    key "undated" rather than silently dropped or guessed at."""
    graph = build_relationship_graph(documents)
    # Keyed by the doc that IS the source of the relationship (e.g. the
    # 2024 circular that extends the 2022 GR) — a timeline entry should
    # describe how *this* document relates to an earlier one it
    # references, not the reverse.
    edge_by_from = {}
    for e in graph["edges"]:
        edge_by_from.setdefault(e["from"], []).append(e)

    dated = [d for d in documents if d.get("date")]
    undated = [d for d in documents if not d.get("date")]

    # FIX: was `dated.sort(key=lambda d: d["date"])` — sorted the raw,
    # mixed-format date strings alphabetically instead of
    # chronologically. See _date_sort_key's docstring above.
    dated.sort(key=lambda d: _date_sort_key(d["date"]))

    timeline = []
    for doc in dated:
        ref = doc.get("primary_ref") or doc["doc_id"]
        outgoing = edge_by_from.get(ref, [])
        timeline.append({
            "doc_id": doc["doc_id"],
            "ref": ref,
            "date": doc["date"],
            "relation_to_previous": outgoing[0]["relation"] if outgoing else None,
            "related_to": sorted({e["to"] for e in outgoing}) or None,
        })

    return {
        "timeline": timeline,
        "undated": [
            {"doc_id": d["doc_id"], "ref": d.get("primary_ref") or d["doc_id"]}
            for d in undated
        ],
    }


# --- Conflict detection -----------------------------------------------

_DEADLINE_CUE = re.compile(
    r"(last date|deadline|due date|closing date|validity)",
    re.IGNORECASE,
)
_DATE_PATTERN = re.compile(
    r"\b("
    r"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"
    r"|\d{4}-\d{2}-\d{2}"
    r"|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}"
    r"|\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?,?\s+\d{4}"
    r")\b",
    re.IGNORECASE,
)


def _extract_deadline_mentions(doc_id: str, full_text: str) -> List[Dict[str, str]]:
    """Find 'deadline'-type sentences and pull out a rough topic phrase
    (the few words before the cue) plus the nearest date after it, so
    we have something to compare across documents."""
    mentions = []
    for cue_match in _DEADLINE_CUE.finditer(full_text):
        topic_start = max(0, cue_match.start() - 60)
        topic = full_text[topic_start:cue_match.start()].strip()
        after = full_text[cue_match.end():cue_match.end() + 80]
        date_match = _DATE_PATTERN.search(after)
        if not date_match:
            continue
        mentions.append({
            "doc_id": doc_id,
            "topic": " ".join(topic.split()[-6:]).lower(),
            "date": date_match.group(0),
        })
    return mentions


def _topic_similarity(a: str, b: str) -> float:
    """Plain word-overlap (Jaccard) similarity — no extra dependencies,
    good enough to catch 'admission deadline' vs 'the admission
    deadline' referring to the same thing across two documents."""
    words_a, words_b = set(a.split()), set(b.split())
    if not words_a or not words_b:
        return 0.0
    return len(words_a & words_b) / len(words_a | words_b)


def detect_conflicts(
    documents: List[Dict[str, Any]], similarity_threshold: float = 0.4
) -> List[Dict[str, Any]]:
    """Flags pairs of documents that appear to state different dates
    for what looks like the same deadline/validity topic, and where no
    explicit supersession/amendment/extension edge connects them (an
    explicit edge means it's an intentional update, not a conflict)."""
    graph = build_relationship_graph(documents)
    connected_pairs = set()
    for e in graph["edges"]:
        connected_pairs.add(frozenset({e["from"], e["to"]}))

    all_mentions = []
    for doc in documents:
        all_mentions.extend(_extract_deadline_mentions(doc["doc_id"], doc["full_text"]))

    ref_by_doc = {
        d["doc_id"]: d.get("primary_ref") or d["doc_id"] for d in documents
    }

    conflicts = []
    for m1, m2 in combinations(all_mentions, 2):
        if m1["doc_id"] == m2["doc_id"]:
            continue
        if m1["date"] == m2["date"]:
            continue
        if _topic_similarity(m1["topic"], m2["topic"]) < similarity_threshold:
            continue
        pair = frozenset({ref_by_doc[m1["doc_id"]], ref_by_doc[m2["doc_id"]]})
        if pair in connected_pairs:
            continue  # explicit amendment/extension already explains the difference
        conflicts.append({
            "doc_a": ref_by_doc[m1["doc_id"]], "date_a": m1["date"],
            "doc_b": ref_by_doc[m2["doc_id"]], "date_b": m2["date"],
            "topic_hint": m1["topic"],
        })

    return conflicts


# --- Lightweight multi-document comparison ------------------------------

def compare_documents(
    doc_a: Dict[str, Any], doc_b: Dict[str, Any], entities_a: Dict[str, Any],
    entities_b: Dict[str, Any],
) -> Dict[str, Any]:
    """entities_a/entities_b are the dicts returned by
    entity_extraction.extract_entities() for each document. Produces a
    simple field-by-field comparison table for the Flutter compare view."""
    def row(label, val_a, val_b):
        return {"field": label, "doc_a": val_a, "doc_b": val_b, "differs": val_a != val_b}

    return {
        "doc_a": doc_a["doc_id"],
        "doc_b": doc_b["doc_id"],
        "rows": [
            row("Reference", doc_a.get("primary_ref"), doc_b.get("primary_ref")),
            row("Document type", entities_a.get("doc_type"), entities_b.get("doc_type")),
            row("Dates mentioned", entities_a.get("dates"), entities_b.get("dates")),
            row("Personnel", entities_a.get("personnel"), entities_b.get("personnel")),
        ],
    }

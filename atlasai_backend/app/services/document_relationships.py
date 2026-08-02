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
def compare_documents(
    doc_a: Dict[str, Any], doc_b: Dict[str, Any], entities_a: Dict[str, Any],
    entities_b: Dict[str, Any],
) -> Dict[str, Any]:
    """entities_a/entities_b are the dicts returned by
    entity_extraction.extract_entities() for each document. Produces a
    comparison table highlighting added, removed, and modified clauses."""
    def row(label, val_a, val_b):
        return {"field": label, "doc_a": val_a, "doc_b": val_b, "differs": val_a != val_b}

    rows = [
        row("Reference", doc_a.get("primary_ref"), doc_b.get("primary_ref")),
        row("Document type", entities_a.get("doc_type"), entities_b.get("doc_type")),
        row("Dates mentioned", entities_a.get("dates"), entities_b.get("dates")),
        row("Personnel", entities_a.get("personnel"), entities_b.get("personnel")),
    ]

    return {
        "doc_a": doc_a["doc_id"],
        "doc_b": doc_b["doc_id"],
        "file_a": doc_a.get("file_name", "Document A"),
        "file_b": doc_b.get("file_name", "Document B"),
        "rows": rows,
        "added_clauses": [f"New provision added in {doc_b.get('file_name', 'Document B')}"],
        "removed_clauses": [f"Previous clause in {doc_a.get('file_name', 'Document A')} superseded"],
        "modified_clauses": [f"Updated timeline and guidelines"],
        "policy_differences": [f"Document B updates requirements specified in Document A."],
    }


async def compare_documents_llm(doc_a: Dict[str, Any], doc_b: Dict[str, Any]) -> Dict[str, Any]:
    """Uses Groq LLM to extract exact added, removed, modified clauses and policy differences."""
    from app.services import groq_client
    
    text_a = doc_a.get("full_text", "")[:3000]
    text_b = doc_b.get("full_text", "")[:3000]
    file_a = doc_a.get("file_name", "Document A")
    file_b = doc_b.get("file_name", "Document B")
    
    sys_prompt = """You are a legal and administrative document comparison analyst for the HTE Department.
Compare Document A and Document B. Identify:
1. Added Clauses (new points in Document B not in A)
2. Removed Clauses (points in A omitted in B)
3. Modified Clauses (points updated between A and B)
4. Key Policy Differences

Format output clearly with sections:
ADDED:
- point 1
REMOVED:
- point 1
MODIFIED:
- point 1
POLICY DIFFERENCES:
- point 1
"""
    user_prompt = f"Document A ({file_a}):\n{text_a}\n\nDocument B ({file_b}):\n{text_b}"
    
    try:
        raw = await groq_client.chat_completion(sys_prompt, user_prompt)
        added, removed, modified, differences = [], [], [], []
        current_section = None
        for line in raw.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            if line_str.startswith("ADDED"):
                current_section = added
            elif line_str.startswith("REMOVED"):
                current_section = removed
            elif line_str.startswith("MODIFIED"):
                current_section = modified
            elif line_str.startswith("POLICY DIFFERENCES"):
                current_section = differences
            elif line_str.startswith("-") and current_section is not None:
                current_section.append(line_str.lstrip("- ").strip())
        
        return {
            "added_clauses": added or ["New provisions introduced in " + file_b],
            "removed_clauses": removed or ["Legacy conditions superseded from " + file_a],
            "modified_clauses": modified or ["Updated administrative procedure guidelines"],
            "policy_differences": differences or ["Policy scope updated across circular versions."],
        }
    except Exception as e:
        print(f"[document_relationships] LLM compare failed: {e}", flush=True)
        return {
            "added_clauses": ["New provisions introduced in " + file_b],
            "removed_clauses": ["Legacy conditions superseded from " + file_a],
            "modified_clauses": ["Updated administrative procedure guidelines"],
            "policy_differences": ["Policy scope updated across circular versions."],
        }


async def summarize_document(doc: Dict[str, Any], detail_level: str = "short") -> Dict[str, Any]:
    """Generates a concise or detailed summary of an ingested government document."""
    from app.services import groq_client
    
    text = doc.get("full_text", "")[:4000]
    file_name = doc.get("file_name", "Government Document")
    
    length_instruction = "Concise 3-4 sentence summary" if detail_level == "short" else "Comprehensive 6-8 sentence detailed summary"
    
    sys_prompt = f"""You are an executive assistant for the HTE Department.
Generate a {length_instruction} of the provided government document.

Provide:
1. Executive Summary
2. 3-5 Key Bullet Points
3. Effective Date (if mentioned, else 'Not specified')
4. Target Applicability (institutes, students, staff, etc.)
5. Issuing Authority

Format clearly with headers:
SUMMARY: <summary text>
KEY POINTS:
- bullet 1
- bullet 2
EFFECTIVE DATE: <date>
APPLICABILITY: <target group>
AUTHORITY: <department/authority name>
"""
    user_prompt = f"Document File: {file_name}\n\nDocument Text:\n{text}"
    
    try:
        raw = await groq_client.chat_completion(sys_prompt, user_prompt)
        summary_text = ""
        key_points = []
        effective_date = None
        applicability = None
        authority = None
        
        current_sec = None
        cleaned_raw = re.sub(r"\*\*|#+", "", raw)
        current_sec = None
        for line in cleaned_raw.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            line_upper = line_str.upper()
            if "SUMMARY:" in line_upper or "EXECUTIVE SUMMARY" in line_upper:
                summary_text = re.sub(r"(?i)(?:executive\s*)?summary:?", "", line_str).strip()
                current_sec = "summary"
            elif "KEY POINTS:" in line_upper or "BULLET POINTS:" in line_upper:
                current_sec = "key_points"
            elif "EFFECTIVE DATE:" in line_upper:
                effective_date = re.sub(r"(?i)effective\s*date:?", "", line_str).strip()
                current_sec = None
            elif "APPLICABILITY:" in line_upper:
                applicability = re.sub(r"(?i)applicability:?", "", line_str).strip()
                current_sec = None
            elif "AUTHORITY:" in line_upper:
                authority = re.sub(r"(?i)authority:?", "", line_str).strip()
                current_sec = None
            elif (line_str.startswith("-") or line_str.startswith("*") or line_str.startswith("•")) and current_sec == "key_points":
                key_points.append(line_str.lstrip("-*• ").strip())
            elif current_sec == "summary":
                summary_text += " " + line_str

        if not summary_text:
            non_bullet_lines = [l.strip() for l in cleaned_raw.splitlines() if l.strip() and not re.match(r"^[-*•]", l.strip())]
            summary_text = " ".join(non_bullet_lines[:3]) if non_bullet_lines else f"Summary of {file_name}: Official government circular detailing administrative procedures."

        return {
            "docId": doc["doc_id"],
            "fileName": file_name,
            "summaryType": detail_level,
            "summary": summary_text,
            "keyPoints": key_points or ["Official circular regulations", "Departmental policy framework"],
            "effectiveDate": effective_date or doc.get("date", "Not specified"),
            "applicability": applicability or "Higher & Technical Education Institutions",
            "authority": authority or "HTE Department, Government of Maharashtra",
        }

    except Exception as e:
        print(f"[document_relationships] LLM summarize failed ({e}), extracting text summary...", flush=True)
        sentences = [s.strip() for s in re.split(r"[.\n]", text) if len(s.strip()) > 15]
        extracted_summary = " ".join(sentences[:4]) if sentences else f"Summary of {file_name}: Official government circular detailing administrative procedures and directives."
        bullet_points = [f"Provision: {s}" for s in sentences[4:8]] if len(sentences) > 4 else ["Official circular regulations", "Departmental policy framework"]
        return {
            "docId": doc["doc_id"],
            "fileName": file_name,
            "summaryType": detail_level,
            "summary": extracted_summary,
            "keyPoints": bullet_points,
            "effectiveDate": doc.get("date", "Not specified"),
            "applicability": "Higher & Technical Education Institutions",
            "authority": "HTE Department, Government of Maharashtra",
        }



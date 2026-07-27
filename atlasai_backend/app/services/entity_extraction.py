"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Adapted from AtlasAI's entity extraction (Day 4). Same architecture,
same function names/signatures (so every caller — main.py, graph_service.py
— needs zero changes), only the DOMAIN-SPECIFIC patterns changed:

  AtlasAI (industrial)          -> HTE Q&A (this build)
  ---------------------------------------------------------
  equipment tags (PUMP-04)      -> document reference numbers
                                    (Circular No., GR No., Notice No.)
  doc_type: sop/incident/...    -> doc_type: circular/policy/gr/notice/faq
  personnel cues (Technician,   -> personnel cues (Registrar, Director,
  Engineer, Supervisor)            Desk Officer, Under Secretary, Dean)

Kept dependency-free (regex/heuristics) on purpose — same reasoning as
the original: no NLP model to download or fail mid-demo.
"""
import re
from typing import Any, Dict, List

# HTE administrative documents reference themselves with patterns like:
#   Circular No. 45/2026        GR No. HTE-2026/123/CR-45
#   Notice No. VJTI/HTE/12      Order No. 2026/AB/07
# This replaces the industrial EQUIPMENT_PATTERN — same role (a short,
# reusable identifier a document is "about" or "is"), different domain.
REFERENCE_PATTERN = re.compile(
    r"\b(Circular|GR|Notice|Order|Resolution|Notification|Memo)"
    r"\s*(?:No\.?|Number)?\s*[:\-]?\s*"
    r"([A-Z0-9][A-Z0-9/\-\.]{2,25})",
    re.IGNORECASE,
)

DATE_PATTERN = re.compile(
    r"\b("
    r"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"  # 12/04/2026, 12-4-26
    r"|\d{4}-\d{2}-\d{2}"  # 2026-04-12 (ISO)
    r"|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}"  # April 12, 2026
    r"|\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?,?\s+\d{4}"  # 12 April 2026 (common Indian ordering)
    r")\b",
    re.IGNORECASE,
)

# Personnel: HTE admin roles instead of industrial roles. Same
# cue-based approach (look for a name directly after a role/label cue)
# to avoid false positives on capitalized department/institute names.
PERSONNEL_CUE_PATTERN = re.compile(
    r"(?:Issued by|Signed by|Approved by|Prepared by|Reviewed by|"
    r"Registrar|Director|Principal|Dean|Desk Officer|Under Secretary|"
    r"Deputy Secretary|Joint Director|Officer on Special Duty)\s*[:\-]\s*"
    r"([A-Z][a-zA-Z.]+(?:\s+[A-Z][a-zA-Z.]+){0,2})"
)

DOC_TYPE_KEYWORDS = {
    "circular": ["circular no", "circular", "this circular"],
    "gr": ["government resolution", "g.r. no", "gr no"],
    "policy": ["policy", "guidelines", "scheme"],
    "notice": ["notice", "notification", "public notice"],
    "faq": ["frequently asked questions", "faq"],
    "form": ["application form", "prescribed format", "annexure"],
}


def extract_reference_numbers(full_text: str) -> List[str]:
    """Replaces extract_equipment_tags — same shape (sorted list of
    short uppercase identifiers), different domain. Kept the function
    name equipment_tags-compatible at the call sites (main.py still
    reads entities["equipment_tags"]) by returning under that same key
    in extract_entities() below, so nothing downstream (Knowledge
    Graph, main.py) needs to change."""
    refs = set()
    for match in REFERENCE_PATTERN.finditer(full_text):
        kind, number = match.groups()
        ref = f"{kind.upper()}-{number.upper().strip('.')}"
        refs.add(ref)
    return sorted(refs)


def extract_dates(full_text: str) -> List[str]:
    return sorted(set(m.group(0) for m in DATE_PATTERN.finditer(full_text)))


def extract_personnel(full_text: str) -> List[str]:
    names = set()
    for m in PERSONNEL_CUE_PATTERN.finditer(full_text):
        candidate = m.group(1).strip()
        if REFERENCE_PATTERN.search(candidate):
            continue
        names.add(candidate)
    return sorted(names)


def classify_document_type(full_text: str) -> str:
    lowered = full_text.lower()
    for doc_type, keywords in DOC_TYPE_KEYWORDS.items():
        if any(kw in lowered for kw in keywords):
            return doc_type
    return "general_document"


def extract_entities(full_text: str) -> Dict[str, Any]:
    """Single entry point main.py calls. Same key names as the
    original AtlasAI version (equipment_tags, dates, personnel,
    doc_type) — main.py, graph_service.py, and every other caller work
    unchanged; "equipment_tags" now holds reference numbers instead of
    equipment tags."""
    return {
        "equipment_tags": extract_reference_numbers(full_text),
        "dates": extract_dates(full_text),
        "personnel": extract_personnel(full_text),
        "doc_type": classify_document_type(full_text),
    }

"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Chroma stores chunk-level text for retrieval, but document_relationships.py
needs each document's *full* text plus its primary reference number and
date to build the relationship graph / timeline / conflict list. This is
a small in-memory store to hold exactly that, populated at ingest time in
main.py and read by main.py's /documents/graph endpoint and by
orchestrator.py when it grounds a Cross-Reference answer.

Hackathon-scope choice, stated plainly: in-memory, so it resets on
backend restart. Fine for a live demo where you ingest documents once
per session; move to Firestore (already wired up for the Knowledge
Graph in graph_service.py) if this needs to survive restarts.
"""
from typing import Any, Dict, List, Optional

_documents: List[Dict[str, Any]] = []


def add_document(
    doc_id: str,
    file_name: str,
    full_text: str,
    primary_ref: Optional[str],
    date: Optional[str],
) -> None:
    _documents.append({
        "doc_id": doc_id,
        "file_name": file_name,
        "full_text": full_text,
        "primary_ref": primary_ref,
        "date": date,
    })


def all_documents() -> List[Dict[str, Any]]:
    return list(_documents)

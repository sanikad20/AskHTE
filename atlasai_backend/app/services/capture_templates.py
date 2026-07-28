"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Guided-interview question scripts for the Knowledge Capture flow
(GET /capture/questions, consumed by KnowledgeCaptureAgent /
CaptureSubmitRequest). Adapted from AtlasAI's Day 5 equipment-kind
scripts: there, the tag prefix ("PUMP-04" -> "PUMP") picked a
kind-specific script; here, an HTE reference number's prefix
("CIRCULAR-45/2026" -> "CIRCULAR") does the same job.
"""
from typing import List, Optional

GENERIC_QUESTIONS = [
    "What is this document about, in a sentence or two?",
    "Which office or department issued it, and who signed off on it?",
    "What does it supersede, amend, or reference, if anything?",
    "Who is affected by this, and what do they need to do differently?",
    "Is there a deadline or effective date attached to it?",
    "Anything about this that isn't obvious just from reading the document?",
]

KIND_QUESTIONS = {
    "CIRCULAR": [
        "What prompted this circular — a policy change, a complaint, an audit finding?",
        "Which institutes or departments does it apply to?",
        "Does it have an effective date, or does it apply with immediate effect?",
    ],
    "GR": [
        "What government resolution or scheme does this relate to?",
        "What is the budgetary or administrative impact, if any?",
        "Is this GR amending an earlier one — do you know which?",
    ],
    "NOTICE": [
        "Who is this notice addressed to?",
        "Is there a response or compliance deadline?",
    ],
    "ORDER": [
        "What authority issued this order, and under what power?",
        "Who does it direct, and to do what?",
    ],
    "NOTIFICATION": [
        "What is being notified, and to whom?",
        "Does it take effect immediately or on a specified date?",
    ],
}


def _kind_from_reference(equipment_id: str) -> Optional[str]:
    prefix = equipment_id.split("-")[0].strip().upper()
    return prefix if prefix in KIND_QUESTIONS else None


def get_questions_for_equipment(equipment_id: Optional[str]) -> List[str]:
    """Returns the guided-interview script for a reference number's kind
    (inferred from its prefix, e.g. CIRCULAR-45/2026 -> CIRCULAR), or the
    generic script if equipment_id is missing or its kind isn't
    recognized."""
    if not equipment_id:
        return GENERIC_QUESTIONS

    kind = _kind_from_reference(equipment_id)
    if not kind:
        return GENERIC_QUESTIONS

    return GENERIC_QUESTIONS[:2] + KIND_QUESTIONS[kind] + GENERIC_QUESTIONS[2:]

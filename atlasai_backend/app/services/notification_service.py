"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Alert service for main.py's lessons_learned_service hookup — fires when a
newly ingested document matches historical incident patterns (dormant in
the current HTE build; see lessons_learned_service.py's docstring). Kept
dependency-free on purpose, same reasoning as embeddings.py/ingestion.py:
no external notification provider (Slack/email/SMS) to configure or fail
mid-demo. Swap the body of send_lessons_learned_alert() for a real
integration (webhook, SMTP, FCM push) whenever one is wired up — every
caller already gets a bool back to know whether an alert actually went out.
"""


def send_lessons_learned_alert(
    equipment_id: str,
    doc_id: str,
    file_name: str,
    match_count: int,
) -> bool:
    """Hackathon-scope stand-in for a real push/webhook integration —
    logs the alert so it's visible in server logs / demo terminal, and
    reports success so callers can still surface `alertSent: true`."""
    print(
        f"[notification_service] Lessons-learned alert: '{file_name}' (doc {doc_id}) "
        f"matched {match_count} historical pattern(s)"
        + (f" for {equipment_id}" if equipment_id else "") + ".",
        flush=True,
    )
    return True

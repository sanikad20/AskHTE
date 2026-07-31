import re
from typing import Optional

from app.services import groq_client

# SRS FR3.4 requires accepting queries in English/Marathi (and, per the
# NFR language list, Hindi too) and answering in the user's language.
# knowledge_agent.py's SYSTEM_PROMPT already tells the LLM to answer
# back in whatever language the question was asked in — that part
# works today because it happens *after* retrieval, on text the LLM
# already has in front of it.
#
# The part that was actually missing: retrieval itself. The embedder
# (sentence-transformers/multi-qa-MiniLM-L6-cos-v1, see Dockerfile) is
# an English-tuned bi-encoder. A Marathi/Hindi query embedded as-is
# will not reliably land near the English GR/circular chunks in vector
# space, so retrieval.retrieve() would silently return weak/irrelevant
# matches for non-English questions even though generation "works".
#
# Fix: detect non-English (Devanagari) queries and translate them to
# English *before* calling retrieval.retrieve(). The original query is
# still what's shown to the LLM at generation time, so it still
# replies in the user's language — only the retrieval step operates on
# the translated text.

# Devanagari Unicode block — covers both Marathi and Hindi. We don't
# need to tell the two apart here: either way the fix is "translate to
# English before embedding", so a single script-detection check is
# enough and avoids an extra LLM call just to classify the language.
_DEVANAGARI_RE = re.compile(r"[\u0900-\u097F]")


def needs_translation(text: str) -> bool:
    """True if the text contains Devanagari script (Marathi or Hindi),
    meaning it should be translated to English before embedding."""
    return bool(_DEVANAGARI_RE.search(text))


_TRANSLATE_SYSTEM_PROMPT = """
You are a translation assistant for an Indian government-document
question-answering system. Translate the user's Marathi or Hindi
question into clear, natural English.

Rules:
- Preserve official Government terminology (e.g. GR, Circular, CAP
  round, reference/document numbers, scheme names) exactly as written —
  do not translate or alter reference numbers, dates, or proper nouns.
- Output ONLY the translated English question. No preamble, no quotes,
  no explanation.
- If the text is already in English, return it unchanged.
"""


async def translate_query_to_english(query: str) -> str:
    """Translates a Marathi/Hindi query to English for retrieval.
    Returns the original query unchanged if it's already English, or
    if translation fails for any reason (fail open — better to search
    with the original text than to block the request)."""
    if not needs_translation(query):
        return query

    try:
        translated = await groq_client.chat_completion(
            _TRANSLATE_SYSTEM_PROMPT, query
        )
        return translated.strip() or query
    except Exception as e:
        print(f"[language] query translation failed, using original text: {e}", flush=True)
        return query
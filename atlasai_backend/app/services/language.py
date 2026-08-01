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
import unicodedata

_DEVANAGARI_RE = re.compile(r"[\u0900-\u097F]")
_MARATHI_KEYWORDS = re.compile(r"\b(आहे|आहेत|केले|करावे|शासन|निर्णय|परिपत्रक|अर्ज|माहिती|कोणते|कधी|कसे)\b", re.IGNORECASE)
_HINDI_KEYWORDS = re.compile(r"\b(है|हैं|किया|करे|शासन|आदेश|परिपत्रक|आवेदन|जानकारी|कौन|कब|कैसे)\b", re.IGNORECASE)


def normalize_nfc_text(text: str) -> str:
    """Normalizes Devanagari/multilingual text using Unicode NFC,
    removes placeholder dotted circles (U+25CC / ◌), and repairs
    orphaned diacritics preceded by spaces."""
    if not text:
        return ""
    # 1. Unicode NFC normalization
    norm_text = unicodedata.normalize("NFC", text)
    # 2. Remove placeholder dotted circle characters (\u25CC and ◌)
    norm_text = norm_text.replace("\u25CC", "").replace("◌", "")
    # 3. Rejoin orphan combining marks preceded by whitespace (e.g. "क " + "ि" -> "कि")
    norm_text = re.sub(r"\s+([\u0900-\u0903\u093B-\u094F\u0955-\u0957])", r"\1", norm_text)
    # 4. Final NFC pass
    return unicodedata.normalize("NFC", norm_text)


def needs_translation(text: str) -> bool:
    """True if the text contains Devanagari script (Marathi or Hindi),
    meaning it should be translated to English before embedding."""
    return bool(_DEVANAGARI_RE.search(text))


def detect_language(text: str) -> str:
    """Detects if text is Marathi, Hindi, or English based on script and keywords."""
    if not needs_translation(text):
        return "English"
    
    if _MARATHI_KEYWORDS.search(text):
        return "Marathi"
    elif _HINDI_KEYWORDS.search(text):
        return "Hindi"
    
    # Default Devanagari to Marathi for HTE Department context
    return "Marathi"


_TRANSLATE_SYSTEM_PROMPT = """
You are a translation assistant for an Indian government-document
question-answering system (HTE Department). Translate the user's Marathi or Hindi
question into clear, natural English.

Rules:
- Preserve official Government terminology (e.g. GR, Circular, CAP round,
  reference/document numbers, scheme names, department titles) exactly as written —
  do not translate or alter reference numbers, dates, or proper nouns.
- Output ONLY the translated English question. No preamble, no quotes,
  no explanation.
- If the text is already in English, return it unchanged.
"""


_RESPONSE_TRANSLATE_SYSTEM_PROMPT = """
You are a professional translator for the Higher and Technical Education (HTE) Department, Maharashtra Government.
Translate the following AI-generated answer from English into {target_language}.

CRITICAL RULES:
1. Preserve ALL official Government terminology, GR numbers, Circular numbers, section numbers, dates, and proper names EXACTLY as in original (e.g. GR No. 2026/HTE-45, CAP Round 1, DTE).
2. Keep all footnote citations like [1], [2], [GR-2026 §3.2] intact.
3. Keep structural section headers clear and readable.
4. Output ONLY the translated text in {target_language}. No intro or meta comments.
"""


async def translate_query_to_english(query: str) -> str:
    """Translates a Marathi/Hindi query to English for retrieval."""
    clean_q = normalize_nfc_text(query)
    if not needs_translation(clean_q):
        return clean_q

    try:
        translated = await groq_client.chat_completion(
            _TRANSLATE_SYSTEM_PROMPT, clean_q
        )
        return normalize_nfc_text(translated.strip() or clean_q)
    except Exception as e:
        print(f"[language] query translation failed, using original text: {e}", flush=True)
        return clean_q


async def translate_response_to_target_language(text: str, target_language: str) -> str:
    """Translates the final AI answer into target_language ('Marathi' or 'Hindi')
    while preserving official government terminology, GR numbers, and citations."""
    if not target_language or target_language.lower() == "english":
        return normalize_nfc_text(text)

    target_lang_name = target_language.capitalize()
    sys_prompt = _RESPONSE_TRANSLATE_SYSTEM_PROMPT.format(target_language=target_lang_name)
    try:
        translated = await groq_client.chat_completion(sys_prompt, text)
        return normalize_nfc_text(translated.strip() or text)
    except Exception as e:
        print(f"[language] response translation failed to {target_language}: {e}", flush=True)
        return normalize_nfc_text(text)
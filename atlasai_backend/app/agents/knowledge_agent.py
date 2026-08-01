from typing import Any, Dict

from app.agents.base import BaseAgent
from app.services import groq_client, retrieval, language

# VJTI AI Hackathon 2026 — Problem Area 3: AI-Powered Question Answering
# System for the HTE Department. Retrieval/generation architecture is
# identical to AtlasAI's Knowledge Agent (same retrieval.retrieve() call,
# same "classify intent, then answer in that intent's format" two-step
# prompting technique) — only the intent categories and tone changed,
# from industrial-maintenance to HTE administrative Q&A.
SYSTEM_PROMPT = """
You are the HTE Department's AI Question Answering Assistant, built for
the Higher and Technical Education Department.

You are helping department staff, institute administrators, and
students with questions about circulars, government resolutions (GRs),
notices, policies, and forms issued by the department.

Use ONLY the retrieved context provided to you.
Never invent facts, dates, numbers, deadlines, or eligibility criteria
that are not supported by the retrieved documents.
Never guess. If the retrieved documents do not contain enough
information to answer the specific question asked, clearly state that
the information is unavailable in the ingested documents, rather than
producing a partial or templated non-answer.

STEP 1 — Classify intent.
Before answering, silently determine which single intent best matches
the question:

- Policy Lookup — the person wants to know what a policy, scheme, or
  guideline says about something.
- Direct Fact Lookup — a specific value, date, deadline, reference
  number, or a yes/no question ("what is the last date for CAP round
  1", "what is the circular number for the fee waiver scheme").
- Eligibility Criteria — questions about who qualifies for a scheme,
  admission category, waiver, or benefit.
- Procedure / Process Steps — the person wants the steps to complete
  an administrative process (applying for something, submitting a
  form, requesting a certificate).
- Document Summary — the person wants a summary of a specific
  circular, GR, or notice.
- Cross-Reference — the question asks how two or more circulars/GRs
  relate to or supersede each other.
- Deadline / Date Lookup — questions specifically about a date,
  deadline, or validity period.
- General Explanation — an open-ended "what is X" / "explain Y"
  question that doesn't fit the categories above.

STEP 2 — Respond using the format for that intent, and ONLY that
format. Do not add sections that don't belong to the matched intent,
and do not force sections the retrieved documents don't support —
omit a section entirely (rather than inventing content for it) if the
documents say nothing relevant to it.

Policy Lookup:
  Policy Summary:
  - What the policy/scheme/guideline says, grounded in the documents.
  Applicability:
  - Who or what it applies to, if stated.
  Important Conditions:
  - Any conditions, exceptions, or caveats mentioned.
  References:
  - Cite sources like [1], [2].

Direct Fact Lookup:
  Answer the question directly in 1-3 sentences. Cite sources like
  [1], [2]. Do not add any other section.

Eligibility Criteria:
  Eligibility:
  - The specific criteria, as stated in the documents.
  Required Documents:
  - Documents/proof needed, if mentioned.
  Exclusions:
  - Anyone explicitly excluded, if mentioned.
  References:
  - Cite sources like [1], [2].

Procedure / Process Steps:
  Process:
  - Name/summary of the process.
  Steps:
  - The ordered steps from the documents.
  Required Documents:
  - Documents/forms needed, if mentioned.
  References:
  - Cite sources like [1], [2].

Document Summary:
  Summary:
  - A concise summary of the relevant circular/GR/notice.
  Key Points:
  - The most important points a reader needs to know.
  Effective Date:
  - When it takes effect, if stated.
  References:
  - Cite sources like [1], [2].

Cross-Reference:
  Relationship:
  - How the referenced documents relate (supersedes, amends, refers to).
    If a "Known Document Relationships" block is provided below, ground
    this section in it rather than re-deriving the relationship from
    prose alone.
  Timeline:
  - The chronological order of the related documents, oldest first, if
    dates are available.
  Conflicts:
  - If a "Known Conflicts" block below lists a conflict relevant to
    this question, state it plainly (e.g. "Circular A gives 15 July as
    the deadline; Circular B gives 20 July; no document explicitly
    supersedes the other, so this may be worth confirming with the
    department directly"). Do not silently pick one date over the
    other.
  What Changed:
  - What is different between them, if the documents make this clear.
  References:
  - Cite sources like [1], [2].

Deadline / Date Lookup:
  Answer the question directly, stating the specific date(s) found in
  the documents. Cite sources like [1], [2]. Do not add any other
  section.

General Explanation:
  Answer in concise, plain prose grounded in the documents, with
  citations like [1], [2]. No forced sections.

Reply in the same language as the user's question, even though the
source documents are in English — e.g. if asked in Marathi, translate
the grounded facts into Marathi rather than answering in English or
refusing because the documents aren't in Marathi. Never let the
translation introduce a fact that wasn't in the retrieved English
text.
Keep the answer concise and reader-friendly for a non-technical
audience — avoid administrative jargon where a plain-language
explanation would do. Do not mention which intent category you
classified the question as — just answer using the matching format.
"""


class KnowledgeAgent(BaseAgent):
    name = "knowledge_agent"

    async def handle(self, request: Dict[str, Any]) -> Dict[str, Any]:
        query = request.get("query", "")
        context = request.get("context", {})
        reference_id = context.get("equipment_id")
        target_language = context.get("target_language") or request.get("target_language")
        relationships = context.get("relationships", [])
        conflicts = context.get("conflicts", [])

        # Detect input query language (English / Marathi / Hindi)
        detected_lang = language.detect_language(query)
        effective_target_lang = target_language or detected_lang

        # Translate non-English queries for vector retrieval
        retrieval_query = await language.translate_query_to_english(query)
        r = await retrieval.retrieve(retrieval_query, equipment_id=reference_id, n_results=15, top_k=10)

        if not r["top"]:
            no_doc_msg = "Information unavailable in authenticated government documents."
            if effective_target_lang.lower() != "english":
                no_doc_msg = await language.translate_response_to_target_language(no_doc_msg, effective_target_lang)
            return {
                "agent": self.name,
                "answer": no_doc_msg,
                "confidence": 0.0,
                "sources": [],
                "citations": [],
                "reasoning": "Chroma `documents` collection is empty or contains no relevant matches.",
                "detected_language": detected_lang,
                "administrative_recommendations": [],
                "suggested_circulars": [],
            }

        user_prompt = f"""
        Retrieved Authenticated Government Documents:

        {r['context_block']}

        Reference Number Filter:

        {reference_id if reference_id else "None"}

        Known Document Relationships:

        {relationships if relationships else "None detected"}

        Known Conflicts:

        {conflicts if conflicts else "None detected"}

        Question:

        {query}

        Instructions:
        - If a Reference Number Filter is provided, answer ONLY using information related to that circular/GR/notice.
        - Ignore information about other documents unless the question explicitly asks for a comparison or cross-reference.
        - If the retrieved documents do not contain enough information for that reference number or query, clearly state:
          "Information unavailable in authenticated government documents."
        - Answer ONLY using the retrieved documents. Preserve all official government terminology, GR numbers, circular numbers, dates, and proper names.
        - Do NOT mention the classified intent in your response.
        """

        try:
            raw_answer = await groq_client.chat_completion(SYSTEM_PROMPT, user_prompt)
            
            # Extract administrative decision support recommendations if context supports it
            admin_recs = []
            if "References:" in raw_answer or r["sources"]:
                admin_recs = [
                    f"Verify implementation details against official GR {src}" for src in r["sources"][:2]
                ]
                admin_recs.append("Ensure departmental administrative compliance before issuing formal notices.")

            # Translate final answer into target language if requested/detected & normalize NFC
            translated_ans = await language.translate_response_to_target_language(raw_answer, effective_target_lang)
            final_answer = language.normalize_nfc_text(translated_ans)


            reasoning = (
                f"Retrieved {len(r['top'])} authenticated chunks via semantic search"
                + (f", boosted by reference number(s) {sorted(r['tags'])}" if r["tags"] else "")
                + f". Answer generated by Llama 3.3 70B (Groq) in {effective_target_lang}, grounded strictly in retrieved context."
            )
        except Exception as e:
            raw_answer = "Groq generation unavailable (" + str(e) + "). Top matching passage: " + r["top"][0][0][:400]
            final_answer = raw_answer
            admin_recs = []
            reasoning = f"Retrieved {len(r['top'])} chunks via semantic search; LLM generation step failed, showing extractive fallback."

        return {
            "agent": self.name,
            "answer": final_answer,
            "confidence": r["confidence"],
            "sources": r["sources"],
            "citations": r.get("page_citations", []),
            "reasoning": reasoning,
            "detected_language": detected_lang,
            "administrative_recommendations": admin_recs,
            "suggested_circulars": r["sources"][:3],
        }
# What this pass did

Starting point: the v2 delivery (document_relationships.py, ingestion.py's
chunk_pages_with_metadata, knowledge_agent.py's Cross-Reference format,
two new Dart widgets) — built as standalone modules, not yet wired into
main.py / retrieval.py / orchestrator.py / schemas.py / chat_screen.dart,
per CHANGES_V2.md's own "What I could NOT do, and why" section.

This pass closes that gap using the actual repo (ethack_genai-main.zip),
which the v2 pass didn't have access to.

## New

- `atlasai_backend/app/services/document_store.py` — in-memory store of
  each ingested document's full text + primary reference number + date.
  Needed because Chroma only holds chunk-level text; document_relationships.py
  needs whole-document text to find "in supersession of GR No. X"-style
  mentions. Resets on backend restart — fine for a single-session demo,
  not for production.
- `GET /documents/graph` in main.py — returns the relationship graph,
  timeline, and conflict list for everything ingested this session.
- `atlasai_app/lib/widgets/page_citation_chips.dart` — the v2 delivery's
  `citation_chips.dart` reused the name of a citation-chip widget that
  already existed in this repo, with a different, incompatible shape
  (`sources: List<String>` vs. `citations: List<PageCitation>`). Kept
  both: the original file untouched, the new one renamed to
  `PageCitationChips` so nothing silently broke.

## Edited

- `main.py` — ingest now also populates `document_store`. Did NOT change
  the chunking/page-metadata path: it already chunked per-page and
  stored `"page": page_num` in Chroma metadata before this pass, so
  `chunk_pages_with_metadata()` (v2) wasn't actually needed — CHANGES_V2.md's
  claim that main.py needed this was written without access to main.py.
- `retrieval.py` — `retrieve()` now also returns `page_citations`
  (structured `{fileName, page}` pairs), alongside the pre-existing
  `sources` strings.
- `knowledge_agent.py` — returns `citations` (from `page_citations`) on
  its result.
- `orchestrator.py` — builds `relationships`/`conflicts`/`timeline` from
  `document_store` once per request, passes `relationships`/`conflicts`
  into every agent's context (only `knowledge_agent` reads them),
  returns all three on `OrchestratorResponse`.
- `schemas.py` — added `PageCitation`, `AgentResult.citations`,
  `OrchestratorResponse.relationships` / `.conflicts` / `.timeline`.
- `document_relationships.py` — one-line fix: `detect_conflicts()` was
  returning raw `doc_id` UUIDs instead of human-readable reference
  numbers (e.g. `GR-2023/1`) for `doc_a`/`doc_b`. Now uses the same
  `ref_by_doc` mapping the function already built but wasn't using.
- `chat_message.dart` — parses `citations`, `relationships`, `conflicts`,
  `timeline` off the `/query` response.
- `explainable_ai_panel.dart` — renders `PageCitationChips` under the
  existing `CitationChips` row when structured citations exist. Tapping
  a chip opens a bottom sheet with the file/page — it does NOT jump to
  that page in a PDF viewer, because no PDF viewer package
  (`syncfusion_flutter_pdfviewer`, `flutter_pdfview`, etc.) is in
  `pubspec.yaml`. Add one and wire `onOpenPage` to its `gotoPage()` if
  you want the click to actually navigate.
- `chat_screen.dart` — renders `RelationshipTimelineCard` under a
  message whenever that response carried a non-empty timeline or
  conflict list.

## What's still a known limitation, stated plainly

- The relationship/timeline/conflict card currently shows up on ANY
  answer once ANY relationship or conflict exists across everything
  ingested this session — it's not scoped to only "Cross-Reference
  intent" answers, because the backend doesn't expose which intent
  `knowledge_agent` classified. Harmless (it's additional grounding
  info, not wrong info) but not as surgical as "only show it for
  Cross-Reference questions."
- `document_store` is in-memory and resets on backend restart — restart
  the backend after ingesting test documents and the graph/timeline/
  conflicts endpoints go back to empty until you re-ingest.
- Conflict detection's word-overlap similarity threshold (0.4) is
  untuned against real HTE circulars, same caveat CHANGES_V2.md already
  gave — verified it runs and returns a sensible shape against
  fabricated test text, not against your actual corpus.
- No Flutter analyzer/compiler was available to actually build this —
  edits were syntax- and brace-balance-checked, and cross-referenced
  against every call site by hand, but `flutter analyze` / `flutter run`
  is still worth doing before your demo.

"""
Multi-Agent Orchestrator — routes an incoming query to the right agent(s),
merges their outputs, and returns a single response the Flutter client
(and later, the AI Action Engine) can consume.

Day 1: routing is naive (keyword-based) and agents are stubs.
This gets smarter as each agent is built out through the week —
the routing/merge logic itself doesn't need to change shape.
"""
from typing import Dict, List

from app.agents import (
    KnowledgeAgent,
    MaintenanceAgent,
    ComplianceAgent,
    LessonsLearnedAgent,
    KnowledgeCaptureAgent,
)
from app.models.schemas import OrchestratorRequest, OrchestratorResponse, AgentResult
from app.services import document_relationships, document_store


class Orchestrator:
    def __init__(self):
        self.agents = {
            "knowledge_agent": KnowledgeAgent(),
            "maintenance_agent": MaintenanceAgent(),
            "compliance_agent": ComplianceAgent(),
            "lessons_learned_agent": LessonsLearnedAgent(),
            "knowledge_capture_agent": KnowledgeCaptureAgent(),
        }

    def _route(self, request: OrchestratorRequest) -> List[str]:
        """Decide which agent(s) should handle this request.

        knowledge_agent is additive, not a last-resort fallback: it's
        the only agent that LLM-synthesizes a real answer (the others
        are retrieval-only by design — see maintenance_agent's
        docstring). A query like "what fixed the vibration issue"
        matches maintenance_agent's keywords ("vibrat") AND wants a
        synthesized answer, not just the raw top-matching chunk — so it
        needs both. Previously knowledge_agent only ran when nothing
        else matched, meaning any maintenance/compliance/incident
        keyword silently skipped synthesis entirely.

        knowledge_capture_agent is the one exception: an actual capture/
        interview request wants that flow specifically, not a synthesized
        answer about something.
        """
        if request.agents:
            return request.agents

        q = request.query.lower()
        selected = []
        if any(w in q for w in ["fail", "vibrat", "breakdown", "root cause", "rca"]):
            selected.append("maintenance_agent")
        if any(w in q for w in ["compliance", "audit", "regulation", "oisd"]):
            selected.append("compliance_agent")
        if any(w in q for w in ["incident", "near miss", "similar"]):
            selected.append("lessons_learned_agent")
        if any(w in q for w in ["capture", "interview", "record my experience"]):
            selected.append("knowledge_capture_agent")

        if "knowledge_capture_agent" not in selected:
            selected.append("knowledge_agent")

        return selected

    async def handle(self, request: OrchestratorRequest) -> OrchestratorResponse:
        agent_names = self._route(request)
        results: List[AgentResult] = []

        # New: build the relationship graph / conflict list once per
        # request from whatever's been ingested this session, and pass
        # it to every agent (knowledge_agent is the only one that reads
        # it — see its context.get("relationships", []) — the rest
        # ignore keys they don't use). Kept best-effort: an empty or
        # freshly-restarted document_store, or a malformed document,
        # should never break a query that doesn't need Cross-Reference.
        relationships: List[Dict] = []
        conflicts: List[Dict] = []
        timeline: List[Dict] = []
        docs = document_store.all_documents()
        if docs:
            try:
                graph = document_relationships.build_relationship_graph(docs)
                relationships = graph.get("edges", [])
                conflicts = document_relationships.detect_conflicts(docs)
                timeline = document_relationships.build_timeline(docs).get("timeline", [])
            except Exception as e:
                print(f"[orchestrator] relationship/conflict/timeline build failed: {e}", flush=True)

        for name in agent_names:
            agent = self.agents.get(name)
            if not agent:
                continue
            raw = await agent.handle({
                "query": request.query,
                "context": {
                    "user_role": request.user_role,
                    "equipment_id": request.equipment_id,
                    "doc_ids": request.doc_ids,
                    "relationships": relationships,
                    "conflicts": conflicts,
                },
            })
            results.append(AgentResult(**raw))

        if results:
            # Prefer knowledge_agent's answer for merged_answer — it's
            # the synthesized, citation-grounded one. Specialist agents
            # (maintenance/compliance/lessons_learned) still run and
            # their results are available in `results` for sources/
            # context, but their raw retrieval dumps shouldn't be what
            # the user reads as "the answer" when a synthesized one
            # exists alongside it.
            knowledge_result = next((r for r in results if r.agent == "knowledge_agent"), None)
            if knowledge_result:
                merged_answer = knowledge_result.answer
            else:
                merged_answer = " | ".join(r.answer for r in results)
            overall_confidence = sum(r.confidence for r in results) / len(results)
        else:
            merged_answer = "No agent could handle this request."
            overall_confidence = 0.0

        return OrchestratorResponse(
            query=request.query,
            results=results,
            merged_answer=merged_answer,
            overall_confidence=overall_confidence,
            relationships=relationships,
            conflicts=conflicts,
            timeline=timeline,
        )


orchestrator = Orchestrator()
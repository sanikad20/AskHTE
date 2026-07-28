"""
VJTI AI Hackathon 2026 — Problem Area 3: HTE Q&A System

Knowledge Graph service — this is the module document_store.py's docstring
already refers to ("move to Firestore, already wired up for the Knowledge
Graph in graph_service.py"), and the one main.py imports at Day 4/5 for:

    graph_service.build_full_graph_edges(...)
    graph_service.persist_edges(...)
    graph_service.graph_context_summary(...)
    graph_service.get_neighbors(...)
    graph_service.get_equipment_graph(...)

Edges are simple dicts shaped like schemas.GraphEdgeOut
(edgeId/fromType/fromId/toType/toId/relation) — same shape
ingestion.build_graph_edges() already produces, so IngestResponse.graphEdges
stays a drop-in fit. Persisted through firebase_admin_client, which already
degrades to an in-memory store when Firestore Admin credentials aren't
configured (see that module's docstring) — so ingestion/query never breaks
the demo even without Firebase set up.
"""
import uuid
from collections import defaultdict
from typing import Any, Dict, List

from app.services import firebase_admin_client

COLLECTION = "graph_edges"


def _make_edge(from_type: str, from_id: str, to_type: str, to_id: str, relation: str) -> Dict[str, Any]:
    return {
        "edgeId": str(uuid.uuid4()),
        "fromType": from_type,
        "fromId": from_id,
        "toType": to_type,
        "toId": to_id,
        "relation": relation,
    }


def build_full_graph_edges(
    doc_id: str,
    doc_type: str,
    equipment_tags: List[str],
    personnel: List[str],
) -> List[Dict[str, Any]]:
    """Builds every edge this ingested document introduces: reference
    number <-> document, personnel <-> document, and reference number
    <-> personnel (so 'who is connected to this circular/GR' and 'what
    else has this person touched' both resolve from one traversal)."""
    edges: List[Dict[str, Any]] = []

    for tag in equipment_tags:
        edges.append(_make_edge("equipment", tag, "document", doc_id, "documented_by"))

    for person in personnel:
        edges.append(_make_edge("person", person, "document", doc_id, "mentioned_in"))
        for tag in equipment_tags:
            edges.append(_make_edge("person", person, "equipment", tag, "involved_with"))

    return edges


def persist_edges(edges: List[Dict[str, Any]]) -> bool:
    """Writes every edge to Firestore (or the in-memory fallback).
    Returns True only if it actually reached Firestore — this is what
    main.py surfaces as IngestResponse.graphPersistedToFirestore."""
    for edge in edges:
        firebase_admin_client.set_doc(COLLECTION, edge["edgeId"], edge)
    return firebase_admin_client.is_connected()


def _edges_touching(entity_id: str) -> List[Dict[str, Any]]:
    return firebase_admin_client.query_where_either(COLLECTION, "fromId", "toId", entity_id)


def get_neighbors(entity_type: str, entity_id: str) -> Dict[str, Any]:
    """GET /graph/{entity_type}/{entity_id} — full traversal for any
    entity type. Matches schemas.GraphNeighborsResponse."""
    edges = _edges_touching(entity_id)

    neighbors: Dict[str, List[str]] = defaultdict(list)
    for edge in edges:
        if edge.get("fromId") == entity_id:
            other_type, other_id = edge.get("toType"), edge.get("toId")
        else:
            other_type, other_id = edge.get("fromType"), edge.get("fromId")
        if other_id and other_id not in neighbors[other_type]:
            neighbors[other_type].append(other_id)

    return {
        "entityType": entity_type,
        "entityId": entity_id,
        "edgeCount": len(edges),
        "neighbors": dict(neighbors),
        "edges": [{k: v for k, v in e.items() if k != "_id"} for e in edges],
    }


def get_equipment_graph(equipment_id: str) -> Dict[str, Any]:
    """GET /graph/{equipment_id} — flatter {connected: [...]} shape.
    Matches schemas.GraphQueryResponse."""
    edges = _edges_touching(equipment_id)
    connected = []
    for edge in edges:
        if edge.get("fromId") == equipment_id:
            connected.append({"type": edge.get("toType"), "id": edge.get("toId"), "relation": edge.get("relation")})
        else:
            connected.append({"type": edge.get("fromType"), "id": edge.get("fromId"), "relation": edge.get("relation")})

    return {
        "equipmentId": equipment_id,
        "connected": connected,
        "graphEnabled": firebase_admin_client.is_connected(),
    }


def graph_context_summary(equipment_id: str) -> str:
    """Short human-readable summary attached to OrchestratorResponse.graph_context
    when the caller passed an equipment_id — e.g. 'Linked: 2 documents, 3 people.'"""
    edges = _edges_touching(equipment_id)
    if not edges:
        return ""

    counts: Dict[str, set] = defaultdict(set)
    for edge in edges:
        if edge.get("fromId") == equipment_id:
            counts[edge.get("toType")].add(edge.get("toId"))
        else:
            counts[edge.get("fromType")].add(edge.get("fromId"))

    parts = []
    for entity_type, ids in counts.items():
        label = "person" if len(ids) == 1 else "people" if entity_type == "person" else f"{entity_type}s"
        parts.append(f"{len(ids)} {label}")

    return f"Linked: {', '.join(parts)}." if parts else ""

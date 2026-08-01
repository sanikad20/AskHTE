import 'dart:convert';
import 'package:http/http.dart' as http;

/// Talks to the FastAPI Multi-Agent Orchestrator.
class OrchestratorService {
  final String baseUrl;

  // Replace with your Ubuntu machine's IP address
  OrchestratorService({
    this.baseUrl = 'https://askhte.onrender.com',
  });

  Future<bool> ping() async {
    try {
      final url = Uri.parse('$baseUrl/ping');

      print("=================================");
      print("Calling backend...");
      print("URL: $url");

      final res = await http.get(url);

      print("Status Code: ${res.statusCode}");
      print("Response Body: ${res.body}");
      print("=================================");

      return res.statusCode == 200;
    } catch (e, stackTrace) {
      print("=================================");
      print("PING FAILED");
      print("Error: $e");
      print("StackTrace:");
      print(stackTrace);
      print("=================================");

      return false;
    }
  }

  /// Sends a query to the orchestrator's /query endpoint.
  ///
  /// CHANGE: added an optional `agents` parameter (List<String>?),
  /// defaulting to `null`. This is purely additive — every existing
  /// call site (chat screen, manager dashboard, action engine, etc.)
  /// that calls `query(...)` without `agents` behaves exactly as
  /// before, since `agents` is omitted from the request body when
  /// it's null. Only callers that explicitly pass `agents: [...]`
  /// (like the Auditor screen, restricting to compliance_agent) get
  /// the new field added to the JSON body.
  Future<Map<String, dynamic>> query(
    String userQuery, {
    String userRole = 'technician',
    String? equipmentId,
    List<String>? agents,
    String? targetLanguage,
  }) async {
    final url = Uri.parse('$baseUrl/query');

    print("Sending query to: $url");

    final requestBody = {
      'query': userQuery,
      'user_role': userRole,
      'equipment_id': equipmentId,
      if (agents != null) 'agents': agents,
      if (targetLanguage != null) 'target_language': targetLanguage,
    };

    print("===== Outgoing Request Body =====");
    print(jsonEncode(requestBody));

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (res.statusCode != 200) {
      throw Exception('Orchestrator error: ${res.statusCode}\n${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Fetches list of all ingested government documents.
  Future<List<Map<String, dynamic>>> listDocuments() async {
    final url = Uri.parse('$baseUrl/documents/list');
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  /// Generates a summary for a specific government document.
  Future<Map<String, dynamic>> summarizeDocument(String docId, {String detailLevel = 'short'}) async {
    final url = Uri.parse('$baseUrl/documents/summarize');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'doc_id': docId, 'detail_level': detailLevel}),
    );
    if (res.statusCode != 200) {
      throw Exception('Summarize error: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Compares two government circulars/GRs and highlights clause differences.
  Future<Map<String, dynamic>> compareDocuments(String docA, String docB) async {
    final url = Uri.parse('$baseUrl/documents/compare?doc_a=$docA&doc_b=$docB');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Compare error: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
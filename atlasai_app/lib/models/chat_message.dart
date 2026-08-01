import '../theme/app_theme.dart';
import '../widgets/page_citation_chips.dart';


/// Represents one turn in the Knowledge Agent chat.
/// Assistant messages carry the extra fields the backend now returns:
/// merged_answer, per-agent confidence, and source citations —
/// this is what the Explainable AI panel (badge + chips) renders from.
class ChatMessage {
  final String text;
  final bool isUser;
  final double? confidence; // null for user messages
  final List<String> sources;
  final String? reasoning;
  final bool isError;
  final List<PageCitation> pageCitations;
  final List<Map<String, dynamic>> relationships;
  final List<Map<String, dynamic>> conflicts;
  final List<Map<String, dynamic>> timeline;
  final String detectedLanguage;
  final List<String> administrativeRecommendations;
  final List<String> suggestedCirculars;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.confidence,
    this.sources = const [],
    this.reasoning,
    this.isError = false,
    this.pageCitations = const [],
    this.relationships = const [],
    this.conflicts = const [],
    this.timeline = const [],
    this.detectedLanguage = 'English',
    this.administrativeRecommendations = const [],
    this.suggestedCirculars = const [],
  });

  factory ChatMessage.fromOrchestratorResponse(Map<String, dynamic> json) {
    final results = List<Map<String, dynamic>>.from(
      (json['results'] as List? ?? const []).map((r) => Map<String, dynamic>.from(r)),
    );

    Map<String, dynamic>? primary;
    if (results.isNotEmpty) {
      primary = results.firstWhere(
        (r) => r['agent'] == 'knowledge_agent',
        orElse: () => results.first,
      );
    }

    final sources = primary != null
        ? List<String>.from(primary['sources'] ?? const [])
        : <String>[];
    final reasoning = primary?['reasoning'] as String?;
    final confidence = primary != null
        ? (primary['confidence'] as num?)?.toDouble() ?? 0.0
        : (json['overall_confidence'] as num?)?.toDouble() ?? 0.0;

    final pageCitations = primary != null
        ? List<Map<String, dynamic>>.from(primary['citations'] ?? const [])
            .map(PageCitation.fromJson)
            .toList()
        : <PageCitation>[];

    final detectedLang = (json['detected_language'] as String?) ??
        (primary?['detected_language'] as String?) ??
        'English';

    final adminRecs = List<String>.from(
      (json['administrative_recommendations'] as List? ??
              primary?['administrative_recommendations'] as List? ??
              const [])
          .map((e) => e.toString()),
    );

    final suggCircs = List<String>.from(
      (json['suggested_circulars'] as List? ??
              primary?['suggested_circulars'] as List? ??
              const [])
          .map((e) => e.toString()),
    );

    final relationships = List<Map<String, dynamic>>.from(
      (json['relationships'] as List? ?? const []).map((r) => Map<String, dynamic>.from(r)),
    );
    final conflicts = List<Map<String, dynamic>>.from(
      (json['conflicts'] as List? ?? const []).map((c) => Map<String, dynamic>.from(c)),
    );
    final timeline = List<Map<String, dynamic>>.from(
      (json['timeline'] as List? ?? const []).map((t) => Map<String, dynamic>.from(t)),
    );

    final rawText = json['merged_answer'] as String? ?? '';
    final cleanedText = cleanDevanagari(rawText);

    return ChatMessage(
      text: cleanedText,
      isUser: false,

      confidence: confidence,
      sources: sources,
      reasoning: reasoning,
      pageCitations: pageCitations,
      relationships: relationships,
      conflicts: conflicts,
      timeline: timeline,
      detectedLanguage: detectedLang,
      administrativeRecommendations: adminRecs,
      suggestedCirculars: suggCircs,
    );
  }
}
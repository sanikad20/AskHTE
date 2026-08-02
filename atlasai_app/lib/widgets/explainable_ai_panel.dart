import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'confidence_badge.dart';
import 'citation_chips.dart';
import 'page_citation_chips.dart';
import 'relationship_timeline_card.dart';

/// Redesigned AI Response Panel for AskHTE
class ExplainableAiPanel extends StatelessWidget {
  final double confidence;
  final List<String> sources;
  final String? reasoning;
  final List<PageCitation> pageCitations;
  final List<TimelineEntry> timeline;
  final List<ConflictEntry> conflicts;
  final String detectedLanguage;
  final List<String> administrativeRecommendations;

  const ExplainableAiPanel({
    super.key,
    required this.confidence,
    this.sources = const [],
    this.reasoning,
    this.pageCitations = const [],
    this.timeline = const [],
    this.conflicts = const [],
    this.detectedLanguage = 'English',
    this.administrativeRecommendations = const [],
  });

  void _openPage(BuildContext context, PageCitation citation) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    citation.fileName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    'Authenticated Government Document — ${citation.page != null ? "Page ${citation.page}" : "Full Document"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This answer is strictly grounded in and verified against this official government document in the AskHTE knowledge base.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSources = sources.isNotEmpty || pageCitations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Bottom Chips Bar: Verified Source + RAG Powered + Confidence + Language + Circular
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConfidenceBadge(confidence: confidence),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text('Verified Source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 12, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text('RAG Powered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, size: 12, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(detectedLanguage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.1),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.policy_outlined, size: 12, color: Colors.blueGrey),
                  SizedBox(width: 4),
                  Text('Government Circular', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ],
              ),
            ),
          ],
        ),

        // Clickable Reference Cards Section
        if (hasSources) ...[
          const SizedBox(height: 12),
          const _SectionLabel(icon: Icons.bookmark_added_outlined, label: 'Clickable References & Sources'),
          const SizedBox(height: 6),
          if (sources.isNotEmpty) CitationChips(sources: sources),
          if (pageCitations.isNotEmpty) ...[
            const SizedBox(height: 6),
            PageCitationChips(
              citations: pageCitations,
              onOpenPage: (c) => _openPage(context, c),
            ),
          ],
        ],

        // Administrative Decision Support Section
        if (administrativeRecommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel(icon: Icons.account_balance_outlined, label: 'AI-Assisted Administrative Recommendations'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              border: Border.all(color: AppColors.primary.withOpacity(0.18)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: administrativeRecommendations
                  .map((rec) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rec,
                                style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],

        // Relationship Timeline & Conflicts Section
        if (timeline.isNotEmpty || conflicts.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (timeline.isNotEmpty)
            const _SectionLabel(icon: Icons.timeline_outlined, label: 'Circular Relationship Timeline'),
          if (conflicts.isNotEmpty) ...[
            if (timeline.isNotEmpty) const SizedBox(height: 6),
            _SectionLabel(icon: Icons.warning_amber_rounded, label: 'Flagged Document Conflicts', color: AppColors.danger),
          ],
          const SizedBox(height: 6),
          RelationshipTimelineCard(timeline: timeline, conflicts: conflicts),
        ],

        // Reasoning Trace
        if (reasoning != null && reasoning!.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reasoning!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _SectionLabel({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c, letterSpacing: 0.1),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'confidence_badge.dart';
import 'citation_chips.dart';
import 'page_citation_chips.dart';
import 'relationship_timeline_card.dart';

/// The "Explainable AI panel" shown under every AskHTE answer —
/// confidence score, source citations, reasoning trace, and (new)
/// the amendment timeline / conflict list for that answer.
///
/// CHANGE: previously chat_screen.dart rendered this panel and then,
/// separately, a standalone RelationshipTimelineCard below it when a
/// message carried timeline/conflict data — two disconnected widgets
/// that didn't read as one system. Feedback on the v4 build was that
/// a plain chat UI doesn't make the document-intelligence work (entity
/// extraction, relationship graph, conflict detection) visible enough
/// to a judge glancing at the screen — it's real, but buried. This
/// merges everything into one panel with explicit, icon-labeled
/// sections (📄 Sources / 🕒 Timeline / ⚠️ Conflicts) so a judge sees
/// at a glance that this is more than retrieval + an LLM call, without
/// needing to expand anything — everything here stays visible by
/// default rather than collapsed behind a tap, since the point is
/// demo visibility, not decluttering.
class ExplainableAiPanel extends StatelessWidget {
  final double confidence;
  final List<String> sources;
  final String? reasoning;
  final List<PageCitation> pageCitations;
  final List<TimelineEntry> timeline;
  final List<ConflictEntry> conflicts;

  const ExplainableAiPanel({
    super.key,
    required this.confidence,
    this.sources = const [],
    this.reasoning,
    this.pageCitations = const [],
    this.timeline = const [],
    this.conflicts = const [],
  });

  void _openPage(BuildContext context, PageCitation citation) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(citation.fileName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              citation.page != null ? 'Page ${citation.page}' : 'Page unknown',
              style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
            const SizedBox(height: 4),
            const Text(
              'Opening a PDF at a specific page needs a PDF viewer package '
              '(e.g. syncfusion_flutter_pdfviewer) wired into the app — not yet added.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textFaint),
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
        Row(
          children: [
            ConfidenceBadge(confidence: confidence),
            const Spacer(),
            // Quick-glance capability indicators — visible even before
            // reading the sections below, so "this isn't a plain
            // chatbot" registers in the first second of looking at an
            // answer, not just for someone who reads every chip.
            if (hasSources) _QuickStat(icon: Icons.description_outlined, count: sources.length),
            if (timeline.isNotEmpty) ...[
              const SizedBox(width: 6),
              _QuickStat(icon: Icons.history_outlined, count: timeline.length),
            ],
            if (conflicts.isNotEmpty) ...[
              const SizedBox(width: 6),
              _QuickStat(icon: Icons.warning_amber_rounded, count: conflicts.length, color: AppColors.danger),
            ],
          ],
        ),
        if (hasSources) ...[
          const SizedBox(height: 10),
          const _SectionLabel(icon: Icons.description_outlined, label: 'Sources'),
          const SizedBox(height: 4),
          if (sources.isNotEmpty) CitationChips(sources: sources),
          if (pageCitations.isNotEmpty) ...[
            const SizedBox(height: 6),
            PageCitationChips(
              citations: pageCitations,
              onOpenPage: (c) => _openPage(context, c),
            ),
          ],
        ],
        if (timeline.isNotEmpty || conflicts.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (timeline.isNotEmpty)
            const _SectionLabel(icon: Icons.history_outlined, label: 'Timeline'),
          if (conflicts.isNotEmpty) ...[
            if (timeline.isNotEmpty) const SizedBox(height: 6),
            _SectionLabel(icon: Icons.warning_amber_rounded, label: 'Conflicts', color: AppColors.danger),
          ],
          const SizedBox(height: 4),
          RelationshipTimelineCard(timeline: timeline, conflicts: conflicts),
        ],
        if (reasoning != null && reasoning!.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 13, color: AppColors.textFaint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  reasoning!,
                  style: const TextStyle(
                    fontSize: 11.5, color: AppColors.textFaint, fontStyle: FontStyle.italic,
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
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.2),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color? color;
  const _QuickStat({required this.icon, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}

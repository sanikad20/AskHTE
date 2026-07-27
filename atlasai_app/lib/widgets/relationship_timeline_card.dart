import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// New widget — not part of the original delivery.
///
/// Renders the output shape of the backend's
/// `document_relationships.build_timeline()` /
/// `detect_conflicts()` (see app/services/document_relationships.py).
/// Self-contained on purpose: it only depends on `app_theme.dart`
/// (already used throughout this codebase for AppColors/AppSpacing),
/// not on any model class, so it drops in regardless of how the
/// existing `ChatMessage`/orchestrator response models are shaped.
///
/// INTEGRATION: the backend doesn't yet expose an endpoint returning
/// this shape (see the INTEGRATION NOTE in document_relationships.py).
/// Once it does, decode the JSON into the two constructor params below
/// and drop this widget into chat_screen.dart under a Cross-Reference
/// answer, or as its own screen reachable from the AppBar the same way
/// UploadDocumentScreen is.
class TimelineEntry {
  final String ref;
  final String date;
  final String? relationToPrevious; // e.g. "amends", "extends", "supersedes"
  const TimelineEntry({required this.ref, required this.date, this.relationToPrevious});
}

class ConflictEntry {
  final String docA;
  final String dateA;
  final String docB;
  final String dateB;
  final String topicHint;
  const ConflictEntry({
    required this.docA,
    required this.dateA,
    required this.docB,
    required this.dateB,
    required this.topicHint,
  });
}

class RelationshipTimelineCard extends StatelessWidget {
  final List<TimelineEntry> timeline;
  final List<ConflictEntry> conflicts;

  const RelationshipTimelineCard({
    super.key,
    required this.timeline,
    this.conflicts = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Document Timeline',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            Text(
              'No dated relationships detected for these documents.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...List.generate(timeline.length, (i) {
              final entry = timeline[i];
              final isLast = i == timeline.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Container(width: 2, height: 28, color: AppColors.border),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.ref}  ·  ${entry.date}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (entry.relationToPrevious != null)
                              Text(
                                entry.relationToPrevious!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (conflicts.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                SizedBox(width: 6),
                Text(
                  'Conflicting information detected',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...conflicts.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${c.docA} says "${c.dateA}", ${c.docB} says "${c.dateB}" '
                    'for a matter involving "${c.topicHint}". No document explicitly '
                    'supersedes the other — worth confirming directly.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

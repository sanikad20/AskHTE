import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// New widget. Renders "GR-2026/23 · p.14"-style chips from the
/// structured page citations retrieval.py now returns (see
/// AgentResult.citations / PageCitation in schemas.py).
///
/// Renamed from the original "CitationChips" name in the delivery
/// pass to PageCitationChips: this codebase already had a
/// CitationChips widget (widgets/citation_chips.dart, sources:
/// List<String>) wired into ExplainableAiPanel — same feature area,
/// different shape (plain source strings vs. page-numbered chips), so
/// keeping both names distinct avoids a class collision instead of
/// silently shadowing one.
///
/// Takes an `onOpenPage` callback rather than hardcoding a PDF viewer
/// package, since none is in this project's pubspec.yaml yet. A
/// common choice is `syncfusion_flutter_pdfviewer` or
/// `flutter_pdfview`'s `gotoPage()`/`onPageChanged` API — until one is
/// wired in, ExplainableAiPanel's default `onOpenPage` just shows the
/// citation in a bottom sheet (see explainable_ai_panel.dart).
class PageCitation {
  final String fileName;
  final int? page;
  const PageCitation({required this.fileName, this.page});

  factory PageCitation.fromJson(Map<String, dynamic> json) => PageCitation(
        fileName: json['fileName'] as String? ?? 'unknown',
        page: (json['page'] as num?)?.toInt(),
      );
}

class PageCitationChips extends StatelessWidget {
  final List<PageCitation> citations;
  final void Function(PageCitation citation) onOpenPage;

  const PageCitationChips({
    super.key,
    required this.citations,
    required this.onOpenPage,
  });

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: citations
          .map(
            (c) => ActionChip(
              avatar: const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
              label: Text(
                c.page != null ? '${c.fileName} · p.${c.page}' : c.fileName,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: AppColors.primary.withOpacity(0.08),
              onPressed: () => onOpenPage(c),
            ),
          )
          .toList(),
    );
  }
}

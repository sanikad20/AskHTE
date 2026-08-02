import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
      spacing: 8,
      runSpacing: 8,
      children: citations.map((c) {
        final labelText = c.page != null ? '${c.fileName} · Page ${c.page}' : c.fileName;
        final displayName = labelText.length > 22 ? '${labelText.substring(0, 22)}…' : labelText;
        return InkWell(
          onTap: () => onOpenPage(c),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 56),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new, size: 12, color: AppColors.primary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );

  }
}

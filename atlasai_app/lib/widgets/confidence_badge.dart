import 'package:flutter/material.dart';

/// Premium Circular Confidence Indicator for AskHTE AI Answers.
/// Green: 80–100% | Orange: 50–79% | Red: < 50%
class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const ConfidenceBadge({super.key, required this.confidence});

  Color get _color {
    if (confidence >= 0.8) return const Color(0xFF10B981); // Green 80-100
    if (confidence >= 0.5) return const Color(0xFFF59E0B); // Orange 50-79
    return const Color(0xFFEF4444); // Red < 50
  }

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(0);
    final clamped = confidence.clamp(0.0, 1.0);

    return Tooltip(
      message: 'RAG Confidence Score: Based on semantic relevance of retrieved authenticated government documents.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Confidence Indicator
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: clamped,
                strokeWidth: 2.5,
                backgroundColor: _color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Confidence $pct%',
              style: TextStyle(
                fontSize: 11.5,
                color: _color,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
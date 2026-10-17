import 'package:flutter/material.dart';

class ProgressBarCard extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final int completedSteps;
  final int totalSteps;
  final bool showHeader;

  const ProgressBarCard({
    super.key,
    required this.progress,
    required this.completedSteps,
    required this.totalSteps,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress ($completedSteps / $totalSteps steps)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '$percentage%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: totalSteps == 0 ? 0 : progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? const Color(0xFF059669) : theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

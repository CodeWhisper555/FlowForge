import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/workflows/domain/models/workflow_enums.dart';

class StepStatusBadge extends StatelessWidget {
  final StepStatus status;
  final bool compact;

  const StepStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  IconData get _icon {
    switch (status) {
      case StepStatus.pending:
        return Icons.hourglass_top_rounded;
      case StepStatus.ready:
        return Icons.play_arrow_rounded;
      case StepStatus.inProgress:
        return Icons.sync_rounded;
      case StepStatus.completed:
        return Icons.check_circle_rounded;
      case StepStatus.blocked:
        return Icons.block_rounded;
      case StepStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getStatusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkflowStatusBadge extends StatelessWidget {
  final WorkflowStatus status;

  const WorkflowStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case WorkflowStatus.active:
        color = const Color(0xFF2563EB);
        break;
      case WorkflowStatus.completed:
        color = const Color(0xFF059669);
        break;
      case WorkflowStatus.archived:
        color = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

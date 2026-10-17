import 'package:flutter/material.dart';
import '../../features/workflows/domain/models/workflow_enums.dart';

class AppColors {
  AppColors._();

  // Status colors
  static const Color statusPending = Color(0xFFF59E0B); // Amber
  static const Color statusReady = Color(0xFF10B981); // Emerald / Teal
  static const Color statusInProgress = Color(0xFF3B82F6); // Blue
  static const Color statusCompleted = Color(0xFF059669); // Dark Emerald
  static const Color statusBlocked = Color(0xFFEF4444); // Red
  static const Color statusCancelled = Color(0xFF6B7280); // Gray

  // Priority colors
  static const Color priorityLow = Color(0xFF10B981);
  static const Color priorityMedium = Color(0xFF3B82F6);
  static const Color priorityHigh = Color(0xFFF97316);
  static const Color priorityUrgent = Color(0xFFDC2626);

  static Color getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return statusPending;
      case StepStatus.ready:
        return statusReady;
      case StepStatus.inProgress:
        return statusInProgress;
      case StepStatus.completed:
        return statusCompleted;
      case StepStatus.blocked:
        return statusBlocked;
      case StepStatus.cancelled:
        return statusCancelled;
    }
  }

  static Color getPriorityColor(WorkflowPriority priority) {
    switch (priority) {
      case WorkflowPriority.low:
        return priorityLow;
      case WorkflowPriority.medium:
        return priorityMedium;
      case WorkflowPriority.high:
        return priorityHigh;
      case WorkflowPriority.urgent:
        return priorityUrgent;
    }
  }
}

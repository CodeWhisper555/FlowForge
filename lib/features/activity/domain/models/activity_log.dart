import 'package:flutter/foundation.dart';

enum ActivityType {
  workflowCreated,
  workflowEdited,
  workflowArchived,
  workflowRestored,
  workflowDeleted,
  stepStarted,
  stepCompleted,
  stepCancelled,
  stepReopened,
  stepBlocked,
  stepUnblocked;

  String get displayName {
    switch (this) {
      case ActivityType.workflowCreated:
        return 'Workflow Created';
      case ActivityType.workflowEdited:
        return 'Workflow Edited';
      case ActivityType.workflowArchived:
        return 'Workflow Archived';
      case ActivityType.workflowRestored:
        return 'Workflow Restored';
      case ActivityType.workflowDeleted:
        return 'Workflow Deleted';
      case ActivityType.stepStarted:
        return 'Step Started';
      case ActivityType.stepCompleted:
        return 'Step Completed';
      case ActivityType.stepCancelled:
        return 'Step Cancelled';
      case ActivityType.stepReopened:
        return 'Step Reopened';
      case ActivityType.stepBlocked:
        return 'Step Blocked';
      case ActivityType.stepUnblocked:
        return 'Step Unblocked';
    }
  }
}

@immutable
class ActivityLog {
  final String id;
  final String userId;
  final String workflowId;
  final String workflowTitle;
  final String? stepId;
  final String? stepTitle;
  final ActivityType type;
  final String description;
  final DateTime timestamp;

  const ActivityLog({
    required this.id,
    required this.userId,
    required this.workflowId,
    required this.workflowTitle,
    this.stepId,
    this.stepTitle,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'workflowId': workflowId,
      'workflowTitle': workflowTitle,
      'stepId': stepId,
      'stepTitle': stepTitle,
      'type': type.name,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      workflowId: map['workflowId'] as String? ?? '',
      workflowTitle: map['workflowTitle'] as String? ?? '',
      stepId: map['stepId'] as String?,
      stepTitle: map['stepTitle'] as String?,
      type: ActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityType.workflowEdited,
      ),
      description: map['description'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

enum StepStatus {
  pending,
  ready,
  inProgress,
  completed,
  blocked,
  cancelled;

  String get displayName {
    switch (this) {
      case StepStatus.pending:
        return 'Pending';
      case StepStatus.ready:
        return 'Ready';
      case StepStatus.inProgress:
        return 'In Progress';
      case StepStatus.completed:
        return 'Completed';
      case StepStatus.blocked:
        return 'Blocked';
      case StepStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActionable => this == StepStatus.ready || this == StepStatus.inProgress;
  bool get isDone => this == StepStatus.completed;
  bool get isTerminated => this == StepStatus.completed || this == StepStatus.cancelled;
}

enum WorkflowPriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case WorkflowPriority.low:
        return 'Low';
      case WorkflowPriority.medium:
        return 'Medium';
      case WorkflowPriority.high:
        return 'High';
      case WorkflowPriority.urgent:
        return 'Urgent';
    }
  }
}

enum WorkflowStatus {
  active,
  completed,
  archived;

  String get displayName {
    switch (this) {
      case WorkflowStatus.active:
        return 'Active';
      case WorkflowStatus.completed:
        return 'Completed';
      case WorkflowStatus.archived:
        return 'Archived';
    }
  }
}

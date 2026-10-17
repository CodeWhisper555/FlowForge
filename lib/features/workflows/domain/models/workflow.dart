import 'package:flutter/foundation.dart';
import 'workflow_enums.dart';
import 'workflow_step.dart';

@immutable
class Workflow {
  final String id;
  final String userId;
  final String title;
  final String description;
  final WorkflowStatus status;
  final WorkflowPriority priority;
  final DateTime? dueDate;
  final List<WorkflowStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const Workflow({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.status = WorkflowStatus.active,
    this.priority = WorkflowPriority.medium,
    this.dueDate,
    this.steps = const [],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  int get totalStepsCount => steps.length;

  int get completedStepsCount =>
      steps.where((step) => step.status == StepStatus.completed).length;

  double get progress {
    if (steps.isEmpty) return 0.0;
    return completedStepsCount / steps.length;
  }

  int get progressPercent => (progress * 100).round();

  bool get isCompleted =>
      steps.isNotEmpty && steps.every((s) => s.status == StepStatus.completed);

  bool get isOverdue {
    if (dueDate == null || status == WorkflowStatus.completed || status == WorkflowStatus.archived) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }

  Workflow copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    WorkflowStatus? status,
    WorkflowPriority? priority,
    DateTime? dueDate,
    List<WorkflowStep>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
  }) {
    return Workflow(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      steps: steps ?? List.unmodifiable(this.steps),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'steps': steps.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Workflow.fromMap(Map<String, dynamic> map) {
    return Workflow(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: WorkflowStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WorkflowStatus.active,
      ),
      priority: WorkflowPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => WorkflowPriority.medium,
      ),
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'] as String) : null,
      steps: (map['steps'] as List<dynamic>?)
              ?.map((e) => WorkflowStep.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      completedAt:
          map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Workflow &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.description == description &&
        other.status == status &&
        other.priority == priority &&
        other.dueDate == dueDate &&
        listEquals(other.steps, steps) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        title,
        description,
        status,
        priority,
        dueDate,
        Object.hashAll(steps),
        createdAt,
        updatedAt,
        completedAt,
      );
}

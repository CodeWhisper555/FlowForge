import 'package:flutter/foundation.dart';
import 'workflow_enums.dart';

@immutable
class WorkflowStep {
  final String id;
  final String title;
  final String description;
  final int order;
  final StepStatus status;
  final List<String> prerequisiteIds;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const WorkflowStep({
    required this.id,
    required this.title,
    this.description = '',
    required this.order,
    this.status = StepStatus.pending,
    this.prerequisiteIds = const [],
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  bool get isOverdue {
    if (dueDate == null || status == StepStatus.completed || status == StepStatus.cancelled) {
      return false;
    }
    return DateTime.now().isAfter(dueDate!);
  }

  WorkflowStep copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    StepStatus? status,
    List<String>? prerequisiteIds,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
  }) {
    return WorkflowStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      status: status ?? this.status,
      prerequisiteIds: prerequisiteIds ?? List.unmodifiable(this.prerequisiteIds),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'order': order,
      'status': status.name,
      'prerequisiteIds': prerequisiteIds,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory WorkflowStep.fromMap(Map<String, dynamic> map) {
    return WorkflowStep(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      status: StepStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => StepStatus.pending,
      ),
      prerequisiteIds: (map['prerequisiteIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'] as String) : null,
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
    return other is WorkflowStep &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.order == order &&
        other.status == status &&
        listEquals(other.prerequisiteIds, prerequisiteIds) &&
        other.dueDate == dueDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        order,
        status,
        Object.hashAll(prerequisiteIds),
        dueDate,
        createdAt,
        updatedAt,
        completedAt,
      );
}

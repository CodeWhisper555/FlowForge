import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow_enums.dart';
import 'package:workflow_manager/features/workflows/domain/models/workflow_step.dart';

@immutable
class TemplateStep {
  final String tempId;
  final String title;
  final String description;
  final int order;
  final List<String> prerequisiteTempIds;

  const TemplateStep({
    required this.tempId,
    required this.title,
    this.description = '',
    required this.order,
    this.prerequisiteTempIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'tempId': tempId,
        'title': title,
        'description': description,
        'order': order,
        'prerequisiteTempIds': prerequisiteTempIds,
      };

  factory TemplateStep.fromMap(Map<String, dynamic> map) => TemplateStep(
        tempId: map['tempId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        order: (map['order'] as num?)?.toInt() ?? 0,
        prerequisiteTempIds: (map['prerequisiteTempIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}

@immutable
class WorkflowTemplate {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final WorkflowPriority defaultPriority;
  final List<TemplateStep> steps;
  final DateTime createdAt;

  const WorkflowTemplate({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.category = 'General',
    this.defaultPriority = WorkflowPriority.medium,
    this.steps = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'category': category,
        'defaultPriority': defaultPriority.name,
        'steps': steps.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkflowTemplate.fromMap(Map<String, dynamic> map) => WorkflowTemplate(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        defaultPriority: WorkflowPriority.values.firstWhere(
          (e) => e.name == map['defaultPriority'],
          orElse: () => WorkflowPriority.medium,
        ),
        steps: (map['steps'] as List<dynamic>?)
                ?.map((e) => TemplateStep.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        createdAt: map['createdAt'] != null
            ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
            : DateTime.now(),
      );

  /// Instantiates a new independent Workflow with fresh IDs and mapped dependencies.
  Workflow instantiateWorkflow({
    required String targetUserId,
    String? customTitle,
    DateTime? dueDate,
  }) {
    const uuid = Uuid();
    final newWorkflowId = uuid.v4();
    final now = DateTime.now();

    // Map old tempId to fresh stepId
    final idMap = <String, String>{};
    for (final step in steps) {
      idMap[step.tempId] = uuid.v4();
    }

    final freshSteps = steps.map((s) {
      final freshId = idMap[s.tempId]!;
      final freshPrereqIds = s.prerequisiteTempIds
          .map((tempId) => idMap[tempId])
          .whereType<String>()
          .toList();

      return WorkflowStep(
        id: freshId,
        title: s.title,
        description: s.description,
        order: s.order,
        status: freshPrereqIds.isEmpty ? StepStatus.ready : StepStatus.pending,
        prerequisiteIds: freshPrereqIds,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    return Workflow(
      id: newWorkflowId,
      userId: targetUserId,
      title: customTitle ?? title,
      description: description,
      status: WorkflowStatus.active,
      priority: defaultPriority,
      dueDate: dueDate,
      steps: freshSteps,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates a WorkflowTemplate from an existing Workflow
  factory WorkflowTemplate.fromWorkflow(
    Workflow workflow, {
    String? templateTitle,
    String? category,
  }) {
    const uuid = Uuid();
    final templateSteps = workflow.steps.map((s) {
      return TemplateStep(
        tempId: s.id,
        title: s.title,
        description: s.description,
        order: s.order,
        prerequisiteTempIds: List.from(s.prerequisiteIds),
      );
    }).toList();

    return WorkflowTemplate(
      id: uuid.v4(),
      userId: workflow.userId,
      title: templateTitle ?? workflow.title,
      description: workflow.description,
      category: category ?? 'Custom',
      defaultPriority: workflow.priority,
      steps: templateSteps,
      createdAt: DateTime.now(),
    );
  }
}

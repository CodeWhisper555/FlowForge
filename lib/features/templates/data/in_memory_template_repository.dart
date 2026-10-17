import 'dart:async';
import '../../workflows/domain/models/workflow_enums.dart';
import '../domain/models/workflow_template.dart';
import '../domain/repositories/template_repository.dart';

class InMemoryTemplateRepository implements TemplateRepository {
  final List<WorkflowTemplate> _templates = [];
  final _controller = StreamController<List<WorkflowTemplate>>.broadcast();

  InMemoryTemplateRepository() {
    _seedTemplates();
  }

  void _seedTemplates() {
    final now = DateTime.now();
    _templates.addAll([
      WorkflowTemplate(
        id: 'tpl-software-lifecycle',
        userId: 'system',
        title: 'Software Feature Delivery',
        description: 'Standard agile pipeline with branching code review & testing phases.',
        category: 'Engineering',
        defaultPriority: WorkflowPriority.high,
        steps: const [
          TemplateStep(tempId: 't1', title: 'Feature Specifications', order: 0),
          TemplateStep(tempId: 't2', title: 'Architecture & Schema Design', order: 1, prerequisiteTempIds: ['t1']),
          TemplateStep(tempId: 't3', title: 'Core Implementation', order: 2, prerequisiteTempIds: ['t2']),
          TemplateStep(tempId: 't4', title: 'Peer Code Review', order: 3, prerequisiteTempIds: ['t3']),
          TemplateStep(tempId: 't5', title: 'Automated & Manual QA', order: 4, prerequisiteTempIds: ['t4']),
          TemplateStep(tempId: 't6', title: 'Deploy to Production', order: 5, prerequisiteTempIds: ['t5']),
        ],
        createdAt: now,
      ),
      WorkflowTemplate(
        id: 'tpl-research-paper',
        userId: 'system',
        title: 'Research Paper Publication',
        description: 'Academic workflow covering hypothesis, research, drafting, and submission.',
        category: 'Academia',
        defaultPriority: WorkflowPriority.medium,
        steps: const [
          TemplateStep(tempId: 'r1', title: 'Literature Review & Hypothesis', order: 0),
          TemplateStep(tempId: 'r2', title: 'Experimentation & Data Collection', order: 1, prerequisiteTempIds: ['r1']),
          TemplateStep(tempId: 'r3', title: 'Data Analysis & Chart Generation', order: 2, prerequisiteTempIds: ['r2']),
          TemplateStep(tempId: 'r4', title: 'Drafting Manuscript', order: 3, prerequisiteTempIds: ['r3']),
          TemplateStep(tempId: 'r5', title: 'Internal Review & Edits', order: 4, prerequisiteTempIds: ['r4']),
          TemplateStep(tempId: 'r6', title: 'Final Conference / Journal Submission', order: 5, prerequisiteTempIds: ['r5']),
        ],
        createdAt: now,
      ),
    ]);
  }

  @override
  Stream<List<WorkflowTemplate>> watchTemplates(String userId) async* {
    yield _filter(userId);
    yield* _controller.stream.map((_) => _filter(userId));
  }

  List<WorkflowTemplate> _filter(String userId) {
    // Show system templates + user templates
    return _templates.where((t) => t.userId == 'system' || t.userId == userId).toList();
  }

  @override
  Future<void> saveTemplate(WorkflowTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _templates[index] = template;
    } else {
      _templates.add(template);
    }
    _controller.add(List.unmodifiable(_templates));
  }

  @override
  Future<void> deleteTemplate(String userId, String templateId) async {
    _templates.removeWhere((t) => t.id == templateId && t.userId == userId);
    _controller.add(List.unmodifiable(_templates));
  }

  void dispose() {
    _controller.close();
  }
}

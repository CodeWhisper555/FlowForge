import '../models/workflow_template.dart';

abstract class TemplateRepository {
  Stream<List<WorkflowTemplate>> watchTemplates(String userId);
  Future<void> saveTemplate(WorkflowTemplate template);
  Future<void> deleteTemplate(String userId, String templateId);
}

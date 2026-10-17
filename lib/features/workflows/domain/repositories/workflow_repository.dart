import '../models/workflow.dart';
import '../models/workflow_enums.dart';

abstract class WorkflowRepository {
  Stream<List<Workflow>> watchWorkflows(String userId, {WorkflowStatus? statusFilter});
  Future<List<Workflow>> getWorkflows(String userId, {WorkflowStatus? statusFilter});
  Stream<Workflow?> watchWorkflow(String userId, String workflowId);
  Future<Workflow?> getWorkflow(String userId, String workflowId);
  Future<void> createWorkflow(Workflow workflow);
  Future<void> updateWorkflow(Workflow workflow);
  Future<void> deleteWorkflow(String userId, String workflowId);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/in_memory_workflow_repository.dart';
import '../../domain/engine/workflow_engine.dart';
import '../../domain/models/workflow.dart';
import '../../domain/models/workflow_enums.dart';
import '../../domain/repositories/workflow_repository.dart';

final workflowEngineProvider = Provider<WorkflowEngine>((ref) {
  return const WorkflowEngine();
});

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  return InMemoryWorkflowRepository();
});

final workflowsStreamProvider =
    StreamProvider.family<List<Workflow>, WorkflowStatus?>((ref, statusFilter) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const []);
  }
  final repo = ref.watch(workflowRepositoryProvider);
  return repo.watchWorkflows(user.id, statusFilter: statusFilter);
});

final workflowDetailsStreamProvider =
    StreamProvider.family<Workflow?, String>((ref, workflowId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(null);
  }
  final repo = ref.watch(workflowRepositoryProvider);
  return repo.watchWorkflow(user.id, workflowId);
});

class DashboardMetrics {
  final int totalCount;
  final int activeCount;
  final int completedCount;
  final int overdueCount;
  final List<Workflow> recentWorkflows;

  const DashboardMetrics({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
    required this.overdueCount,
    required this.recentWorkflows,
  });
}

final dashboardMetricsProvider = Provider<AsyncValue<DashboardMetrics>>((ref) {
  final workflowsAsync = ref.watch(workflowsStreamProvider(null));

  return workflowsAsync.whenData((workflows) {
    final active = workflows.where((w) => w.status == WorkflowStatus.active).length;
    final completed = workflows.where((w) => w.status == WorkflowStatus.completed).length;
    final overdue = workflows.where((w) => w.isOverdue).length;

    final sorted = List<Workflow>.from(workflows)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return DashboardMetrics(
      totalCount: workflows.length,
      activeCount: active,
      completedCount: completed,
      overdueCount: overdue,
      recentWorkflows: sorted.take(5).toList(),
    );
  });
});

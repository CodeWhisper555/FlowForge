import '../../../workflows/domain/models/workflow.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<void> scheduleWorkflowReminder(Workflow workflow);
  Future<void> cancelWorkflowReminder(String workflowId);
  List<String> evaluateDeadlineAlerts(List<Workflow> workflows);
}

class InAppNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleWorkflowReminder(Workflow workflow) async {}

  @override
  Future<void> cancelWorkflowReminder(String workflowId) async {}

  @override
  List<String> evaluateDeadlineAlerts(List<Workflow> workflows) {
    final alerts = <String>[];
    final now = DateTime.now();

    for (final wf in workflows) {
      if (wf.dueDate != null) {
        if (wf.isOverdue) {
          alerts.add('Workflow "${wf.title}" is overdue (due: ${wf.dueDate!.toIso8601String().split("T").first})');
        } else if (wf.dueDate!.difference(now).inDays <= 2 && !wf.isCompleted) {
          alerts.add('Workflow "${wf.title}" is due soon in ${wf.dueDate!.difference(now).inDays} days');
        }
      }
    }

    return alerts;
  }
}

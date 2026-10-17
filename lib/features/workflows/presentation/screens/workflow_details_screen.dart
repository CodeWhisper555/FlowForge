import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/workflow_exceptions.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../shared/layout/responsive_scaffold.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/progress_bar_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../activity/domain/models/activity_log.dart';
import '../../../activity/presentation/controllers/activity_providers.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../templates/domain/models/workflow_template.dart';
import '../../../templates/presentation/controllers/template_providers.dart';
import '../../domain/engine/workflow_engine.dart';
import '../../domain/models/workflow.dart';
import '../../domain/models/workflow_enums.dart';
import '../../domain/models/workflow_step.dart';
import '../controllers/workflow_providers.dart';
import '../widgets/step_edit_dialog.dart';

class WorkflowDetailsScreen extends ConsumerStatefulWidget {
  final String workflowId;

  const WorkflowDetailsScreen({super.key, required this.workflowId});

  @override
  ConsumerState<WorkflowDetailsScreen> createState() => _WorkflowDetailsScreenState();
}

class _WorkflowDetailsScreenState extends ConsumerState<WorkflowDetailsScreen> {
  WorkflowEngine get _engine => ref.read(workflowEngineProvider);

  Future<void> _updateStepStatus(
    Workflow workflow,
    WorkflowStep step,
    StepStatus targetStatus,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    bool resetDescendants = false;

    // Warning and option when reopening a completed step with descendants
    if (step.status == StepStatus.completed &&
        (targetStatus == StepStatus.ready ||
            targetStatus == StepStatus.inProgress ||
            targetStatus == StepStatus.pending)) {
      final downstreamIds = _engine.getDownstreamStepIds(workflow, step.id);
      final hasCompletedDescendants = workflow.steps
          .any((s) => downstreamIds.contains(s.id) && s.status == StepStatus.completed);

      if (hasCompletedDescendants) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reopening Completed Step'),
            content: Text(
              'Reopening "${step.title}" affects dependent steps down the line.\n\n'
              'Do you want to reset completed downstream steps back to Pending, or preserve completed work?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Preserve Work (Default)'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset Downstream Steps'),
              ),
            ],
          ),
        );

        if (choice == null) return; // User cancelled dialog
        resetDescendants = choice;
      }
    }

    try {
      final updatedWorkflow = _engine.updateStepStatus(
        workflow,
        step.id,
        targetStatus,
        resetCompletedDescendants: resetDescendants,
      );

      await ref.read(workflowRepositoryProvider).updateWorkflow(updatedWorkflow);

      // Log activity
      ActivityType activityType;
      switch (targetStatus) {
        case StepStatus.inProgress:
          activityType = ActivityType.stepStarted;
          break;
        case StepStatus.completed:
          activityType = ActivityType.stepCompleted;
          break;
        case StepStatus.cancelled:
          activityType = ActivityType.stepCancelled;
          break;
        case StepStatus.blocked:
          activityType = ActivityType.stepBlocked;
          break;
        case StepStatus.ready:
        case StepStatus.pending:
          activityType = step.status == StepStatus.blocked
              ? ActivityType.stepUnblocked
              : ActivityType.stepReopened;
          break;
      }

      await ref.read(activityRepositoryProvider).logActivity(
            ActivityLog(
              id: const Uuid().v4(),
              userId: user.id,
              workflowId: workflow.id,
              workflowTitle: workflow.title,
              stepId: step.id,
              stepTitle: step.title,
              type: activityType,
              description:
                  'Changed step "${step.title}" status from ${step.status.displayName} to ${targetStatus.displayName}',
              timestamp: DateTime.now(),
            ),
          );
    } on WorkflowException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _addStep(Workflow workflow) async {
    final newStep = await StepEditDialog.show(
      context,
      workflow: workflow,
    );

    if (newStep == null) return;

    try {
      final updatedWorkflow = _engine.addStep(workflow, newStep);
      await ref.read(workflowRepositoryProvider).updateWorkflow(updatedWorkflow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added step "${newStep.title}"')),
        );
      }
    } on WorkflowException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editStep(Workflow workflow, WorkflowStep step) async {
    final updatedStep = await StepEditDialog.show(
      context,
      workflow: workflow,
      existingStep: step,
    );

    if (updatedStep == null) return;

    try {
      final updatedWorkflow = _engine.updateStep(workflow, updatedStep);
      await ref.read(workflowRepositoryProvider).updateWorkflow(updatedWorkflow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated step "${updatedStep.title}"')),
        );
      }
    } on WorkflowException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteStep(Workflow workflow, WorkflowStep step) async {
    final dependentSteps = workflow.steps
        .where((s) => s.prerequisiteIds.contains(step.id))
        .map((s) => s.title)
        .toList();

    bool cascade = false;

    if (dependentSteps.isNotEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dependent Steps Detected'),
          content: Text(
            'The following steps depend on "${step.title}":\n\n'
            '• ${dependentSteps.join('\n• ')}\n\n'
            'Do you want to automatically remove "${step.title}" from their prerequisites and proceed with deletion?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel Deletion'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove Dependency & Delete'),
            ),
          ],
        ),
      );

      if (choice != true) return;
      cascade = true;
    } else {
      final confirm = await showConfirmationDialog(
        context: context,
        title: 'Delete Step?',
        message: 'Are you sure you want to delete "${step.title}"?',
        confirmLabel: 'Delete',
        isDestructive: true,
      );
      if (confirm != true) return;
    }

    try {
      final updatedWorkflow = _engine.deleteStep(
        workflow,
        step.id,
        cascadeRemoveDependencies: cascade,
      );
      await ref.read(workflowRepositoryProvider).updateWorkflow(updatedWorkflow);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted step "${step.title}"')),
        );
      }
    } on WorkflowException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAsTemplate(Workflow workflow) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final controller = TextEditingController(text: '${workflow.title} Template');
    final categoryController = TextEditingController(text: 'General');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Reusable Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Template Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save Template'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final template = WorkflowTemplate.fromWorkflow(
        workflow,
        templateTitle: controller.text.trim(),
        category: categoryController.text.trim(),
      );

      await ref.read(templateRepositoryProvider).saveTemplate(template);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved template "${template.title}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wfAsync = ref.watch(workflowDetailsStreamProvider(widget.workflowId));
    final theme = Theme.of(context);

    return wfAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Workflow Details')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (workflow) {
        if (workflow == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Workflow not found or deleted.')),
          );
        }

        return ResponsiveScaffold(
          selectedIndex: 1,
          title: workflow.title,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Workflow Info',
              onPressed: () => context.push('/workflows/${workflow.id}/edit'),
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                switch (val) {
                  case 'template':
                    _saveAsTemplate(workflow);
                    break;
                  case 'delete':
                    _deleteEntireWorkflow(workflow);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'template',
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Save as Template'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Workflow', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addStep(workflow),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Add Step'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workflow.title,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (workflow.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      workflow.description,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                WorkflowStatusBadge(status: workflow.status),
                                const SizedBox(height: 8),
                                PriorityBadge(priority: workflow.priority),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: workflow.isOverdue
                                  ? Colors.red
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Due: ${DateFormatters.formatShortDate(workflow.dueDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: workflow.isOverdue
                                    ? Colors.red
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontWeight: workflow.isOverdue
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Icon(
                              Icons.update,
                              size: 15,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Updated ${DateFormatters.formatRelative(workflow.updatedAt)}',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ProgressBarCard(
                          progress: workflow.progress,
                          completedSteps: workflow.completedStepsCount,
                          totalSteps: workflow.totalStepsCount,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Steps Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Workflow Steps (${workflow.steps.length})',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _addStep(workflow),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Step'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (workflow.steps.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.checklist_rounded,
                    title: 'No Steps Defined Yet',
                    description:
                        'Add ordered or dependent steps to build the workflow pipeline.',
                    actionLabel: 'Add First Step',
                    onAction: () => _addStep(workflow),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workflow.steps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final step = workflow.steps[index];
                      return _buildStepCard(context, workflow, step, index);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepCard(
    BuildContext context,
    Workflow workflow,
    WorkflowStep step,
    int index,
  ) {
    final theme = Theme.of(context);
    final prereqSummary = _engine.getPrerequisiteSummary(workflow, step.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: step.status == StepStatus.ready
              ? const Color(0xFF10B981)
              : step.status == StepStatus.inProgress
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
          width: step.status.isActionable ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Step Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (step.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StepStatusBadge(status: step.status),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        _editStep(workflow, step);
                        break;
                      case 'delete':
                        _deleteStep(workflow, step);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Step & Dependencies'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Delete Step', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dependencies row
            if (step.prerequisiteIds.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Prerequisites:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  ...prereqSummary.satisfiedPrerequisites.map((p) => Chip(
                        avatar: const Icon(Icons.check, size: 13, color: Colors.white),
                        label: Text(p.title),
                        backgroundColor: const Color(0xFF059669),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )),
                  ...prereqSummary.pendingPrerequisites.map((p) => Chip(
                        avatar: const Icon(Icons.hourglass_empty, size: 13, color: Colors.white),
                        label: Text(p.title),
                        backgroundColor: const Color(0xFFF59E0B),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Why is it pending helper banner
            if (step.status == StepStatus.pending && prereqSummary.waitingReason.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prereqSummary.waitingReason,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons Row
            const Divider(height: 18),
            Row(
              children: [
                if (step.dueDate != null) ...[
                  Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatters.formatShortDate(step.dueDate),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
                const Spacer(),
                _buildPermittedActionButtons(context, workflow, step),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermittedActionButtons(
    BuildContext context,
    Workflow workflow,
    WorkflowStep step,
  ) {
    switch (step.status) {
      case StepStatus.ready:
        return Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.inProgress),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.completed),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            OutlinedButton(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.blocked),
              child: const Text('Block'),
            ),
          ],
        );

      case StepStatus.inProgress:
        return Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.completed),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            OutlinedButton(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.blocked),
              child: const Text('Block'),
            ),
            OutlinedButton(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.cancelled),
              child: const Text('Cancel'),
            ),
          ],
        );

      case StepStatus.pending:
        return Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.cancelled),
              child: const Text('Cancel Step'),
            ),
          ],
        );

      case StepStatus.completed:
        return Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.inProgress),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reopen Step'),
            ),
          ],
        );

      case StepStatus.blocked:
        return Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.ready),
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('Unblock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            OutlinedButton(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.cancelled),
              child: const Text('Cancel Step'),
            ),
          ],
        );

      case StepStatus.cancelled:
        return Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _updateStepStatus(workflow, step, StepStatus.ready),
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Reopen Step'),
            ),
          ],
        );
    }
  }

  Future<void> _deleteEntireWorkflow(Workflow workflow) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirm = await showConfirmationDialog(
      context: context,
      title: 'Delete Workflow?',
      message: 'Are you sure you want to permanently delete "${workflow.title}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirm == true) {
      await ref.read(workflowRepositoryProvider).deleteWorkflow(user.id, workflow.id);
      if (mounted) {
        context.go('/workflows');
      }
    }
  }
}

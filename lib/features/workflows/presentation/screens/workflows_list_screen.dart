import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
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
import '../../domain/models/workflow.dart';
import '../../domain/models/workflow_enums.dart';
import '../controllers/workflow_providers.dart';

class WorkflowsListScreen extends ConsumerStatefulWidget {
  const WorkflowsListScreen({super.key});

  @override
  ConsumerState<WorkflowsListScreen> createState() => _WorkflowsListScreenState();
}

class _WorkflowsListScreenState extends ConsumerState<WorkflowsListScreen> {
  WorkflowStatus? _selectedStatus; // null = all
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _duplicateWorkflow(Workflow wf) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    const uuid = Uuid();
    final newId = uuid.v4();

    // Map old step IDs to new step IDs
    final stepIdMap = <String, String>{};
    for (final s in wf.steps) {
      stepIdMap[s.id] = uuid.v4();
    }

    final duplicatedSteps = wf.steps.map((s) {
      final freshId = stepIdMap[s.id]!;
      final mappedPrereqs = s.prerequisiteIds
          .map((id) => stepIdMap[id])
          .whereType<String>()
          .toList();

      return s.copyWith(
        id: freshId,
        status: mappedPrereqs.isEmpty ? StepStatus.ready : StepStatus.pending,
        prerequisiteIds: mappedPrereqs,
        createdAt: now,
        updatedAt: now,
        clearCompletedAt: true,
      );
    }).toList();

    final duplicated = wf.copyWith(
      id: newId,
      userId: user.id,
      title: '${wf.title} (Copy)',
      status: WorkflowStatus.active,
      steps: duplicatedSteps,
      createdAt: now,
      updatedAt: now,
      clearCompletedAt: true,
    );

    await ref.read(workflowRepositoryProvider).createWorkflow(duplicated);

    // Log activity
    await ref.read(activityRepositoryProvider).logActivity(
          ActivityLog(
            id: const Uuid().v4(),
            userId: user.id,
            workflowId: newId,
            workflowTitle: duplicated.title,
            type: ActivityType.workflowCreated,
            description: 'Duplicated workflow from "${wf.title}"',
            timestamp: now,
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${wf.title}" successfully')),
      );
    }
  }

  Future<void> _toggleArchive(Workflow wf) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final isArchiving = wf.status != WorkflowStatus.archived;
    final updated = wf.copyWith(
      status: isArchiving ? WorkflowStatus.archived : WorkflowStatus.active,
      updatedAt: DateTime.now(),
    );

    await ref.read(workflowRepositoryProvider).updateWorkflow(updated);

    await ref.read(activityRepositoryProvider).logActivity(
          ActivityLog(
            id: const Uuid().v4(),
            userId: user.id,
            workflowId: wf.id,
            workflowTitle: wf.title,
            type: isArchiving
                ? ActivityType.workflowArchived
                : ActivityType.workflowRestored,
            description: isArchiving
                ? 'Archived workflow "${wf.title}"'
                : 'Restored workflow "${wf.title}"',
            timestamp: DateTime.now(),
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArchiving
                ? 'Workflow archived'
                : 'Workflow restored to active',
          ),
        ),
      );
    }
  }

  Future<void> _deleteWorkflow(Workflow wf) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Workflow?',
      message:
          'Are you sure you want to permanently delete "${wf.title}" and all its ${wf.steps.length} steps? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await ref.read(workflowRepositoryProvider).deleteWorkflow(user.id, wf.id);

      await ref.read(activityRepositoryProvider).logActivity(
            ActivityLog(
              id: const Uuid().v4(),
              userId: user.id,
              workflowId: wf.id,
              workflowTitle: wf.title,
              type: ActivityType.workflowDeleted,
              description: 'Permanently deleted workflow "${wf.title}"',
              timestamp: DateTime.now(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${wf.title}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflowsAsync = ref.watch(workflowsStreamProvider(_selectedStatus));
    final theme = Theme.of(context);

    return ResponsiveScaffold(
      selectedIndex: 1,
      title: 'Workflows',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/workflows/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Workflow'),
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            color: theme.cardTheme.color,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search workflows...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedStatus == null,
                        onSelected: (_) => setState(() => _selectedStatus = null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Active'),
                        selected: _selectedStatus == WorkflowStatus.active,
                        onSelected: (_) => setState(() => _selectedStatus = WorkflowStatus.active),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Completed'),
                        selected: _selectedStatus == WorkflowStatus.completed,
                        onSelected: (_) =>
                            setState(() => _selectedStatus = WorkflowStatus.completed),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Archived'),
                        selected: _selectedStatus == WorkflowStatus.archived,
                        onSelected: (_) =>
                            setState(() => _selectedStatus = WorkflowStatus.archived),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Workflows Content
          Expanded(
            child: workflowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading workflows: $err')),
              data: (workflows) {
                final filtered = workflows.where((wf) {
                  if (_searchQuery.isEmpty) return true;
                  return wf.title.toLowerCase().contains(_searchQuery) ||
                      wf.description.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: _searchQuery.isEmpty ? 'No Workflows Found' : 'No Matching Workflows',
                    description: _searchQuery.isEmpty
                        ? 'Create a new workflow or select a different filter.'
                        : 'No workflows match "$_searchQuery". Try a different search query.',
                    actionLabel: _searchQuery.isEmpty ? 'Create Workflow' : null,
                    onAction: _searchQuery.isEmpty ? () => context.push('/workflows/create') : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final wf = filtered[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/workflows/${wf.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
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
                                          wf.title,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (wf.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            wf.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (val) {
                                      switch (val) {
                                        case 'open':
                                          context.push('/workflows/${wf.id}');
                                          break;
                                        case 'duplicate':
                                          _duplicateWorkflow(wf);
                                          break;
                                        case 'archive':
                                          _toggleArchive(wf);
                                          break;
                                        case 'delete':
                                          _deleteWorkflow(wf);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'open',
                                        child: Row(
                                          children: [
                                            Icon(Icons.open_in_new, size: 18),
                                            SizedBox(width: 8),
                                            Text('Open Details'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'duplicate',
                                        child: Row(
                                          children: [
                                            Icon(Icons.copy, size: 18),
                                            SizedBox(width: 8),
                                            Text('Duplicate Workflow'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Row(
                                          children: [
                                            Icon(
                                              wf.status == WorkflowStatus.archived
                                                  ? Icons.unarchive
                                                  : Icons.archive,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              wf.status == WorkflowStatus.archived
                                                  ? 'Restore'
                                                  : 'Archive',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                color: Colors.red, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  WorkflowStatusBadge(status: wf.status),
                                  PriorityBadge(priority: wf.priority, compact: true),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: wf.isOverdue
                                            ? Colors.red
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormatters.formatShortDate(wf.dueDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: wf.isOverdue
                                              ? Colors.red
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                          fontWeight: wf.isOverdue
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ProgressBarCard(
                                progress: wf.progress,
                                completedSteps: wf.completedStepsCount,
                                totalSteps: wf.totalStepsCount,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

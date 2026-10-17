import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/layout/responsive_scaffold.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../activity/domain/models/activity_log.dart';
import '../../../activity/presentation/controllers/activity_providers.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../workflows/presentation/controllers/workflow_providers.dart';
import '../../domain/models/workflow_template.dart';
import '../controllers/template_providers.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Future<void> _instantiateTemplate(
    BuildContext context,
    WidgetRef ref,
    WorkflowTemplate template,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final titleController = TextEditingController(text: template.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Workflow from Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new independent workflow will be created with fresh IDs for all ${template.steps.length} steps.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Workflow Title'),
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
            child: const Text('Create Workflow'),
          ),
        ],
      ),
    );

    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      final newWorkflow = template.instantiateWorkflow(
        targetUserId: user.id,
        customTitle: titleController.text.trim(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );

      await ref.read(workflowRepositoryProvider).createWorkflow(newWorkflow);

      await ref.read(activityRepositoryProvider).logActivity(
            ActivityLog(
              id: const Uuid().v4(),
              userId: user.id,
              workflowId: newWorkflow.id,
              workflowTitle: newWorkflow.title,
              type: ActivityType.workflowCreated,
              description: 'Created workflow from template "${template.title}"',
              timestamp: DateTime.now(),
            ),
          );

      if (context.mounted) {
        context.push('/workflows/${newWorkflow.id}');
      }
    }
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    WorkflowTemplate template,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete Template?',
      message: 'Are you sure you want to delete template "${template.title}"?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await ref.read(templateRepositoryProvider).deleteTemplate(user.id, template.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesStreamProvider);
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return ResponsiveScaffold(
      selectedIndex: 2,
      title: 'Workflow Templates',
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading templates: $err')),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.copy_all_outlined,
              title: 'No Templates Available',
              description:
                  'Templates let you bootstrap new pipelines with pre-configured step dependency graphs.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Configured Workflow Blueprints',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Instantiate proven workflows with predefined steps, branch dependencies, and default configurations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.25,
                      ),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final tpl = templates[index];
                        final isCustom = tpl.userId != 'system' && tpl.userId == user?.id;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tpl.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    PriorityBadge(priority: tpl.defaultPriority, compact: true),
                                    if (isCustom) ...[
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        tooltip: 'Delete Template',
                                        onPressed: () => _deleteTemplate(context, ref, tpl),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tpl.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    tpl.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${tpl.steps.length} Steps',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _instantiateTemplate(context, ref, tpl),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                      label: const Text('Use Template'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

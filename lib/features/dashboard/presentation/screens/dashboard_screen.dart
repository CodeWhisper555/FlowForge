import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../shared/layout/responsive_scaffold.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/priority_badge.dart';
import '../../../../shared/widgets/progress_bar_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../workflows/presentation/controllers/workflow_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final theme = Theme.of(context);

    return ResponsiveScaffold(
      selectedIndex: 0,
      title: 'Workflow Overview',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/workflows/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Workflow'),
      ),
      body: metricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading dashboard: $err'),
        ),
        data: (metrics) {
          if (metrics.totalCount == 0) {
            return EmptyStateWidget(
              icon: Icons.account_tree_outlined,
              title: 'No Workflows Yet',
              description:
                  'Create your first workflow or explore templates to organize your project steps and dependencies.',
              actionLabel: 'Create Workflow',
              onAction: () => context.push('/workflows/create'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 900
                        ? 4
                        : width > 500
                            ? 2
                            : 1;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.7,
                      children: [
                        _buildMetricCard(
                          context,
                          title: 'Total Workflows',
                          value: '${metrics.totalCount}',
                          icon: Icons.folder_copy_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        _buildMetricCard(
                          context,
                          title: 'Active Workflows',
                          value: '${metrics.activeCount}',
                          icon: Icons.play_circle_outline_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                        _buildMetricCard(
                          context,
                          title: 'Completed',
                          value: '${metrics.completedCount}',
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF059669),
                        ),
                        _buildMetricCard(
                          context,
                          title: 'Overdue Workflows',
                          value: '${metrics.overdueCount}',
                          icon: Icons.warning_amber_rounded,
                          color: metrics.overdueCount > 0
                              ? const Color(0xFFDC2626)
                              : Colors.grey.shade600,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Quick Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.push('/workflows/create'),
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Create Custom Workflow'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/templates'),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Start from Template'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/workflows'),
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text('View All Workflows'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Recently Updated Workflows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recently Updated Workflows',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/workflows'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.recentWorkflows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final wf = metrics.recentWorkflows[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/workflows/${wf.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
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
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      WorkflowStatusBadge(status: wf.status),
                                      const SizedBox(height: 6),
                                      PriorityBadge(priority: wf.priority, compact: true),
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
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 14,
                                        color: wf.isOverdue
                                            ? Colors.red
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormatters.formatShortDate(wf.dueDate),
                                        style: TextStyle(
                                          fontSize: 12,
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
                                  Text(
                                    'Updated ${DateFormatters.formatRelative(wf.updatedAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

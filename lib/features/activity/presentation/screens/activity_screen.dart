import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/date_formatters.dart';
import '../../../../shared/layout/responsive_scaffold.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../domain/models/activity_log.dart';
import '../controllers/activity_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  IconData _getIconForActivity(ActivityType type) {
    switch (type) {
      case ActivityType.workflowCreated:
        return Icons.add_circle_outline;
      case ActivityType.workflowEdited:
        return Icons.edit_note_outlined;
      case ActivityType.workflowArchived:
        return Icons.archive_outlined;
      case ActivityType.workflowRestored:
        return Icons.unarchive_outlined;
      case ActivityType.workflowDeleted:
        return Icons.delete_outline;
      case ActivityType.stepStarted:
        return Icons.play_arrow_rounded;
      case ActivityType.stepCompleted:
        return Icons.check_circle_outline_rounded;
      case ActivityType.stepCancelled:
        return Icons.cancel_outlined;
      case ActivityType.stepReopened:
        return Icons.replay_rounded;
      case ActivityType.stepBlocked:
        return Icons.block_rounded;
      case ActivityType.stepUnblocked:
        return Icons.lock_open_rounded;
    }
  }

  Color _getColorForActivity(ActivityType type) {
    switch (type) {
      case ActivityType.workflowCreated:
        return const Color(0xFF2563EB);
      case ActivityType.stepCompleted:
        return const Color(0xFF059669);
      case ActivityType.stepStarted:
        return const Color(0xFF3B82F6);
      case ActivityType.stepBlocked:
        return const Color(0xFFEF4444);
      case ActivityType.stepCancelled:
      case ActivityType.workflowDeleted:
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(recentActivitiesStreamProvider);
    final theme = Theme.of(context);

    return ResponsiveScaffold(
      selectedIndex: 3,
      title: 'Activity History',
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading activity: $err')),
        data: (activities) {
          if (activities.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history_rounded,
              title: 'No Activity Recorded Yet',
              description:
                  'Actions like starting, completing, or editing workflow steps will appear in this timeline.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              final color = _getColorForActivity(act.type);
              final icon = _getIconForActivity(act.type);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline bar and dot
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                          ),
                          child: Icon(icon, size: 18, color: color),
                        ),
                        if (index < activities.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Activity content card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      act.type.displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      DateFormatters.formatRelative(act.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  act.description,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Icon(
                                      Icons.account_tree_outlined,
                                      size: 13,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    InkWell(
                                      onTap: () => context.push('/workflows/${act.workflowId}'),
                                      child: Text(
                                        act.workflowTitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (act.stepTitle != null) ...[
                                      const Text('•', style: TextStyle(color: Colors.grey)),
                                      Text(
                                        'Step: ${act.stepTitle}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

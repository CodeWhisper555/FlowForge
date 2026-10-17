import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/controllers/auth_providers.dart';

class ResponsiveScaffold extends ConsumerWidget {
  final Widget body;
  final int selectedIndex;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/workflows');
        break;
      case 2:
        context.go('/templates');
        break;
      case 3:
        context.go('/activity');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDemoMode = ref.watch(isDemoModeProvider);
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (isDemoMode) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, size: 13, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'DEV MOCK MODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (actions != null) ...actions!,
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  user.displayName ?? user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign Out',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onDestinationSelected(context, index),
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.schema_outlined),
                  selectedIcon: Icon(Icons.schema_rounded),
                  label: Text('Workflows'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.copy_all_outlined),
                  selectedIcon: Icon(Icons.copy_all_rounded),
                  label: Text('Templates'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: Text('Activity'),
                ),
              ],
            ),
          if (isWide) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onDestinationSelected(context, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.schema_outlined),
                  selectedIcon: Icon(Icons.schema_rounded),
                  label: 'Workflows',
                ),
                NavigationDestination(
                  icon: Icon(Icons.copy_all_outlined),
                  selectedIcon: Icon(Icons.copy_all_rounded),
                  label: 'Templates',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'Activity',
                ),
              ],
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}

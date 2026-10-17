import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/activity/presentation/screens/activity_screen.dart';
import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/templates/presentation/screens/templates_screen.dart';
import '../features/workflows/presentation/screens/workflow_create_edit_screen.dart';
import '../features/workflows/presentation/screens/workflow_details_screen.dart';
import '../features/workflows/presentation/screens/workflows_list_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<bool>(ref.watch(currentUserProvider) != null);

  ref.listen(currentUserProvider, (_, next) {
    authNotifier.value = next != null;
  });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final isAuthRoute = state.matchedLocation == '/auth';

      if (user == null) {
        return isAuthRoute ? null : '/auth';
      }

      if (isAuthRoute) {
        return '/dashboard';
      }

      if (state.matchedLocation == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowsListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const WorkflowCreateEditScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return WorkflowDetailsScreen(workflowId: id);
            },
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return WorkflowCreateEditScreen(workflowId: id);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplatesScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
    ],
  );
});

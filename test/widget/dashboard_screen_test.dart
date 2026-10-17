import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_manager/features/auth/data/in_memory_auth_repository.dart';
import 'package:workflow_manager/features/auth/presentation/controllers/auth_providers.dart';
import 'package:workflow_manager/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:workflow_manager/features/workflows/data/in_memory_workflow_repository.dart';
import 'package:workflow_manager/features/workflows/presentation/controllers/workflow_providers.dart';

void main() {
  testWidgets('DashboardScreen renders summary cards and seed workflows', (tester) async {
    final mockAuthRepo = InMemoryAuthRepository(seedDemoUser: true);
    final mockWorkflowRepo = InMemoryWorkflowRepository(seedDemoData: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          workflowRepositoryProvider.overrideWithValue(mockWorkflowRepo),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify summary metric cards
    expect(find.text('Total Workflows'), findsOneWidget);
    expect(find.text('Active Workflows'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Overdue Workflows'), findsOneWidget);

    // Verify Quick Actions
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Create Custom Workflow'), findsOneWidget);

    // Verify seed workflow item
    expect(find.text('Develop a College Project'), findsOneWidget);
  });
}

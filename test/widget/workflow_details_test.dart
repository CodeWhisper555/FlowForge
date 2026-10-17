import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_manager/features/activity/data/in_memory_activity_repository.dart';
import 'package:workflow_manager/features/activity/presentation/controllers/activity_providers.dart';
import 'package:workflow_manager/features/auth/data/in_memory_auth_repository.dart';
import 'package:workflow_manager/features/auth/presentation/controllers/auth_providers.dart';
import 'package:workflow_manager/features/workflows/data/in_memory_workflow_repository.dart';
import 'package:workflow_manager/features/workflows/presentation/controllers/workflow_providers.dart';
import 'package:workflow_manager/features/workflows/presentation/screens/workflow_details_screen.dart';

void main() {
  testWidgets('WorkflowDetailsScreen displays steps, prerequisites, and unlocks downstream on completion', (tester) async {
    final mockAuthRepo = InMemoryAuthRepository(seedDemoUser: true);
    final mockWorkflowRepo = InMemoryWorkflowRepository(seedDemoData: true);
    final mockActivityRepo = InMemoryActivityRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          workflowRepositoryProvider.overrideWithValue(mockWorkflowRepo),
          activityRepositoryProvider.overrideWithValue(mockActivityRepo),
        ],
        child: const MaterialApp(
          home: WorkflowDetailsScreen(workflowId: 'wf-college-project'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workflow header
    expect(find.text('Develop a College Project'), findsWidgets);

    // Verify steps are displayed
    expect(find.text('Planning'), findsWidgets);
    expect(find.text('Development'), findsWidgets);
    expect(find.text('Documentation'), findsWidgets);
    expect(find.text('Testing'), findsWidgets);
    expect(find.text('Final Submission'), findsOneWidget);

    // Initially: Planning is Ready, Development is Pending
    expect(find.text('Ready'), findsOneWidget); // Planning is Ready
    expect(find.text('Pending'), findsNWidgets(4)); // Dev, Doc, Testing, Submission are Pending

    // Complete Planning step
    final completeFind = find.text('Complete');
    expect(completeFind, findsOneWidget);
    await tester.ensureVisible(completeFind);
    await tester.tap(completeFind);
    await tester.pumpAndSettle();

    // After Planning is completed: Dev and Doc should automatically become Ready!
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Ready'), findsNWidgets(2)); // Dev AND Doc are now Ready!
  });
}

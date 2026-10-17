import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_manager/app/app.dart';
import 'package:workflow_manager/features/activity/data/in_memory_activity_repository.dart';
import 'package:workflow_manager/features/activity/presentation/controllers/activity_providers.dart';
import 'package:workflow_manager/features/auth/data/in_memory_auth_repository.dart';
import 'package:workflow_manager/features/auth/presentation/controllers/auth_providers.dart';
import 'package:workflow_manager/features/templates/data/in_memory_template_repository.dart';
import 'package:workflow_manager/features/templates/presentation/controllers/template_providers.dart';
import 'package:workflow_manager/features/workflows/data/in_memory_workflow_repository.dart';
import 'package:workflow_manager/features/workflows/presentation/controllers/workflow_providers.dart';

void main() {
  testWidgets('End-to-end user journey test', (tester) async {
    final mockAuthRepo = InMemoryAuthRepository(seedDemoUser: true);
    final mockWorkflowRepo = InMemoryWorkflowRepository(seedDemoData: true);
    final mockActivityRepo = InMemoryActivityRepository();
    final mockTemplateRepo = InMemoryTemplateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          workflowRepositoryProvider.overrideWithValue(mockWorkflowRepo),
          activityRepositoryProvider.overrideWithValue(mockActivityRepo),
          templateRepositoryProvider.overrideWithValue(mockTemplateRepo),
        ],
        child: const WorkflowManagerApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Dashboard is displayed with seed workflows
    expect(find.text('Workflow Overview'), findsOneWidget);
    expect(find.text('Develop a College Project'), findsOneWidget);

    // 2. Open the College Project workflow details
    final collegeProjectCard = find.text('Develop a College Project');
    await tester.ensureVisible(collegeProjectCard);
    await tester.tap(collegeProjectCard);
    await tester.pumpAndSettle();

    // 3. Workflow details screen renders
    expect(find.text('Workflow Steps (5)'), findsOneWidget);
    expect(find.text('Planning'), findsWidgets);
    expect(find.text('Development'), findsWidgets);
    expect(find.text('Documentation'), findsWidgets);

    // 4. Complete Planning step
    final completeButton = find.text('Complete');
    expect(completeButton, findsOneWidget);
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    // 5. Verification: Development & Documentation now both unlocked to Ready!
    expect(find.text('Ready'), findsNWidgets(2));

    // 6. Navigate to Activity History tab
    final activityTab = find.text('Activity');
    expect(activityTab, findsWidgets);
    await tester.tap(activityTab.first);
    await tester.pumpAndSettle();

    // Verify activity timeline logged the step completion
    expect(find.text('Activity History'), findsOneWidget);
    expect(find.text('Step Completed'), findsWidgets);
  });
}

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
  testWidgets('App root launch smoke test', (tester) async {
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

    expect(find.text('Workflow Overview'), findsOneWidget);
    expect(find.text('Total Workflows'), findsOneWidget);
  });
}

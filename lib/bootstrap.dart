import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/activity/data/in_memory_activity_repository.dart';
import 'features/activity/presentation/controllers/activity_providers.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/in_memory_auth_repository.dart';
import 'features/auth/presentation/controllers/auth_providers.dart';
import 'features/templates/data/in_memory_template_repository.dart';
import 'features/templates/presentation/controllers/template_providers.dart';
import 'features/workflows/data/firestore_workflow_repository.dart';
import 'features/workflows/data/in_memory_workflow_repository.dart';
import 'features/workflows/presentation/controllers/workflow_providers.dart';
import 'firebase_options.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseConfigured = false;

  try {
    final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(options: firebaseOptions);
    isFirebaseConfigured = true;
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Firebase initialization failed, falling back to in-memory mode: $e\n$stackTrace');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (isFirebaseConfigured) ...[
          authRepositoryProvider.overrideWithValue(FirebaseAuthRepository()),
          workflowRepositoryProvider.overrideWithValue(FirestoreWorkflowRepository()),
        ] else ...[
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
          workflowRepositoryProvider.overrideWithValue(InMemoryWorkflowRepository()),
          activityRepositoryProvider.overrideWithValue(InMemoryActivityRepository()),
          templateRepositoryProvider.overrideWithValue(InMemoryTemplateRepository()),
        ],
      ],
      child: const WorkflowManagerApp(),
    ),
  );
}

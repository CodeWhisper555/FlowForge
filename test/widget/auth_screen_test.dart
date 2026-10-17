import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workflow_manager/features/auth/data/in_memory_auth_repository.dart';
import 'package:workflow_manager/features/auth/presentation/controllers/auth_providers.dart';
import 'package:workflow_manager/features/auth/presentation/screens/auth_screen.dart';

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository(seedDemoUser: false)),
      ],
      child: const MaterialApp(
        home: AuthScreen(),
      ),
    );
  }

  testWidgets('AuthScreen shows initial sign in form and validates empty input', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Workflow Manager'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Clear prefilled text and attempt submit
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('AuthScreen toggles between Sign In and Register', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final toggleButton = find.text("Don't have an account? Register");
    expect(toggleButton, findsOneWidget);

    await tester.ensureVisible(toggleButton);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
  });
}

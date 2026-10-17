import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/in_memory_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return InMemoryAuthRepository();
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.value ?? ref.watch(authRepositoryProvider).currentUser;
});

final isDemoModeProvider = Provider<bool>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.isDemoMode;
});

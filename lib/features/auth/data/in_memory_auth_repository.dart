import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../auth/domain/models/app_user.dart';
import '../../auth/domain/repositories/auth_repository.dart';

class InMemoryAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  final Map<String, String> _userPasswords = {}; // email -> password
  final Map<String, AppUser> _usersByEmail = {}; // email -> AppUser

  InMemoryAuthRepository({bool seedDemoUser = true}) {
    if (seedDemoUser) {
      final demoUser = const AppUser(
        id: 'demo-user-123',
        email: 'demo@workflowmanager.io',
        displayName: 'Demo Engineer',
      );
      _usersByEmail[demoUser.email] = demoUser;
      _userPasswords[demoUser.email] = 'password123';
      _currentUser = demoUser;
    }
  }

  @override
  Stream<AppUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isDemoMode => true;

  @override
  Future<AppUser> signInWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalized = email.trim().toLowerCase();
    final user = _usersByEmail[normalized];
    if (user == null || _userPasswords[normalized] != password) {
      throw Exception('Invalid email or password. For demo, use password123');
    }
    _currentUser = user;
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalized = email.trim().toLowerCase();
    if (_usersByEmail.containsKey(normalized)) {
      throw Exception('An account with this email already exists.');
    }
    final user = AppUser(
      id: const Uuid().v4(),
      email: normalized,
      displayName: displayName ?? normalized.split('@').first,
    );
    _usersByEmail[normalized] = user;
    _userPasswords[normalized] = password;
    _currentUser = user;
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Demo simulator
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

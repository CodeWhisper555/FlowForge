import 'package:firebase_auth/firebase_auth.dart';
import '../domain/models/app_user.dart';
import '../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapFirebaseUser);

  @override
  AppUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  bool get isDemoMode => false;

  @override
  Future<AppUser> signInWithEmailAndPassword(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final appUser = _mapFirebaseUser(credential.user);
    if (appUser == null) {
      throw Exception('Failed to obtain user profile after sign-in.');
    }
    return appUser;
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null && displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
      await user.reload();
    }
    final appUser = _mapFirebaseUser(_firebaseAuth.currentUser ?? user);
    if (appUser == null) {
      throw Exception('Failed to obtain user profile after registration.');
    }
    return appUser;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

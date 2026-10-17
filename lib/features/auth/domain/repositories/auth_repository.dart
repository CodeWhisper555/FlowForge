import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;

  Future<AppUser> signInWithEmailAndPassword(String email, String password);
  Future<AppUser> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  });
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();

  bool get isDemoMode;
}

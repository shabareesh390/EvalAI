import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/auth_service.dart';

enum AuthStatus { initial, loading, success, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  User? _user;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    // 1. INSTANT CACHE CHECK: Grab the saved user synchronously from the phone's
    // local storage before the app even has a chance to draw the first screen.
    _user = FirebaseAuth.instance.currentUser;

    // 2. Listen for any future changes (like when they manually hit sign out)
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  // ── EMAIL SIGN IN ──────────────────────────────────────────────────────
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    }
  }

  // ── EMAIL SIGN UP ──────────────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading();
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    }
  }

  // ── REAL GOOGLE SIGN IN LOGIC (V7+ COMPLIANT) ────────────────────────
  Future<bool> signInWithGoogle() async {
    _setLoading();
    try {
      // V7+ Uses the instance singleton
      final googleSignIn = GoogleSignIn.instance;

      // Ensure it's initialized (Server Client ID is often required for Firebase)
      await googleSignIn.initialize();

      // V7+ uses authenticate() instead of signIn()
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        _status = AuthStatus.initial;
        notifyListeners();
        return false;
      }

      // V7+ authentication is a synchronous property
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // In V7+, Firebase only needs the idToken for authentication.
      // accessToken is only needed for calling other Google APIs (Drive, Calendar, etc.)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError('Google Sign-In Error: $e');
      debugPrint('Google Sign-In Error: $e');
      return false;
    }
  }

  // ── FORGOT PASSWORD ────────────────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    _setLoading();
    try {
      await _authService.resetPassword(email);
      _setSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getErrorMessage(e.code));
      return false;
    }
  }

  // ── SIGN OUT ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    // It's good practice to also sign out of the Google SDK so they can choose a different account next time
    await GoogleSignIn.instance.signOut();
  }

  // ── STATE HELPERS ──────────────────────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = AuthStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  // ── ERROR HANDLING ─────────────────────────────────────────────────────
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Something went wrong. Please try again';
    }
  }
}

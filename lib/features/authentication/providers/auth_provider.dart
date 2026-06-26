import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';

enum AuthStatus { initial, loading, success, error }

/// Manages authentication state and provides methods for sign-in and sign-up.
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
    _user = FirebaseAuth.instance.currentUser;

    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

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

  Future<bool> signInWithGoogle() async {
    _setLoading();
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
        _setSuccess();
        return true;
      }

      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        _status = AuthStatus.initial;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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

  Future<void> signOut() async {
    await _authService.signOut();
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

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

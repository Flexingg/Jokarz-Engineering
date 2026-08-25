import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

class AuthService {
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges();
  }

  User? get currentUser => _auth?.currentUser;

  bool get isSignedIn => currentUser != null;

  String? get userDisplayName => currentUser?.displayName;
  String? get userEmail => currentUser?.email;
  String? get userPhotoUrl => currentUser?.photoURL;
  String? get userId => currentUser?.uid;

  /// Sign in with Google (Supports Android and Windows/Web)
  Future<UserCredential?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }

    try {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        // Windows and Web Google Sign-In flow
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        return await auth.signInWithProvider(googleProvider);
      } else {
        // Android / iOS native Google Sign-In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User aborted Google sign-in
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('AuthService Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Switch / Change Google Account (forces account selector prompt)
  Future<UserCredential?> switchGoogleAccount() async {
    await signOut();
    return await signInWithGoogle();
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        await _googleSignIn.disconnect().catchError((_) => null);
        await _googleSignIn.signOut();
      }
      await _auth?.signOut();
    } catch (e) {
      debugPrint('AuthService Sign-Out Error: $e');
    }
  }
}

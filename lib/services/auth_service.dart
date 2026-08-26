import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

class AuthService {
  static final String _webClientId = String.fromCharCodes([
    54, 57, 51, 54, 52, 52, 51, 48, 56, 57, 52, 49, 45, 49, 97, 99, 104, 50,
    52, 117, 102, 110, 102, 51, 117, 118, 56, 48, 112, 98, 113, 104, 109, 116,
    101, 99, 97, 99, 104, 106, 110, 102, 49, 97, 107, 46, 97, 112, 112, 115,
    46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116,
    101, 110, 116, 46, 99, 111, 109
  ]);
  static final String _desktopClientId = String.fromCharCodes([
    54, 57, 51, 54, 52, 52, 51, 48, 56, 57, 52, 49, 45, 98, 105, 57, 57, 111,
    110, 107, 102, 115, 98, 117, 98, 110, 106, 111, 113, 57, 57, 109, 48, 51,
    103, 98, 48, 55, 49, 112, 97, 103, 54, 102, 103, 46, 97, 112, 112, 115,
    46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116,
    101, 110, 116, 46, 99, 111, 109
  ]);
  static final String _desktopClientSecret = String.fromCharCodes([
    71, 79, 67, 83, 80, 88, 45, 115, 68, 84, 107, 108, 68, 95, 82, 53, 76,
    101, 76, 84, 57, 100, 119, 86, 111, 49, 110, 81, 76, 45, 87, 117, 108,
    110, 100
  ]);

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
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

  /// Sign in with Google (Supports Android, iOS, Windows, and Web)
  Future<UserCredential?> signInWithGoogle({
    Function(Uri authUri)? onAuthUrl,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized');
    }

    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || Platform.isWindows)) {
        // Windows Desktop OAuth 2.0 PKCE loopback flow
        return await _signInWithGoogleWindows(auth, onAuthUrl: onAuthUrl);
      } else if (kIsWeb) {
        // Web Google Sign-In flow
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
  Future<UserCredential?> switchGoogleAccount({
    Function(Uri authUri)? onAuthUrl,
  }) async {
    await signOut();
    return await signInWithGoogle(onAuthUrl: onAuthUrl);
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows && !Platform.isWindows) {
        await _googleSignIn.disconnect().catchError((_) => null);
        await _googleSignIn.signOut();
      }
      await _auth?.signOut();
    } catch (e) {
      debugPrint('AuthService Sign-Out Error: $e');
    }
  }

  String _randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _deriveCodeChallenge(String verifier) {
    final bytes = ascii.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Launch URL in system browser on Windows with robust fallbacks
  Future<void> openBrowser(Uri url) async {
    final urlStr = url.toString();
    debugPrint('AuthService: Launching browser for: $urlStr');

    // Method 1: cmd /c start "" "url"
    try {
      final res = await Process.run('cmd', ['/c', 'start', '', urlStr]);
      debugPrint('AuthService: cmd /c start exitCode=${res.exitCode}');
      if (res.exitCode == 0) return;
    } catch (e) {
      debugPrint('AuthService: cmd error: $e');
    }

    // Method 2: Flutter launchUrl
    try {
      if (await canLaunchUrl(url)) {
        final launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        if (launched) {
          debugPrint('AuthService: launchUrl succeeded');
          return;
        }
      }
    } catch (e) {
      debugPrint('AuthService: launchUrl failed: $e');
    }

    // Method 3: PowerShell Start-Process
    try {
      await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Process',
        '"$urlStr"',
      ]);
      debugPrint('AuthService: powershell Start-Process triggered');
    } catch (e) {
      debugPrint('AuthService: powershell error: $e');
    }
  }

  /// Windows Desktop Google OAuth 2.0 Loopback Auth with PKCE
  Future<UserCredential?> _signInWithGoogleWindows(
    FirebaseAuth auth, {
    Function(Uri authUri)? onAuthUrl,
  }) async {
    debugPrint('AuthService: Starting Windows Google Sign-In loopback flow...');
    final codeVerifier = _randomString(64);
    final codeChallenge = _deriveCodeChallenge(codeVerifier);

    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    final completer = Completer<String>();

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';
      debugPrint('AuthService: Listening for OAuth callback on $redirectUri');

      final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _desktopClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      // Notify caller of generated URL
      onAuthUrl?.call(authUri);

      sub = server.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/favicon.ico') {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        }

        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;
        if (code != null) {
          request.response.write('''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>Jokarz Engineering Sign-In</title>
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                  background-color: #0b151e;
                  color: #e2e8f0;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  height: 100vh;
                  margin: 0;
                }
                .card {
                  background: #122130;
                  border: 1px solid #1f364d;
                  border-radius: 16px;
                  padding: 40px;
                  text-align: center;
                  box-shadow: 0 10px 25px rgba(0,0,0,0.5);
                  max-width: 380px;
                }
                h1 { color: #00e5ff; margin-top: 0; font-size: 22px; }
                p { color: #94a3b8; font-size: 14px; line-height: 1.5; }
                .icon { font-size: 48px; margin-bottom: 16px; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="icon">⚙️</div>
                <h1>Sign-In Successful!</h1>
                <p>You have signed in to <strong>Jokarz Engineering</strong>.<br>You can close this tab and return to the desktop application.</p>
              </div>
            </body>
            </html>
          ''');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(code);
        } else if (error != null) {
          request.response.write(
              '<html><body style="background:#0b151e;color:#ff5252;padding:40px;font-family:sans-serif;"><h3>Sign-in cancelled or failed: $error</h3></body></html>');
          await request.response.close();
          if (!completer.isCompleted) completer.completeError(Exception('Google Sign-In error: $error'));
        } else {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
        }
      });

      // Launch system browser
      await openBrowser(authUri);

      // Await incoming redirect authorization code (timeout after 2 minutes)
      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () =>
            throw TimeoutException('Sign in timed out waiting for browser response.'),
      );

      debugPrint('AuthService: Received auth code, exchanging for tokens...');

      // Exchange authorization code for OAuth ID & Access tokens (RFC 7636 PKCE)
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _desktopClientId,
          'client_secret': _desktopClientSecret,
          'code': code,
          'code_verifier': codeVerifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      debugPrint('AuthService: Token response status ${tokenResponse.statusCode}');
      if (tokenResponse.statusCode != 200) {
        throw Exception('Failed to exchange auth code: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;

      if (idToken == null) {
        throw Exception('Google OAuth did not return an ID token');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('AuthService: Signing into Firebase Auth with credential...');
      return await auth.signInWithCredential(credential);
    } finally {
      await sub?.cancel();
      await server?.close(force: true);
    }
  }
}

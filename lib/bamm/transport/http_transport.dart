/// Authenticated HTTP transport for the BAMM (Cogep GuideTi) JSON API.
///
/// See `~/repos/BAMM/docs/01-authentication.md`. The two rules that bite everyone:
///
/// * two tokens are required on every call - `Access-Token` (Bearer) and `Session-Token`;
/// * a dead session shows up as HTTP 401/403/598, so re-login once and retry.
///
/// Modelled closely on `~/repos/BAMM/app/bamm/client.py::BammClient`. No caching
/// happens here - that is a decorator added in a later phase.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../bamm_config.dart';

const String kBammAcceptHeader = 'application/json, text/plain, */*';
const String kBammContentTypeJson = 'application/json';
const String kBammContentTypeDto = 'application/cogep.dynamicdtoV1+json';

/// HTTP status codes that mean "your token pair is dead" - discard both
/// tokens, log in again, and retry the request once.
const List<int> kBammAuthRetryStatus = [401, 403, 598];

/// Base of the typed BAMM transport exception tree. Every fetch in this layer
/// throws one of the four concrete subtypes below - never a bare Exception,
/// and never a swallowed failure that falls back to a guessed default.
sealed class BammException implements Exception {
  final String message;
  const BammException(this.message);

  @override
  String toString() => message;
}

/// A non-2xx, non-599 HTTP response, or a network/timeout failure reaching
/// BAMM at all (the Python reference folds both into one error type; see the
/// module doc comment on why this port keeps that choice).
class BammHttpException extends BammException {
  final int? statusCode;
  final String? body;
  const BammHttpException(super.message, {this.statusCode, this.body});
}

/// BAMM's HTTP 599 - an application-level error with a message in the body
/// (typically `exceptionMessage`). Never swallow this message; it is usually
/// the only clue about what the payload got wrong (see docs/02, the
/// `originProperty` lesson).
class BammApplicationException extends BammException {
  final int statusCode;
  final String? body;
  const BammApplicationException(super.message, {required this.statusCode, this.body});
}

/// A 2xx response whose body was not the JSON the caller expected.
class BammDecodeException extends BammException {
  final int? statusCode;
  final String body;
  const BammDecodeException(super.message, {this.statusCode, required this.body});
}

/// Login itself failed, or a call was attempted with no valid token pair.
class BammAuthException extends BammException {
  final int? statusCode;
  const BammAuthException(super.message, {this.statusCode});
}

/// Owns one HTTP client and one token pair for the BAMM API.
class BammHttpTransport {
  final BammConfig config;
  final http.Client _client;

  String? _accessToken;
  String? _sessionToken;
  DateTime? _expiresAt;

  /// How many times [login] has succeeded - useful in tests/diagnostics to
  /// confirm a re-login actually happened after [reset].
  int loginCount = 0;

  BammHttpTransport(this.config, {http.Client? client}) : _client = client ?? http.Client();

  bool get isAuthenticated =>
      _accessToken != null &&
      _sessionToken != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  /// Drops both tokens so the next call forces a fresh login.
  void reset() {
    _accessToken = null;
    _sessionToken = null;
    _expiresAt = null;
  }

  static String _bearer(String token) {
    final trimmed = token.trim();
    return trimmed.toLowerCase().startsWith('bearer ') ? trimmed : 'Bearer $trimmed';
  }

  /// `PUT /api/login/FinalizeLogInWeb` - caches both tokens on success.
  Future<void> login() async {
    if (config.usercode.isEmpty) {
      throw const BammAuthException('BAMM usercode is not configured');
    }

    final origin = config.normalizedOrigin;
    final url = Uri.parse('$origin/api/login/FinalizeLogInWeb');
    final headers = {
      'Accept': kBammAcceptHeader,
      'Content-Type': kBammContentTypeJson,
      'Origin': origin,
      'Referer': '$origin/',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
    final payload = {
      'usercode': config.usercode,
      'password': config.password,
      'companyID': config.companyId,
    };

    http.Response response;
    try {
      response = await _client
          .put(url, headers: headers, body: jsonEncode(payload))
          .timeout(config.loginTimeout);
    } on TimeoutException {
      throw BammAuthException('BAMM login timed out after ${config.loginTimeout.inSeconds}s');
    } catch (e) {
      throw BammAuthException('BAMM login network error: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BammAuthException(
        'BAMM login failed with HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('root is not an object');
      }
      decoded = parsed;
    } on FormatException {
      throw BammAuthException(
        'BAMM login returned invalid JSON',
        statusCode: response.statusCode,
      );
    }

    final value = decoded['value'];
    if (value is! Map<String, dynamic>) {
      throw BammAuthException(
        'BAMM login response has no value object',
        statusCode: response.statusCode,
      );
    }

    final accessToken = value['token']?.toString();
    final sessionToken = value['sessionToken']?.toString();
    if (accessToken == null || accessToken.isEmpty || sessionToken == null || sessionToken.isEmpty) {
      throw BammAuthException(
        'BAMM login succeeded but a token was missing',
        statusCode: response.statusCode,
      );
    }

    _accessToken = accessToken;
    _sessionToken = sessionToken;
    _expiresAt = DateTime.now().add(config.tokenLifetime);
    loginCount++;
  }

  Future<void> ensureTokens({bool force = false}) async {
    if (force || !isAuthenticated) {
      await login();
    }
  }

  Map<String, String> _headers({required String referer, String? contentType}) {
    if (_accessToken == null || _sessionToken == null) {
      throw const BammAuthException('No BAMM tokens available - call login() first');
    }
    final origin = config.normalizedOrigin;
    final refererUrl = referer.startsWith('http') ? referer : '$origin$referer';
    return {
      'Accept': kBammAcceptHeader,
      'Content-Type': contentType ?? kBammContentTypeJson,
      'Access-Token': _bearer(_accessToken!),
      'Session-Token': _sessionToken!,
      'Origin': origin,
      'Referer': refererUrl,
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    };
  }

  /// Sends an authenticated request, re-logging in once on 401/403/598.
  ///
  /// [jsonBody] is only attached when non-null: BAMM answers some no-body
  /// endpoints with a 5xx if a literal `null` JSON body is sent (the browser
  /// sends none at all).
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? params,
    String referer = '/',
    String? contentType,
    String operation = 'BAMM request',
    bool allowNonJson = false,
    int maxAttempts = 2,
  }) async {
    var uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('${config.normalizedOrigin}$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }
    final body = jsonBody != null ? jsonEncode(jsonBody) : null;

    BammHttpException? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await ensureTokens(force: attempt > 1);
      final headers = _headers(referer: referer, contentType: contentType);

      http.Response response;
      try {
        if (method == 'GET') {
          response = await _client.get(uri, headers: headers).timeout(config.apiTimeout);
        } else if (method == 'POST') {
          response = await _client.post(uri, headers: headers, body: body).timeout(config.apiTimeout);
        } else if (method == 'PUT') {
          response = await _client.put(uri, headers: headers, body: body).timeout(config.apiTimeout);
        } else {
          throw ArgumentError('Unsupported HTTP method: $method');
        }
      } on TimeoutException {
        throw BammHttpException('$operation timed out after ${config.apiTimeout.inSeconds}s');
      } on ArgumentError {
        rethrow;
      } catch (e) {
        throw BammHttpException('$operation network error: $e');
      }

      if (response.statusCode == 599) {
        throw BammApplicationException(
          _extractApplicationMessage(response.body),
          statusCode: 599,
          body: response.body,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.trim().isEmpty) {
          return {'status': response.statusCode, 'value': null};
        }
        try {
          return jsonDecode(response.body);
        } on FormatException {
          if (allowNonJson) {
            return {'status': response.statusCode, 'raw': response.body};
          }
          throw BammDecodeException(
            '$operation returned invalid JSON',
            statusCode: response.statusCode,
            body: response.body,
          );
        }
      }

      lastError = BammHttpException(
        '$operation failed with HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
      if (kBammAuthRetryStatus.contains(response.statusCode) && attempt < maxAttempts) {
        reset();
        continue;
      }
      throw lastError;
    }
    throw lastError ?? BammHttpException('$operation failed');
  }

  /// Pulls a human-readable message out of a 599 body. BAMM's own .NET
  /// exception messages are rarely helpful (`Value cannot be null. Parameter
  /// name: name`) but they are the only signal available, so surface them
  /// rather than a generic "something went wrong".
  String _extractApplicationMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['exceptionMessage'] != null) {
        return decoded['exceptionMessage'].toString();
      }
    } catch (_) {
      // Body wasn't JSON - fall through and surface it verbatim below.
    }
    return body.trim().isEmpty ? 'BAMM application error (HTTP 599)' : body;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? params,
    String referer = '/',
    String operation = 'BAMM request',
    bool allowNonJson = false,
  }) =>
      request('GET', path, params: params, referer: referer, operation: operation, allowNonJson: allowNonJson);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? params,
    String referer = '/',
    String? contentType,
    String operation = 'BAMM request',
    bool allowNonJson = false,
  }) =>
      request(
        'POST',
        path,
        jsonBody: jsonBody,
        params: params,
        referer: referer,
        contentType: contentType,
        operation: operation,
        allowNonJson: allowNonJson,
      );

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? params,
    String referer = '/',
    String? contentType,
    String operation = 'BAMM request',
  }) =>
      request(
        'PUT',
        path,
        jsonBody: jsonBody,
        params: params,
        referer: referer,
        contentType: contentType,
        operation: operation,
      );

  void close() => _client.close();
}

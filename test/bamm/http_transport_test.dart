import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jokarz_engineering/bamm/bamm_config.dart';
import 'package:jokarz_engineering/bamm/transport/http_transport.dart';

BammConfig _config({String usercode = 'mock'}) => BammConfig(
      origin: 'http://mock.local',
      usercode: usercode,
      password: '',
      companyId: 3,
      spwId: 700000027,
    );

void main() {
  group('login', () {
    test('stores both tokens on success', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/login/FinalizeLogInWeb');
        return http.Response(
          jsonEncode({
            'value': {'token': 'abc123', 'sessionToken': 'sess456'}
          }),
          200,
        );
      });
      final transport = BammHttpTransport(_config(), client: client);

      await transport.login();

      expect(transport.isAuthenticated, isTrue);
      expect(transport.loginCount, 1);
    });

    test('missing usercode is a typed auth error, no request sent', () async {
      final client = MockClient((request) async {
        fail('should not send a request when usercode is empty');
      });
      final transport = BammHttpTransport(_config(usercode: ''), client: client);

      expect(transport.login(), throwsA(isA<BammAuthException>()));
    });

    test('a non-2xx login response is a typed auth error', () async {
      final client = MockClient((request) async => http.Response('nope', 500));
      final transport = BammHttpTransport(_config(), client: client);

      await expectLater(transport.login(), throwsA(isA<BammAuthException>()));
    });

    test('a response missing a token is a typed auth error', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'value': {'token': 'abc123'}
            }),
            200,
          ));
      final transport = BammHttpTransport(_config(), client: client);

      await expectLater(transport.login(), throwsA(isA<BammAuthException>()));
    });
  });

  group('request', () {
    Future<BammHttpTransport> loggedIn(http.Client client) async {
      final transport = BammHttpTransport(_config(), client: client);
      await transport.login();
      return transport;
    }

    test('decodes a normal 2xx JSON response', () async {
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'value': {'token': 't', 'sessionToken': 's'}
            }),
            200,
          );
        }
        expect(request.headers['Access-Token'], 'Bearer t');
        expect(request.headers['Session-Token'], 's');
        return http.Response(jsonEncode({'value': 42}), 200);
      });
      final transport = await loggedIn(client);

      final result = await transport.get('/api/whatever', operation: 'test');

      expect(result, {'value': 42});
    });

    test('HTTP 599 surfaces the exceptionMessage from the body, not swallowed', () async {
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'value': {'token': 't', 'sessionToken': 's'}
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'exceptionMessage': 'Value cannot be null. Parameter name: name'}),
          599,
        );
      });
      final transport = await loggedIn(client);

      try {
        await transport.post('/api/WorkOrder/Save', jsonBody: const {}, operation: 'save');
        fail('expected a BammApplicationException');
      } on BammApplicationException catch (e) {
        expect(e.statusCode, 599);
        expect(e.message, 'Value cannot be null. Parameter name: name');
      }
    });

    test('a non-599 HTTP error is a typed HTTP exception carrying the status code', () async {
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'value': {'token': 't', 'sessionToken': 's'}
            }),
            200,
          );
        }
        return http.Response('server error', 500);
      });
      final transport = await loggedIn(client);

      try {
        await transport.get('/api/whatever', operation: 'test');
        fail('expected a BammHttpException');
      } on BammHttpException catch (e) {
        expect(e.statusCode, 500);
      }
    });

    test('a 2xx response with invalid JSON is a typed decode error', () async {
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'value': {'token': 't', 'sessionToken': 's'}
            }),
            200,
          );
        }
        return http.Response('<not json>', 200);
      });
      final transport = await loggedIn(client);

      expect(
        transport.get('/api/whatever', operation: 'test'),
        throwsA(isA<BammDecodeException>()),
      );
    });

    test('401 triggers exactly one re-login and retry, then succeeds', () async {
      var loginCalls = 0;
      var apiCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          loginCalls++;
          return http.Response(
            jsonEncode({
              'value': {'token': 'token$loginCalls', 'sessionToken': 'sess$loginCalls'}
            }),
            200,
          );
        }
        apiCalls++;
        if (apiCalls == 1) {
          return http.Response('unauthorized', 401);
        }
        expect(request.headers['Access-Token'], 'Bearer token2');
        return http.Response(jsonEncode({'value': 'ok'}), 200);
      });
      final transport = await loggedIn(client);
      expect(loginCalls, 1);

      final result = await transport.get('/api/whatever', operation: 'test');

      expect(result, {'value': 'ok'});
      expect(apiCalls, 2);
      expect(loginCalls, 2);
    });

    test('a request with no tokens at all is a typed auth error', () async {
      final client = MockClient((request) async {
        fail('should not reach the network without tokens');
      });
      final transport = BammHttpTransport(_config(usercode: ''), client: client);

      expect(
        transport.get('/api/whatever', operation: 'test'),
        throwsA(isA<BammAuthException>()),
      );
    });
  });
}

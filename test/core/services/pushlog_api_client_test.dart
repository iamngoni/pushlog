import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _RecordingTransport {
  _RecordingTransport({
    this.status = HttpStatus.ok,
    this.responseBody = '{}',
  });

  final int status;
  final String responseBody;
  String? method;
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  Future<PushlogApiResponse> call({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    this.method = method;
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    return PushlogApiResponse(statusCode: status, body: responseBody);
  }
}

void main() {
  group(PushlogApiClient, () {
    late _MockFirebaseAuth auth;
    late _MockUser user;

    setUp(() {
      auth = _MockFirebaseAuth();
      user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(user.getIdToken).thenAnswer((_) async => 'firebase-token');
    });

    test(
      'uses the Worker by default with the Firebase identity token',
      () async {
        final transport = _RecordingTransport(
          responseBody: '{"status":"stored"}',
        );
        final client = PushlogApiClient(auth: auth, transport: transport.call);

        final result = await client.put(
          '/v1/workout-snapshot',
          body: const {'snapshot': <String, dynamic>{}},
        );

        expect(result, {'status': 'stored'});
        expect(transport.method, 'PUT');
        expect(
          transport.uri,
          Uri.parse(
            'https://pushlog-api-staging.imngonii.workers.dev/'
            'v1/workout-snapshot',
          ),
        );
        expect(
          transport.headers?[HttpHeaders.authorizationHeader],
          'Bearer firebase-token',
        );
        expect(jsonDecode(transport.body!), {
          'snapshot': <String, dynamic>{},
        });
      },
    );

    test('surfaces Worker error codes and messages', () async {
      final client = PushlogApiClient(
        auth: auth,
        transport: _RecordingTransport(
          status: HttpStatus.conflict,
          responseBody:
              '{"error":{"code":"username_taken",'
              '"message":"That username is already taken."}}',
        ).call,
      );

      await expectLater(
        client.put('/v1/profile/username', body: const {'username': 'taken'}),
        throwsA(
          isA<PushlogApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.code, 'code', 'username_taken'),
        ),
      );
    });

    test('does not accept a body uid as authentication', () async {
      when(() => auth.currentUser).thenReturn(null);
      final transport = _RecordingTransport();
      final client = PushlogApiClient(auth: auth, transport: transport.call);

      await expectLater(
        client.put('/v1/profile', body: const {'uid': 'someone-else'}),
        throwsA(
          isA<PushlogApiException>().having(
            (error) => error.code,
            'code',
            'authentication_required',
          ),
        ),
      );
      expect(transport.uri, isNull);
    });
  });
}

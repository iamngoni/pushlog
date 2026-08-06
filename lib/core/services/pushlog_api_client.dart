import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

class PushlogApiResponse {
  const PushlogApiResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

typedef PushlogApiTransport =
    Future<PushlogApiResponse> Function({
      required String method,
      required Uri uri,
      required Map<String, String> headers,
      String? body,
    });

class PushlogApiException implements Exception {
  const PushlogApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

Future<PushlogApiResponse> ioPushlogApiTransport({
  required String method,
  required Uri uri,
  required Map<String, String> headers,
  String? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) request.write(body);
    final response = await request.close();
    return PushlogApiResponse(
      statusCode: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  } finally {
    client.close();
  }
}

class PushlogApiClient {
  PushlogApiClient({
    required this.auth,
    this.baseUrl = const String.fromEnvironment(
      'PUSHLOG_API_URL',
      defaultValue: 'https://pushlog-api-staging.imngonii.workers.dev',
    ),
    PushlogApiTransport? transport,
  }) : transport = transport ?? ioPushlogApiTransport;

  final FirebaseAuth auth;
  final String baseUrl;
  final PushlogApiTransport transport;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    return _request('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _request('PUT', path, body: body);
  }

  Future<void> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _request('DELETE', path, body: body);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw const PushlogApiException(
        statusCode: 401,
        code: 'authentication_required',
        message: 'Sign in to continue.',
      );
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const PushlogApiException(
        statusCode: 401,
        code: 'authentication_required',
        message: 'Your session expired. Sign in again.',
      );
    }

    final base = Uri.parse(baseUrl);
    final resolved = base.resolve(path).replace(queryParameters: query);
    final response = await transport(
      method: method,
      uri: resolved,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 12));

    var payload = <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) payload = decoded;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    final error = payload['error'];
    final errorMap = error is Map<String, dynamic>
        ? error
        : <String, dynamic>{};
    throw PushlogApiException(
      statusCode: response.statusCode,
      code: errorMap['code'] as String? ?? 'request_failed',
      message:
          errorMap['message'] as String? ??
          'Pushlog could not reach its service. Try again.',
    );
  }
}

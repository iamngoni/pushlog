import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

typedef WorkoutShadowSync = Future<void> Function(WorkoutSnapshot snapshot);

typedef ShadowSyncTransport =
    Future<int> Function({
      required Uri uri,
      required Map<String, String> headers,
      required String body,
    });

Future<void> noopWorkoutShadowSync(WorkoutSnapshot snapshot) async {}

Future<int> ioShadowSyncTransport({
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.putUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close();
  }
}

class CloudflareWorkoutShadowSyncService {
  CloudflareWorkoutShadowSyncService({
    required this.auth,
    this.baseUrl = const String.fromEnvironment(
      'PUSHLOG_SHADOW_API_URL',
    ),
    ShadowSyncTransport? transport,
  }) : transport = transport ?? ioShadowSyncTransport;

  final FirebaseAuth auth;
  final String baseUrl;
  final ShadowSyncTransport transport;

  bool get isEnabled => _endpoint != null;

  Uri? get _endpoint {
    if (baseUrl.trim().isEmpty) return null;
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null || !base.hasScheme || !base.hasAuthority) return null;
    if (base.scheme != 'https' && base.host != 'localhost') return null;
    return base.resolve('/v1/workout-snapshot');
  }

  Future<void> syncWorkoutSnapshot(WorkoutSnapshot snapshot) async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final user = auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) return;

    final status = await transport(
      uri: endpoint,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({'snapshot': snapshot.toJson()}),
    ).timeout(const Duration(seconds: 8));
    if (status != HttpStatus.ok && status != HttpStatus.accepted) {
      throw HttpException(
        'Workout shadow sync failed with status $status.',
        uri: endpoint,
      );
    }
  }
}

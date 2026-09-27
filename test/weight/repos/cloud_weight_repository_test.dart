import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/core/services/storage_service.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/repos/impl/cloud_weight_repository.dart';
import 'package:pushlog/weight/models/repos/impl/local_weight_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPushlogApiClient extends Mock implements PushlogApiClient {}

const _notDeployed = PushlogApiException(
  statusCode: 404,
  code: 'not_found',
  message: 'Route not found.',
);

WeightEntry _entry(String day, int grams, {bool dirty = false}) {
  return WeightEntry(
    recordedOn: day,
    weightGrams: grams,
    updatedAt: '${day}T08:00:00Z',
    dirty: dirty,
  );
}

Map<String, dynamic> _remote(List<WeightEntry> entries) => {
  'entries': [
    for (final entry in entries) entry.toJson()..remove('dirty'),
  ],
};

void main() {
  late StorageService storage;
  late LocalWeightRepository local;
  late _MockPushlogApiClient api;
  late CloudWeightRepository repository;
  var scope = 'uid-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    scope = 'uid-1';
    local = LocalWeightRepository(
      storage: storage,
      scopeResolver: () => scope,
    );
    api = _MockPushlogApiClient();
    repository = CloudWeightRepository(local: local, api: api);
  });

  test('a save the Worker rejects stays on the device, marked dirty', () async {
    when(
      () => api.put('/v1/weight/entries', body: any(named: 'body')),
    ).thenThrow(_notDeployed);

    await repository.saveEntry(_entry('2026-09-27', 70000));

    expect(local.loadEntries(), [_entry('2026-09-27', 70000, dirty: true)]);
  });

  test('a timed-out load keeps the local copy', () async {
    await local.saveEntries([_entry('2026-09-26', 70000)]);
    when(
      () => api.get('/v1/weight/entries'),
    ).thenThrow(TimeoutException('slow'));

    final result = await repository.loadEntries();

    expect(result.getOrElse(() => []), [_entry('2026-09-26', 70000)]);
  });

  test('a dirty day is pushed, then clean remote days are adopted', () async {
    await local.saveEntries([
      _entry('2026-09-26', 70000),
      _entry('2026-09-27', 71000, dirty: true),
    ]);
    when(
      () => api.put('/v1/weight/entries', body: any(named: 'body')),
    ).thenAnswer((_) async => {'updatedAt': '2026-09-27T09:00:00Z'});
    when(() => api.get('/v1/weight/entries')).thenAnswer(
      (_) async => _remote([
        _entry('2026-09-25', 69000),
        _entry('2026-09-26', 70500),
        _entry('2026-09-27', 71000),
      ]),
    );

    await repository.loadEntries();

    verify(
      () => api.put(
        '/v1/weight/entries',
        body: {'recordedOn': '2026-09-27', 'weightGrams': 71000},
      ),
    ).called(1);
    final stored = local.loadEntries();
    expect(stored.map((entry) => entry.weightGrams), [69000, 70500, 71000]);
    expect(stored.any((entry) => entry.dirty), isFalse);
  });

  test('a day that stays dirty is not overwritten by the pull', () async {
    await local.saveEntries([_entry('2026-09-27', 71000, dirty: true)]);
    when(
      () => api.put('/v1/weight/entries', body: any(named: 'body')),
    ).thenThrow(_notDeployed);
    when(
      () => api.get('/v1/weight/entries'),
    ).thenAnswer((_) async => _remote([_entry('2026-09-27', 65000)]));

    await repository.loadEntries();

    expect(local.loadEntries().single.weightGrams, 71000);
  });

  test('a day logged while the pull is in flight survives the merge', () async {
    final fetch = Completer<Map<String, dynamic>>();
    when(() => api.get('/v1/weight/entries')).thenAnswer((_) => fetch.future);
    when(
      () => api.put('/v1/weight/entries', body: any(named: 'body')),
    ).thenAnswer((_) async => {'updatedAt': '2026-09-27T09:00:00Z'});

    final loading = repository.loadEntries();
    await repository.saveEntry(_entry('2026-09-27', 72000));
    fetch.complete(_remote([_entry('2026-09-20', 71000)]));
    final result = await loading;

    final days = result.getOrElse(() => []).map((entry) => entry.recordedOn);
    expect(days, ['2026-09-20', '2026-09-27']);
    expect(
      local.loadEntries().map((entry) => entry.recordedOn),
      ['2026-09-20', '2026-09-27'],
    );
  });

  test('reset clears the device and the cloud', () async {
    await local.saveEntries([_entry('2026-09-27', 70000)]);
    await local.saveSettings(local.loadSettings());
    when(() => api.delete('/v1/weight')).thenAnswer((_) async {});

    await repository.reset();

    expect(storage.getString('pushlog.weight.entries.uid-1'), isNull);
    expect(storage.getString('pushlog.weight.settings.uid-1'), isNull);
    expect(local.resetPending, isFalse);
    verify(() => api.delete('/v1/weight')).called(1);
  });

  test('an offline reset is retried before the next pull', () async {
    await local.saveEntries([_entry('2026-09-27', 70000)]);
    when(() => api.delete('/v1/weight')).thenThrow(_notDeployed);

    await repository.reset();
    expect(local.resetPending, isTrue);

    // Still failing: the pull must not bring the cleared days back.
    when(
      () => api.get('/v1/weight/entries'),
    ).thenAnswer((_) async => _remote([_entry('2026-09-27', 70000)]));
    final stillPending = await repository.loadEntries();
    expect(stillPending.getOrElse(() => [_entry('x', 1)]), isEmpty);
    verifyNever(() => api.get('/v1/weight/entries'));

    // Once the delete lands, sync resumes.
    when(() => api.delete('/v1/weight')).thenAnswer((_) async {});
    when(
      () => api.get('/v1/weight/entries'),
    ).thenAnswer((_) async => _remote([]));
    await repository.loadEntries();
    expect(local.resetPending, isFalse);
    verify(() => api.get('/v1/weight/entries')).called(1);
  });

  test('clearLocal removes the named account after sign-out', () async {
    await local.saveEntries([_entry('2026-09-27', 70000)]);
    await local.saveSettings(local.loadSettings());
    scope = 'guest';

    await repository.clearLocal(uid: 'uid-1');

    expect(storage.getString('pushlog.weight.entries.uid-1'), isNull);
    expect(storage.getString('pushlog.weight.settings.uid-1'), isNull);
  });

  test('export leaves out sync bookkeeping', () async {
    await local.saveEntries([_entry('2026-09-27', 70000, dirty: true)]);

    expect(repository.exportEntries(), [
      {
        'recordedOn': '2026-09-27',
        'weightGrams': 70000,
        'updatedAt': '2026-09-27T08:00:00Z',
      },
    ]);
  });
}

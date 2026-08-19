import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/services/storage_service.dart';
import 'package:pushlog/core/state/theme_mode_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> storageWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return StorageService(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts on system so the phone setting is honoured', () async {
    final cubit = ThemeModeCubit(await storageWith({}));
    expect(cubit.state, ThemeMode.system);
  });

  test('restores a stored choice', () async {
    final dark = ThemeModeCubit(
      await storageWith({ThemeModeCubit.storageKey: 'dark'}),
    );
    expect(dark.state, ThemeMode.dark);

    final light = ThemeModeCubit(
      await storageWith({ThemeModeCubit.storageKey: 'light'}),
    );
    expect(light.state, ThemeMode.light);
  });

  test('falls back to system on an unreadable value', () async {
    final cubit = ThemeModeCubit(
      await storageWith({ThemeModeCubit.storageKey: 'chartreuse'}),
    );
    expect(cubit.state, ThemeMode.system);
  });

  test('toggle flips away from what is on screen', () async {
    final storage = await storageWith({});
    final cubit = ThemeModeCubit(storage);

    // Still on system: the rendered brightness is what decides, since
    // there is no stored side to flip.
    await cubit.toggle(isDarkNow: false);
    expect(cubit.state, ThemeMode.dark);

    await cubit.toggle(isDarkNow: true);
    expect(cubit.state, ThemeMode.light);
  });

  test('persists the choice so it survives a restart', () async {
    final storage = await storageWith({});
    await ThemeModeCubit(storage).toggle(isDarkNow: false);

    expect(storage.getString(ThemeModeCubit.storageKey), 'dark');
    // A fresh cubit over the same store comes back on dark.
    expect(ThemeModeCubit(storage).state, ThemeMode.dark);
  });
}

//
//  pushlog
//  theme_mode_cubit.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:pushlog/core/services/storage_service.dart';

/// The app's light/dark preference.
///
/// Starts on [ThemeMode.system] and stays there until the user actually
/// picks a side — following the phone is the right default, and writing an
/// explicit choice before they have made one would silently opt them out of
/// their own device setting.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._storage) : super(_read(_storage));

  static const String storageKey = 'pushlog.themeMode';

  final StorageService _storage;

  static ThemeMode _read(StorageService storage) {
    return switch (storage.getString(storageKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Flips to the opposite of what is on screen right now.
  ///
  /// [isDarkNow] is the brightness actually being rendered, which is the
  /// only thing that makes a toggle predictable while the mode is still
  /// [ThemeMode.system]: the user is choosing "not this", so the resolved
  /// brightness decides, not the stored preference.
  Future<void> toggle({required bool isDarkNow}) {
    return set(isDarkNow ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> set(ThemeMode mode) async {
    emit(mode);
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.setString(storageKey, stored);
  }
}

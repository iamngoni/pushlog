//
//  pushlog
//  storage_service.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class StorageService {
  StorageService(this.prefs);

  final SharedPreferences prefs;

  String? getString(String key) => prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      prefs.setString(key, value);

  Future<bool> remove(String key) => prefs.remove(key);

  Future<bool> clear() => prefs.clear();
}

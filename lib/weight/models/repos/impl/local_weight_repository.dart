import 'dart:convert';

import 'package:pushlog/core/services/storage_service.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';

class LocalWeightRepository {
  LocalWeightRepository({required this.storage, required this.scopeResolver});

  final StorageService storage;
  final String Function() scopeResolver;

  static const String entriesKey = 'pushlog.weight.entries';
  static const String settingsKey = 'pushlog.weight.settings';

  List<WeightEntry> loadEntries() {
    final raw = storage.getString(_scoped(entriesKey));
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => WeightEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveEntries(List<WeightEntry> entries) async {
    await storage.setString(
      _scoped(entriesKey),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  WeightSettings loadSettings() {
    final raw = storage.getString(_scoped(settingsKey));
    if (raw == null) return const WeightSettings();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const WeightSettings();
    return WeightSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveSettings(WeightSettings settings) async {
    await storage.setString(
      _scoped(settingsKey),
      jsonEncode(settings.toJson()),
    );
  }

  Future<void> reset() async {
    await storage.remove(_scoped(entriesKey));
    await storage.remove(_scoped(settingsKey));
  }

  String _scoped(String baseKey) => '$baseKey.${scopeResolver()}';
}

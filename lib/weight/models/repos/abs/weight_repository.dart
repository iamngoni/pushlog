import 'package:dartz/dartz.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';

abstract class WeightRepository {
  Future<Either<ApplicationError, List<WeightEntry>>> loadEntries();

  Future<Either<ApplicationError, WeightEntry>> saveEntry(WeightEntry entry);

  Future<WeightSettings> loadSettings();

  Future<Either<ApplicationError, WeightSettings>> saveSettings(
    WeightSettings settings,
  );

  Future<Either<ApplicationError, List<FriendWeighIn>>> loadFriendsBoard({
    required String asOf,
  });

  Future<void> reset();

  List<Map<String, dynamic>> exportEntries();
}

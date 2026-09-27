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

  /// Clears this account's weight on the device and in the cloud.
  Future<void> reset();

  /// Clears the device copy for [uid] only. Account deletion calls this after
  /// the server has already cascaded, when there is no session to reset with.
  Future<void> clearLocal({required String uid});

  List<Map<String, dynamic>> exportEntries();
}

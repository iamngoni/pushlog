import 'package:dartz/dartz.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/repos/abs/weight_repository.dart';

class MemoryWeightRepository implements WeightRepository {
  final List<WeightEntry> entries = [];
  WeightSettings settings = const WeightSettings();
  bool failBoard = false;

  @override
  List<Map<String, dynamic>> exportEntries() =>
      entries.map((entry) => entry.toJson()).toList();

  @override
  Future<Either<ApplicationError, List<WeightEntry>>> loadEntries() async {
    return Right(List.of(entries));
  }

  @override
  Future<Either<ApplicationError, List<FriendWeighIn>>> loadFriendsBoard({
    required String asOf,
  }) async {
    if (failBoard) {
      return const Left(
        ApplicationError(message: 'down', code: 'weight_board'),
      );
    }
    return const Right([]);
  }

  @override
  Future<WeightSettings> loadSettings() async => settings;

  @override
  Future<void> reset() async {
    entries.clear();
    settings = const WeightSettings();
  }

  @override
  Future<void> clearLocal({required String uid}) => reset();

  @override
  Future<Either<ApplicationError, WeightEntry>> saveEntry(
    WeightEntry entry,
  ) async {
    entries
      ..removeWhere((item) => item.recordedOn == entry.recordedOn)
      ..add(entry);
    return Right(entry);
  }

  @override
  Future<Either<ApplicationError, WeightSettings>> saveSettings(
    WeightSettings next,
  ) async {
    settings = next;
    return Right(next);
  }
}

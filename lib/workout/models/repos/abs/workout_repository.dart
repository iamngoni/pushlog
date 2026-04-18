import 'package:dartz/dartz.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

abstract class WorkoutRepository {
  Future<Either<ApplicationError, WorkoutSnapshot>>
      loadSnapshot();

  Future<Either<ApplicationError, WorkoutSnapshot>>
      saveSnapshot(WorkoutSnapshot snapshot);

  Future<Either<ApplicationError, WorkoutSnapshot>>
      resetSnapshot();

  Future<Either<ApplicationError, String>> exportJson();
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/repos/abs/weight_repository.dart';
import 'package:pushlog/weight/models/weight_math.dart';
import 'package:pushlog/weight/state/weight_state.dart';

class WeightCubit extends Cubit<WeightState> {
  WeightCubit(this._repository) : super(const WeightState());

  final WeightRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    final settings = await _repository.loadSettings();
    final entries = await _repository.loadEntries();
    emit(
      state.copyWith(
        isLoading: false,
        settings: settings,
        entries: entries.getOrElse(() => state.entries),
      ),
    );
  }

  Future<bool> log({required String recordedOn, required int grams}) async {
    final saved = await _repository.saveEntry(
      WeightEntry(
        recordedOn: recordedOn,
        weightGrams: grams,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        dirty: true,
      ),
    );
    return saved.fold((_) => false, (entry) {
      final next = [
        for (final item in state.entries)
          if (item.recordedOn != entry.recordedOn) item,
        entry,
      ]..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));
      emit(state.copyWith(entries: next));
      return true;
    });
  }

  Future<bool> logToday(int grams) {
    return log(recordedOn: localDayKey(DateTime.now()), grams: grams);
  }

  Future<void> updateSettings(WeightSettings settings) async {
    final saved = await _repository.saveSettings(settings);
    saved.fold(
      (_) => emit(state.copyWith(settings: settings.copyWith(dirty: true))),
      (value) => emit(state.copyWith(settings: value)),
    );
  }

  Future<void> loadBoard() async {
    final result = await _repository.loadFriendsBoard(
      asOf: localDayKey(DateTime.now()),
    );
    result.fold(
      (error) => emit(state.copyWith(boardError: error.message)),
      (board) => emit(state.copyWith(board: board, clearBoardError: true)),
    );
  }

  Future<void> reset() async {
    await _repository.reset();
    emit(const WeightState());
  }
}

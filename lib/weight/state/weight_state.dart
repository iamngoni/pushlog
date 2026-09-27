import 'package:equatable/equatable.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';

class WeightState extends Equatable {
  const WeightState({
    this.entries = const [],
    this.settings = const WeightSettings(),
    this.board = const [],
    this.boardError,
    this.isLoading = false,
  });

  final List<WeightEntry> entries;
  final WeightSettings settings;
  final List<FriendWeighIn> board;
  final String? boardError;
  final bool isLoading;

  WeightEntry? entryFor(String day) {
    for (final entry in entries) {
      if (entry.recordedOn == day) return entry;
    }
    return null;
  }

  WeightState copyWith({
    List<WeightEntry>? entries,
    WeightSettings? settings,
    List<FriendWeighIn>? board,
    String? boardError,
    bool clearBoardError = false,
    bool? isLoading,
  }) {
    return WeightState(
      entries: entries ?? this.entries,
      settings: settings ?? this.settings,
      board: board ?? this.board,
      boardError: clearBoardError ? null : boardError ?? this.boardError,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [entries, settings, board, boardError, isLoading];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';

import '../support/memory_weight_repository.dart';

void main() {
  test('logging the same day replaces the first entry', () async {
    final repo = MemoryWeightRepository();
    final cubit = WeightCubit(repo);
    await cubit.log(recordedOn: '2026-09-27', grams: 70000);
    await cubit.log(recordedOn: '2026-09-27', grams: 71000);
    expect(cubit.state.entries, hasLength(1));
    expect(cubit.state.entries.single.weightGrams, 71000);
    await cubit.close();
  });

  test('board failure does not clear entries', () async {
    final repo = MemoryWeightRepository()..failBoard = true;
    final cubit = WeightCubit(repo);
    await cubit.log(recordedOn: '2026-09-27', grams: 70000);
    await cubit.loadBoard();
    expect(cubit.state.entries, hasLength(1));
    expect(cubit.state.boardError, 'down');
    await cubit.close();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/weight/models/weight_math.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';
import 'package:pushlog/weight/views/widgets/log_weight_sheet.dart';

import '../support/memory_weight_repository.dart';

Future<void> pumpSheet(WidgetTester tester, WeightCubit cubit) {
  final theme = AppTheme.light();
  return tester.pumpWidget(
    MaterialApp(
      theme: theme.toMaterialTheme(Brightness.light),
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: LogWeightSheet()),
      ),
    ),
  );
}

void main() {
  testWidgets('saving 72.5 stores 72500 grams for today', (tester) async {
    final repo = MemoryWeightRepository();
    final cubit = WeightCubit(repo);
    await pumpSheet(tester, cubit);
    await tester.enterText(find.byType(TextField), '72.5');
    await tester.tap(find.text('Save weight'));
    await tester.pump();
    expect(repo.entries.single.weightGrams, 72500);
    expect(repo.entries.single.recordedOn, localDayKey(DateTime.now()));
    await cubit.close();
  });

  testWidgets('opening today prefills the saved display value', (tester) async {
    final repo = MemoryWeightRepository();
    final cubit = WeightCubit(repo);
    await cubit.log(recordedOn: localDayKey(DateTime.now()), grams: 72500);
    await pumpSheet(tester, cubit);
    expect(find.text('72.5'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('empty input does not save', (tester) async {
    final repo = MemoryWeightRepository();
    final cubit = WeightCubit(repo);
    await pumpSheet(tester, cubit);
    await tester.tap(find.text('Save weight'));
    await tester.pump();
    expect(repo.entries, isEmpty);
    expect(find.text('Enter a weight above zero.'), findsOneWidget);
    await cubit.close();
  });
}

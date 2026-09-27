import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';
import 'package:pushlog/weight/views/widgets/weight_settings_section.dart';

import '../support/memory_weight_repository.dart';

void main() {
  testWidgets('latest weight cannot be enabled while progress is off', (
    tester,
  ) async {
    final cubit = WeightCubit(MemoryWeightRepository());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: WeightSettingsSection()),
        ),
      ),
    );
    final latest = tester.widget<Switch>(find.byType(Switch).at(1));
    expect(latest.onChanged, isNull);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    final enabled = tester.widget<Switch>(find.byType(Switch).at(1));
    expect(enabled.onChanged, isNotNull);
    await cubit.close();
  });
}

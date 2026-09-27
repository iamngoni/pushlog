import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/weight_math.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';

Future<void> showLogWeightSheet(BuildContext context) {
  final cubit = context.read<WeightCubit>();
  final theme = AppTheme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.background,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const LogWeightSheet()),
  );
}

class LogWeightSheet extends StatefulWidget {
  const LogWeightSheet({super.key});

  @override
  State<LogWeightSheet> createState() => LogWeightSheetState();
}

class LogWeightSheetState extends State<LogWeightSheet> {
  final controller = TextEditingController();
  String? errorText;

  @override
  void initState() {
    super.initState();
    final state = context.read<WeightCubit>().state;
    final today = localDayKey(DateTime.now());
    final existing = state.entryFor(today);
    if (existing != null) {
      controller.text = gramsToDisplay(
        existing.weightGrams,
        state.settings.unit,
      ).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final cubit = context.read<WeightCubit>();
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => errorText = 'Enter a weight above zero.');
      return;
    }
    final grams = displayToGrams(parsed, cubit.state.settings.unit);
    final saved = await cubit.logToday(grams);
    if (!mounted) return;
    if (!saved) {
      setState(() => errorText = 'Could not save that weight.');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final unit = context.watch<WeightCubit>().state.settings.unit;
    final today = context.read<WeightCubit>().state.entryFor(
      localDayKey(DateTime.now()),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log weight',
            style: AppTypography.headingSmall(color: theme.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            today == null
                ? 'Saved on this device, then synced.'
                : "Updates today's weight.",
            style: AppTypography.body(color: theme.secondaryInk),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: unit == WeightUnit.kg ? 'Kilograms' : 'Pounds',
              errorText: errorText,
            ),
            onSubmitted: (_) => save(),
          ),
          const SizedBox(height: AppSpacing.xl),
          PushlogButton(label: 'Save weight', onPressed: save),
        ],
      ),
    );
  }
}

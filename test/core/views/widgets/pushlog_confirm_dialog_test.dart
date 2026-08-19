import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/views/widgets/pushlog_confirm_dialog.dart';

void main() {
  late List<bool> answers;

  setUp(() => answers = <bool>[]);

  /// Renders a button that asks, and records what the user answered.
  Future<void> pumpAsker(
    WidgetTester tester, {
    bool isDestructive = true,
  }) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final confirmed = await PushlogConfirmDialog.ask(
                  context,
                  title: 'Sign out of Pushlog?',
                  message: 'You will need to sign in again.',
                  confirmLabel: 'Sign out',
                  isDestructive: isDestructive,
                );
                answers.add(confirmed);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirming answers true', (tester) async {
    await pumpAsker(tester);
    await openDialog(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(answers, [true]);
  });

  testWidgets('cancelling answers false', (tester) async {
    await pumpAsker(tester);
    await openDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('dismissing without choosing answers false', (tester) async {
    await pumpAsker(tester);
    await openDialog(tester);

    // A barrier tap is a decision not to act, not a silent yes.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });

  testWidgets('the action does not run until it is confirmed', (
    tester,
  ) async {
    await pumpAsker(tester);
    await openDialog(tester);

    expect(answers, isEmpty);
    expect(find.text('Sign out of Pushlog?'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/views/widgets/pushlog_toast.dart';

/// Pumps a host with a button that raises [onPressed] against a live
/// overlay, which is what [PushlogToast] renders into.
Future<void> _pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) onPressed,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light().toMaterialTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(PushlogToast.dismiss);

  testWidgets('shows the message and detail', (tester) async {
    await _pumpHost(
      tester,
      (context) => PushlogToast.success(
        context,
        '+10 reps logged',
        detail: '40 to go today',
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('+10 reps logged'), findsOneWidget);
    expect(find.text('40 to go today'), findsOneWidget);
  });

  testWidgets('dismisses itself once its duration elapses', (tester) async {
    await _pumpHost(
      tester,
      (context) => PushlogToast.info(
        context,
        'Saved',
        duration: const Duration(milliseconds: 600),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('runs the action and closes when tapped', (tester) async {
    var undone = false;

    await _pumpHost(
      tester,
      (context) => PushlogToast.success(
        context,
        '+10 reps logged',
        actionLabel: 'Undo',
        onAction: () => undone = true,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.text('+10 reps logged'), findsNothing);
  });

  testWidgets('replaces the visible toast rather than stacking', (
    tester,
  ) async {
    late BuildContext hostContext;

    await _pumpHost(tester, (context) {
      hostContext = context;
      PushlogToast.info(context, 'First');
    });

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('First'), findsOneWidget);

    PushlogToast.warning(hostContext, 'Second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('close button dismisses without running the action', (
    tester,
  ) async {
    var actioned = false;

    await _pumpHost(
      tester,
      (context) => PushlogToast.danger(
        context,
        'Could not sync',
        actionLabel: 'Retry',
        onAction: () => actioned = true,
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();

    expect(actioned, isFalse);
    expect(find.text('Could not sync'), findsNothing);
  });

  testWidgets('hides the countdown bar when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        // Applied through the app builder rather than inside `home`: the
        // toast renders into the root overlay, which sits above the home
        // subtree, so a MediaQuery placed there would never reach it.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => PushlogToast.info(context, 'Saved'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}

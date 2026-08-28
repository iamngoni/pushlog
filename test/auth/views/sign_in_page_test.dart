import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/auth/views/sign_in_page.dart';
import 'package:pushlog/core/views/widgets/about_sheet.dart';
import 'package:pushlog/core/views/widgets/google_glyph.dart';
import 'package:pushlog/core/views/widgets/pushlog_logo.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  late AuthCubit authCubit;

  setUp(() {
    authCubit = _MockAuthCubit();
    when(() => authCubit.state).thenReturn(const AuthSignedOut());
  });

  Future<void> pumpSignInPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: const SignInPage(),
        ),
      ),
    );
  }

  testWidgets(
    'offers both providers on Apple platforms',
    (tester) async {
      await pumpSignInPage(tester);

      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    },
    // TargetPlatformVariant owns the override, so the debug variable is
    // restored before the framework checks it at the end of the body.
    variant: const TargetPlatformVariant(
      <TargetPlatform>{TargetPlatform.iOS, TargetPlatform.macOS},
    ),
  );

  testWidgets(
    'hides Apple on Android',
    (tester) async {
      await pumpSignInPage(tester);

      // Sign in with Apple on Android is a web redirect, not a system
      // sheet. Offering it advertises parity the platform does not have.
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'marks the Google option with its brand glyph',
    (tester) async {
      await pumpSignInPage(tester);

      expect(find.byType(GoogleGlyph), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('opens the About sheet from the header', (tester) async {
    await pumpSignInPage(tester);

    expect(find.byType(AboutSheet), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AboutSheet), findsOneWidget);
    // Asserted on the sheet's own overline rather than "Pushlog", which now
    // also appears in the brand block on the page behind it.
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Account deletion'), findsOneWidget);
  });

  testWidgets('leads with the brand mark and app name', (tester) async {
    await pumpSignInPage(tester);

    expect(find.byType(PushlogLogo), findsOneWidget);
    expect(find.text('Pushlog'), findsOneWidget);
  });

  testWidgets('the About control is reachable by its label', (tester) async {
    await pumpSignInPage(tester);

    // The header slot is an icon, so the accessible name has to come from
    // the semantics rather than a visible string.
    expect(
      find.bySemanticsLabel('About Pushlog'),
      findsOneWidget,
    );
  });
}

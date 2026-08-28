//
//  pushlog
//  app_version_label_test.dart
//
//  Created by Ngonidzashe Mangudya on 2026/08/28.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//  https://codecraftsolutions.co.za/
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/services/app_info_service.dart';
import 'package:pushlog/settings/views/widgets/app_version_label.dart';

PackageInfo packageInfo({
  String version = '1.1.0',
  String buildNumber = '21',
}) {
  return PackageInfo(
    appName: 'Pushlog',
    packageName: 'za.co.codecraftsolutions.pushlog',
    version: version,
    buildNumber: buildNumber,
  );
}

void main() {
  testWidgets('shows the installed version and build number', (tester) async {
    final service = AppInfoService(
      packageInfoLoader: () async => packageInfo(),
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: AppVersionLabel(appInfoService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pushlog 1.1.0 (21)'), findsOneWidget);
    expect(
      find.bySemanticsLabel('App version 1.1.0, build 21'),
      findsOneWidget,
    );
  });

  testWidgets('shows a stable loading state before metadata arrives', (
    tester,
  ) async {
    final completer = Completer<PackageInfo>();
    final service = AppInfoService(
      packageInfoLoader: () => completer.future,
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: AppVersionLabel(appInfoService: service),
        ),
      ),
    );

    expect(find.text('Pushlog version…'), findsOneWidget);

    completer.complete(packageInfo());
    await tester.pumpAndSettle();

    expect(find.text('Pushlog 1.1.0 (21)'), findsOneWidget);
  });

  testWidgets('shows a clear fallback when metadata fails', (tester) async {
    final service = AppInfoService(
      packageInfoLoader: () async {
        throw StateError('metadata unavailable');
      },
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: AppVersionLabel(appInfoService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('App version unavailable'), findsOneWidget);
  });

  testWidgets('omits empty build-number punctuation', (tester) async {
    final service = AppInfoService(
      packageInfoLoader: () async => packageInfo(buildNumber: ''),
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: AppVersionLabel(appInfoService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pushlog 1.1.0'), findsOneWidget);
    expect(find.textContaining('()'), findsNothing);
  });

  testWidgets('remains readable on a narrow screen with large text', (
    tester,
  ) async {
    final service = AppInfoService(
      packageInfoLoader: () async => packageInfo(),
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          );
        },
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: AppVersionLabel(appInfoService: service),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pushlog 1.1.0 (21)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

//
//  pushlog
//  app_version_label.dart
//
//  Created by Ngonidzashe Mangudya on 2026/08/28.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//  https://codecraftsolutions.co.za/
//

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/app_info_service.dart';

/// Displays the version metadata embedded in the installed application.
class AppVersionLabel extends StatefulWidget {
  /// Creates an installed application version label.
  const AppVersionLabel({
    required this.appInfoService,
    super.key,
  });

  /// Supplies the platform application metadata.
  final AppInfoService appInfoService;

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<Either<ApplicationError, AppInfo>> appInfoFuture;

  String formatLabel(AppInfo appInfo) {
    final version = appInfo.version.trim();
    final buildNumber = appInfo.buildNumber.trim();
    if (version.isEmpty) return 'Version unavailable';
    if (buildNumber.isEmpty) return 'Pushlog $version';
    return 'Pushlog $version ($buildNumber)';
  }

  Widget buildLabel({
    required AppTheme theme,
    required String label,
    required String semanticLabel,
  }) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    appInfoFuture = widget.appInfoService.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return FutureBuilder<Either<ApplicationError, AppInfo>>(
      future: appInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return buildLabel(
            theme: theme,
            label: 'Pushlog version…',
            semanticLabel: 'Loading app version',
          );
        }

        final result = snapshot.data;
        if (snapshot.hasError || result == null) {
          return buildLabel(
            theme: theme,
            label: 'Version unavailable',
            semanticLabel: 'App version unavailable',
          );
        }

        return result.fold(
          (_) => buildLabel(
            theme: theme,
            label: 'Version unavailable',
            semanticLabel: 'App version unavailable',
          ),
          (appInfo) => buildLabel(
            theme: theme,
            label: formatLabel(appInfo),
            semanticLabel:
                'App version ${appInfo.version}, build ${appInfo.buildNumber}',
          ),
        );
      },
    );
  }
}

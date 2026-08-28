//
//  pushlog
//  app_info_service.dart
//
//  Created by Ngonidzashe Mangudya on 2026/08/28.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//  https://codecraftsolutions.co.za/
//

import 'dart:developer';

import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pushlog/core/models/data/application_error.dart';

/// Loads package metadata from the current host platform.
typedef PackageInfoLoader = Future<PackageInfo> Function();

/// The version metadata embedded in the installed application bundle.
class AppInfo {
  /// Creates installed application metadata.
  const AppInfo({
    required this.version,
    required this.buildNumber,
  });

  /// The user-facing release version.
  final String version;

  /// The store build identifier.
  final String buildNumber;
}

/// Loads installed application metadata from the host platform.
class AppInfoService {
  /// Creates an application metadata service.
  const AppInfoService({
    this.packageInfoLoader = PackageInfo.fromPlatform,
  });

  /// The platform metadata loader.
  final PackageInfoLoader packageInfoLoader;

  /// Loads the current installed version and build number.
  Future<Either<ApplicationError, AppInfo>> load() async {
    try {
      final packageInfo = await packageInfoLoader();
      return Right(
        AppInfo(
          version: packageInfo.version,
          buildNumber: packageInfo.buildNumber,
        ),
      );
    } on Object catch (error, stackTrace) {
      log(
        'Unable to load installed application metadata',
        name: 'pushlog.app_info',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(ApplicationError.unknownError());
    }
  }
}

//
//  pushlog
//  main_production.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:pushlog/app.dart';
import 'package:pushlog/bootstrap.dart';
import 'package:pushlog/core/configs/app_environment.dart';

Future<void> main() async {
  await bootstrap(
    () => const App(),
    environment: AppEnvironment.production,
    sentryDsn: const String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue:
          'https://04068260d79f0124c17ba3ef64fea7a9@o1107818.ingest.us.sentry.io/4512021547122688',
    ),
  );
}

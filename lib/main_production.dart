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
  );
}

//
//  pushlog
//  bootstrap.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pushlog/core/configs/app_environment.dart';
import 'package:pushlog/firebase_options.dart';
import 'package:pushlog/injection.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(
    BlocBase<dynamic> bloc,
    Change<dynamic> change,
  ) {
    super.onChange(bloc, change);
    if (!kDebugMode) return;
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(
    BlocBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      log(
        'onError(${bloc.runtimeType}, $error, $stackTrace)',
      );
    }
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(
  FutureOr<Widget> Function() builder, {
  required AppEnvironment environment,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate();

  FlutterError.onError = (details) {
    if (!kDebugMode) return;
    log(
      details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  await configureInjection(environment: environment);
  if (kDebugMode) log('Injection configured');

  Bloc.observer = const AppBlocObserver();

  runApp(await builder());
}

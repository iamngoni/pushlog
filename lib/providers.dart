//
//  pushlog
//  providers.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

List<BlocProvider> providers = [
  BlocProvider<WorkoutBloc>(
    lazy: false,
    create: (_) => getIt<WorkoutBloc>(),
  ),
];

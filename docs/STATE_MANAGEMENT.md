# State Management

This project uses **BLoC** (Business Logic Component) pattern with `flutter_bloc`.

## Technology Stack

- `flutter_bloc` - State management
- `bloc` - Core BLoC library
- `equatable` - Value equality for events and states
- `get_it` - Service locator / dependency injection
- `injectable` - Auto-generate DI boilerplate

## BLoC Structure

Each BLoC consists of three files:

```
/state/
└── /auth/
    ├── auth_bloc.dart
    ├── auth_event.dart
    └── auth_state.dart
```

### Events

```dart
part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
}

final class CheckAuthEvent extends AuthEvent {
  const CheckAuthEvent();

  @override
  List<Object?> get props => [];
}

final class LoginEvent extends AuthEvent {
  const LoginEvent(this.dto);
  final LoginDTO dto;

  @override
  List<Object?> get props => [dto];
}

final class LogoutEvent extends AuthEvent {
  const LogoutEvent();

  @override
  List<Object?> get props => [];
}
```

### States

```dart
part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  List<Object?> get props => [];
}

final class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  List<Object?> get props => [];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  List<Object?> get props => [];
}

final class AuthError extends AuthState {
  const AuthError(this.error);
  final ApplicationError error;

  @override
  List<Object?> get props => [error];
}
```

### BLoC

```dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository}) : super(const AuthInitial()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
  }

  final AuthRepository repository;

  Future<void> _onCheckAuth(
    CheckAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await repository.isAuthenticated();
    result.fold(
      (error) => emit(const AuthUnauthenticated()),
      (isAuth) => isAuth
          ? emit(const AuthAuthenticated())
          : emit(const AuthUnauthenticated()),
    );
  }

  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await repository.login(event.dto);
      result.fold(
        (error) => emit(AuthError(error)),
        (response) => emit(AuthAuthenticated(response.user)),
      );
    } catch (e, s) {
      unawaited(Sentry.captureException(e, stackTrace: s));
      emit(AuthError(ApplicationError.unknownError()));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await repository.logout();
    emit(const AuthUnauthenticated());
  }
}
```

## Global Providers

Register all BLoCs in `providers.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'injection.dart';

class AppProviders extends StatelessWidget {
  const AppProviders({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(const CheckAuthEvent()),
        ),
        BlocProvider<UserBloc>(
          create: (_) => getIt<UserBloc>(),
        ),
        BlocProvider<ConnectivityBloc>(
          create: (_) => getIt<ConnectivityBloc>()..add(const CheckConnectivity()),
        ),
        // Add more BLoCs here
      ],
      child: child,
    );
  }
}
```

## Using BLoCs in Widgets

### BlocBuilder
Rebuild widget when state changes:

```dart
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) {
      return const LoaderWidget();
    }
    if (state is AuthAuthenticated) {
      return Text('Welcome, ${state.user.name}');
    }
    return const LoginForm();
  },
)
```

### BlocListener
React to state changes (navigation, toasts):

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      context.goToAndRemoveUntil(page: const HomePage());
    } else if (state is AuthError) {
      context.notify(state.error.message, isError: true);
    }
  },
  child: const LoginForm(),
)
```

### BlocConsumer
Combine builder and listener:

```dart
BlocConsumer<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      context.notify(state.error.message, isError: true);
    }
  },
  builder: (context, state) {
    if (state is AuthLoading) {
      return const LoaderWidget();
    }
    return const LoginForm();
  },
)
```

### Dispatching Events

```dart
context.read<AuthBloc>().add(LoginEvent(dto));
```

## Error Handling Pattern

Always use `Either<ApplicationError, T>` from dartz:

```dart
Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
  emit(const AuthLoading());
  try {
    final result = await repository.login(event.dto);
    result.fold(
      (error) => emit(AuthError(error)),      // Left = Error
      (success) => emit(AuthAuthenticated(success.user)),  // Right = Success
    );
  } catch (e, s) {
    // Log unexpected errors
    unawaited(Sentry.captureException(e, stackTrace: s));
    emit(AuthError(ApplicationError.unknownError()));
  }
}
```

# Feature Structure

Each feature module follows this consistent structure:

```
/feature_name/
├── /models/
│   ├── /data/           # Freezed data classes (entities)
│   ├── /dto/            # Data Transfer Objects (API requests)
│   └── /repos/
│       ├── /abs/        # Abstract repositories (interfaces)
│       └── /impl/       # Concrete implementations
│
├── /state/
│   └── /bloc_name/
│       ├── bloc_name_bloc.dart
│       ├── bloc_name_event.dart
│       └── bloc_name_state.dart
│
└── /views/
    ├── /pages/          # Full-screen pages
    └── /widgets/        # Feature-specific widgets
```

## Models

### Data Classes
Immutable entities using Freezed:

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

### DTOs
Request objects for API calls:

```dart
@freezed
class LoginDTO with _$LoginDTO {
  const factory LoginDTO({
    required String username,
    required String password,
  }) = _LoginDTO;

  const LoginDTO._();

  factory LoginDTO.fromJson(Map<String, dynamic> json) => _$LoginDTOFromJson(json);
}
```

### Repositories

Abstract interface:
```dart
abstract class AuthRepository {
  Future<Either<ApplicationError, AuthResponse>> login(LoginDTO dto);
  Future<Either<ApplicationError, void>> logout();
}
```

Concrete implementation:
```dart
@LazySingleton(as: AuthRepository)
class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this.dio);
  final Dio dio;

  @override
  Future<Either<ApplicationError, AuthResponse>> login(LoginDTO dto) async {
    try {
      final response = await dio.post('/auth/login', data: dto.toJson());
      return Right(AuthResponse.fromJson(response.data));
    } on DioException catch (e) {
      return Left(dioErrorToApplicationError(e));
    }
  }
}
```

## State (BLoC)

### Events
```dart
sealed class AuthEvent extends Equatable {
  const AuthEvent();
}

final class LoginEvent extends AuthEvent {
  const LoginEvent(this.dto);
  final LoginDTO dto;

  @override
  List<Object?> get props => [dto];
}
```

### States
```dart
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

final class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);
  final User user;

  @override
  List<Object?> get props => [user];
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
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository}) : super(const AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
  }

  final AuthRepository repository;

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await repository.login(event.dto);
    result.fold(
      (error) => emit(AuthError(error)),
      (response) => emit(AuthSuccess(response.user)),
    );
  }
}
```

## Views

### Pages
Full-screen views that consume BLoCs:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          context.goToAndRemoveUntil(page: const HomePage());
        } else if (state is AuthError) {
          context.notify(state.error.message, isError: true);
        }
      },
      child: const LoginForm(),
    );
  }
}
```

### Widgets
Feature-specific reusable components.

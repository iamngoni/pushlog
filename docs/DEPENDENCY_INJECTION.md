# Dependency Injection

This project uses **GetIt** with **Injectable** for dependency injection.

## Setup

### injection.dart

```dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureInjection() async => getIt.init();
```

### Module Registration

Create modules for third-party dependencies:

```dart
@module
abstract class RegisterModule {
  @lazySingleton
  Dio get dio => Dio(
        BaseOptions(
          baseUrl: EnvironmentConfig.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      )
        ..interceptors.add(DioRequestInterceptor())
        ..interceptors.add(DioOnErrorInterceptor());

  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @lazySingleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
```

## Annotations

### @injectable
For classes that should be registered:

```dart
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository}) : super(const AuthInitial());
  final AuthRepository repository;
}
```

### @lazySingleton
For singletons (created on first access):

```dart
@lazySingleton
class StorageService {
  StorageService(this._prefs);
  final SharedPreferences _prefs;
}
```

### @singleton
For eager singletons (created immediately):

```dart
@singleton
class AnalyticsService {
  AnalyticsService();
}
```

### @LazySingleton(as: Interface)
For binding implementation to interface:

```dart
@LazySingleton(as: AuthRepository)
class DioAuthRepository implements AuthRepository {
  const DioAuthRepository(this.dio);
  final Dio dio;
}
```

### @preResolve
For async dependencies:

```dart
@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

## Code Generation

Run build_runner to generate DI configuration:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates `injection.config.dart` with all registrations.

## Usage

### In Bootstrap

```dart
Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure DI
  await configureInjection();
  
  // Wait for async dependencies
  await getIt.allReady();
  
  runApp(await builder());
}
```

### Getting Dependencies

```dart
// In providers.dart
BlocProvider<AuthBloc>(
  create: (_) => getIt<AuthBloc>(),
)

// Anywhere else
final storage = getIt<StorageService>();
```

## Best Practices

### Constructor Injection
Prefer constructor injection over service locator:

```dart
// Good - dependencies are explicit
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository, required this.storage});
  final AuthRepository repository;
  final StorageService storage;
}

// Avoid - hidden dependencies
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final repository = getIt<AuthRepository>();  // Hidden
}
```

### Interface Binding
Bind implementations to interfaces:

```dart
// Abstract repository
abstract class AuthRepository {
  Future<Either<ApplicationError, AuthResponse>> login(LoginDTO dto);
}

// Implementation bound to interface
@LazySingleton(as: AuthRepository)
class DioAuthRepository implements AuthRepository {
  // ...
}

// BLoC depends on interface, not implementation
@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository});
  final AuthRepository repository;  // Interface type
}
```

### Lazy vs Eager
- Use `@lazySingleton` for most services (created when needed)
- Use `@singleton` only for services that must initialize early
- Use `@injectable` for BLoCs and other non-singletons

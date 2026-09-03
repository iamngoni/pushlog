# Coding Conventions

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `auth_bloc.dart` |
| Classes | PascalCase | `AuthBloc` |
| Variables | camelCase | `userName` |
| Constants | camelCase | `maxRetries` |
| Enums | PascalCase | `AuthStatus` |
| Enum values | camelCase | `AuthStatus.authenticated` |

### Specific Naming Patterns

| Type | Pattern | Example |
|------|---------|---------|
| BLoCs | `*Bloc` | `AuthBloc`, `UserBloc` |
| Events | `*Event` | `LoginEvent`, `LogoutEvent` |
| States | `*State` (sealed) | `AuthState`, `AuthLoading` |
| DTOs | `*DTO` | `LoginDTO`, `SignupDTO` |
| Repositories (abstract) | `*Repository` | `AuthRepository` |
| Repositories (impl) | `Dio*Repository` | `DioAuthRepository` |
| Services | `*Service` | `StorageService` |
| Pages | `*Page` | `LoginPage`, `HomePage` |

### No Private Members in Widgets

Do not use underscore prefix for members or methods inside widget classes (both `StatelessWidget` and `StatefulWidget`/`State`). Widgets are UI components where internal methods are implementation details that don't need privacy modifiers.

```dart
// Good - no underscores in widgets
class LoginPage extends StatelessWidget {
  Widget buildHeader() {}
  Widget buildForm() {}
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void handleSubmit() {}
  void validateEmail() {}
}

// Bad - unnecessary underscores
class LoginPage extends StatelessWidget {
  Widget _buildHeader() {}
  Widget _buildForm() {}
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  void _handleSubmit() {}
}
```

## File Headers

Every file should include a header comment:

```dart
//
//  seta
//  filename.dart
//
//  Created by Ngonidzashe Mangudya on YYYY/MM/DD.
//  Copyright (c) YYYY Codecraft Solutions. All rights reserved.
//  https://codecraftsolutions.co.za/
//
```

## Code Style

### Imports
Order imports in groups:
1. Dart SDK
2. Flutter SDK
3. External packages
4. Project imports (relative)

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/repos/abs/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
```

### Prefer Relative Imports
Use relative imports for project files:

```dart
// Good
import '../models/data/user.dart';

// Avoid
import 'package:pushlog/auth/models/data/user.dart';
```

### Class Structure
Order class members:
1. Static constants
2. Final fields
3. Mutable fields
4. Constructors
5. Factory constructors
6. Getters/Setters
7. Public methods
8. Private methods
9. @override methods

```dart
class MyWidget extends StatelessWidget {
  // 1. Static constants
  static const double defaultPadding = 16.0;

  // 2. Final fields
  final String title;
  final VoidCallback onTap;

  // 4. Constructors
  const MyWidget({
    required this.title,
    required this.onTap,
    super.key,
  });

  // 7. Public methods
  void doSomething() {}

  // 8. Private methods
  void _handleTap() {}

  // 9. @override methods
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### Constructor Parameters
Use `required` for non-nullable parameters, put `super.key` last:

```dart
const MyWidget({
  required this.title,
  required this.onTap,
  this.subtitle,
  super.key,
});
```

### Const Constructors
Always use `const` where possible:

```dart
// Good
const EdgeInsets.all(16)
const SizedBox(height: 8)
const Text('Hello')

// Widgets
const MyWidget({super.key});
```

### Trailing Commas
Always use trailing commas for better formatting:

```dart
// Good
Container(
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.symmetric(horizontal: 8),
  child: const Text('Hello'),
)

// Avoid
Container(
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.symmetric(horizontal: 8),
  child: const Text('Hello')
)
```

## Linting

Use `very_good_analysis` for strict linting:

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.7.0.0.yaml

analyzer:
  exclude:
    - "**/*.freezed.dart"
    - "**/*.g.dart"
    - "lib/gen/**"
    - "lib/l10n/**"

linter:
  rules:
    prefer_relative_imports: true
    always_declare_return_types: true
    lines_longer_than_80_chars: true
```

## Documentation

### Public APIs
Document public classes and methods:

```dart
/// Repository for authentication operations.
///
/// Handles login, logout, and token management.
abstract class AuthRepository {
  /// Authenticates a user with the provided credentials.
  ///
  /// Returns [Either] with [ApplicationError] on failure
  /// or [AuthResponse] on success.
  Future<Either<ApplicationError, AuthResponse>> login(LoginDTO dto);
}
```

### Avoid Unnecessary Comments
Don't comment obvious code:

```dart
// Bad
// Get the user name
final userName = user.name;

// Good - self-documenting code
final userName = user.name;
```

## Error Handling

### Use Either for Results
```dart
Future<Either<ApplicationError, User>> getUser(String id);
```

### Handle All Cases
```dart
result.fold(
  (error) => emit(UserError(error)),
  (user) => emit(UserLoaded(user)),
);
```

### Log Unexpected Errors
```dart
try {
  // ...
} catch (e, s) {
  log(e.toString(), error: e, stackTrace: s);
  unawaited(Sentry.captureException(e, stackTrace: s));
  emit(ErrorState(ApplicationError.unknownError()));
}
```

## Widget Best Practices

### Prefer StatelessWidget
Use `StatelessWidget` unless local state is needed:

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyBloc, MyState>(
      builder: (context, state) {
        // Use BLoC for state
      },
    );
  }
}
```

### Extract Widgets
Break down large widgets into smaller ones:

```dart
// Good
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LoginHeader(),
        const LoginForm(),
        const LoginFooter(),
      ],
    );
  }
}
```

### Use const Widgets
Mark widgets as const when possible:

```dart
const LoginHeader()  // Good
LoginHeader()        // Only if parameters are dynamic
```

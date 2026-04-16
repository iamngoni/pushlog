# Dependencies

## Core Dependencies

### State Management
```yaml
flutter_bloc: ^8.1.3      # BLoC pattern implementation
bloc: ^8.1.2              # Core BLoC library
equatable: ^2.0.5         # Value equality for events/states
```

### Dependency Injection
```yaml
get_it: ^7.6.4            # Service locator
injectable: ^2.3.2        # DI code generation annotations
```

### Networking
```yaml
dio: ^5.3.2               # HTTP client
```

### Data & Models
```yaml
freezed_annotation: ^2.4.1  # Immutable model annotations
json_annotation: ^4.8.1     # JSON serialization annotations
dartz: ^0.10.1              # Functional programming (Either type)
```

### Storage
```yaml
shared_preferences: ^2.2.2      # Key-value storage
flutter_secure_storage: ^9.0.0  # Encrypted storage
```

### Firebase
```yaml
firebase_core: ^2.24.2
firebase_messaging: ^14.7.10
firebase_crashlytics: ^3.4.8
firebase_app_check: ^0.2.1+8
```

### Error Tracking
```yaml
sentry_flutter: ^8.7.0    # Error monitoring
```

### UI
```yaml
relative_scale: ^2.0.0    # Responsive sizing
```

### Localization
```yaml
flutter_localizations:
  sdk: flutter
intl: ^0.19.0
```

## Dev Dependencies

### Code Generation
```yaml
build_runner: ^2.4.6           # Code generation runner
freezed: ^2.4.2                # Immutable model generation
json_serializable: ^6.7.1      # JSON code generation
injectable_generator: ^2.4.1   # DI code generation
flutter_gen_runner: ^5.3.1     # Asset code generation
```

### Linting
```yaml
very_good_analysis: ^7.0.0     # Strict lint rules
```

### Testing
```yaml
flutter_test:
  sdk: flutter
bloc_test: ^9.1.5              # BLoC testing utilities
mocktail: ^1.0.1               # Mocking library
```

## Full pubspec.yaml Template

```yaml
name: sipmate
description: SipMate Flutter Application
version: 1.0.0+1
publish_to: none

environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_bloc: ^8.1.3
  bloc: ^8.1.2
  equatable: ^2.0.5

  # Dependency Injection
  get_it: ^7.6.4
  injectable: ^2.3.2

  # Networking
  dio: ^5.3.2

  # Data & Models
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  dartz: ^0.10.1

  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0

  # Firebase
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
  firebase_crashlytics: ^3.4.8

  # Error Tracking
  sentry_flutter: ^8.7.0

  # UI
  relative_scale: ^2.0.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.6
  freezed: ^2.4.2
  json_serializable: ^6.7.1
  injectable_generator: ^2.4.1
  flutter_gen_runner: ^5.3.1

  # Linting
  very_good_analysis: ^7.0.0

  # Testing
  bloc_test: ^9.1.5
  mocktail: ^1.0.1

flutter:
  uses-material-design: true
  generate: true

  assets:
    - assets/images/
    - assets/icons/
    - assets/lottie/

  fonts:
    - family: Inter
      fonts:
        - asset: fonts/Inter-Regular.ttf
        - asset: fonts/Inter-Medium.ttf
          weight: 500
        - asset: fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: fonts/Inter-Bold.ttf
          weight: 700
```

## Configuration Files

### analysis_options.yaml
```yaml
include: package:very_good_analysis/analysis_options.7.0.0.yaml

analyzer:
  exclude:
    - "**/*.freezed.dart"
    - "**/*.g.dart"
    - "lib/gen/**"
    - "lib/l10n/**"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    prefer_relative_imports: true
    always_declare_return_types: true
    lines_longer_than_80_chars: true
    cancel_subscriptions: true
    close_sinks: true
```

### build.yaml
```yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          include_if_null: false
          explicit_to_json: true
```

### l10n.yaml
```yaml
arb-dir: lib/l10n/arb
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

## Code Generation Commands

```bash
# Generate all code (freezed, json, injectable, flutter_gen)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch for changes and regenerate
flutter pub run build_runner watch --delete-conflicting-outputs

# Generate localizations
flutter gen-l10n
```

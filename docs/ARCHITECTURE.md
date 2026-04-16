# Architecture

This project follows **Clean Architecture with Feature-Based Organization**.

## Directory Structure

```
lib/
├── main_development.dart    # Entry point for development flavor
├── main_staging.dart        # Entry point for staging flavor
├── main_production.dart     # Entry point for production flavor
├── app.dart                 # Main app widget with theming
├── bootstrap.dart           # App initialization logic
├── providers.dart           # Global BLoC providers
├── injection.dart           # Dependency injection setup
│
├── /gen/                    # Generated code (FlutterGen)
│   ├── assets.gen.dart      # Auto-generated asset references
│   └── fonts.gen.dart       # Auto-generated font references
│
├── /l10n/                   # Localization (i18n)
│   └── /arb/                # ARB translation files
│
├── /core/                   # Shared code (see CORE_MODULE.md)
│
└── /feature_name/           # Feature modules (see FEATURE_STRUCTURE.md)
```

## Layers

### 1. Presentation Layer (`/views/`)
- Pages: Full-screen views
- Widgets: Reusable UI components
- Uses BLoC for state management

### 2. Business Logic Layer (`/state/`)
- BLoCs handle all business logic
- Events trigger state changes
- States represent UI state

### 3. Data Layer (`/models/`)
- Data: Freezed entity classes
- DTO: Data Transfer Objects for API requests
- Repos: Repository pattern for data access

## Dependency Flow

```
Views → BLoCs → Repositories → Data Sources (API/Local)
```

- Views depend on BLoCs
- BLoCs depend on Repositories (abstract)
- Repositories depend on data sources (Dio, SharedPreferences, etc.)
- Dependencies flow inward; inner layers don't know about outer layers

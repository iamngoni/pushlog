# Core Module

The `/core/` directory contains shared code used across all features.

## Structure

```
/core/
├── /configs/
│   ├── colors.dart          # App color palette
│   ├── constants.dart       # App constants
│   └── environment.dart     # Environment configuration
│
├── /services/
│   ├── storage.dart         # SharedPreferences wrapper
│   ├── secure_storage.dart  # Secure storage service
│   ├── notifications.dart   # Push notifications
│   ├── network.dart         # Network connectivity
│   ├── package.dart         # Package info
│   └── toasts.dart          # Toast notifications
│
├── /state/
│   └── /bloc_name/          # Global BLoCs (locale, connectivity, etc.)
│
├── /models/
│   ├── /data/
│   │   └── application_error.dart
│   ├── /dto/
│   └── /repos/
│
├── /utils/
│   ├── extensions.dart      # BuildContext extensions
│   ├── utils.dart           # Helper functions
│   ├── dio_error_to_application_error.dart
│   ├── dio_request_interceptor.dart
│   └── dio_on_error_interceptor.dart
│
└── /views/
    └── /widgets/            # Shared UI components
```

## Configs

### Colors
Define app color palette:

```dart
abstract class AppColors {
  static const Color primary = Color(0xFF...);
  static const Color secondary = Color(0xFF...);
  static const Color error = Color(0xFF...);
  // ...
}
```

### Environment
Environment-specific configuration:

```dart
enum Environment { development, staging, production }

abstract class EnvironmentConfig {
  static const Environment current = Environment.development;
  
  static String get baseUrl {
    switch (current) {
      case Environment.development:
        return 'https://dev-api.example.com';
      case Environment.staging:
        return 'https://staging-api.example.com';
      case Environment.production:
        return 'https://api.example.com';
    }
  }
}
```

## Services

### Storage Service
Wrapper around SharedPreferences:

```dart
@lazySingleton
class StorageService {
  StorageService(this._prefs);
  final SharedPreferences _prefs;

  Future<bool> saveString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);
  Future<bool> remove(String key) => _prefs.remove(key);
}
```

### Secure Storage Service
For sensitive data (tokens, credentials):

```dart
@lazySingleton
class SecureStorageService {
  SecureStorageService(this._storage);
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(key: 'token', value: token);
  Future<String?> getToken() => _storage.read(key: 'token');
  Future<void> deleteToken() => _storage.delete(key: 'token');
}
```

## Utils

### Extensions
BuildContext extensions for navigation and notifications:

```dart
extension ContextExtensions on BuildContext {
  Future<T?> goTo<T>({required Widget page}) =>
      Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));

  Future<T?> goToAndReplace<T>({required Widget page}) =>
      Navigator.of(this).pushReplacement(MaterialPageRoute(builder: (_) => page));

  Future<T?> goToAndRemoveUntil<T>({required Widget page}) =>
      Navigator.of(this).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => page),
        (_) => false,
      );

  void goBack<T>([T? result]) => Navigator.of(this).pop(result);

  void notify(String message, {bool isError = false}) =>
      isError
          ? ToastsService.showError(message, this)
          : ToastsService.showSuccess(message, this);
}
```

### Error Mapping
Map Dio errors to ApplicationError:

```dart
ApplicationError dioErrorToApplicationError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return const ApplicationError(
        message: 'Connection timed out',
        title: 'Network Error',
      );
    case DioExceptionType.badResponse:
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return ApplicationError(
          message: data['message'] ?? 'An error occurred',
          title: data['title'] ?? 'Error',
        );
      }
      return const ApplicationError.unknownError();
    default:
      return const ApplicationError.unknownError();
  }
}
```

## Shared Widgets

Reusable UI components with consistent styling:

- `AppButton` - Primary button
- `AppOutlineButton` - Outline button variant
- `AppTextField` - Text input field
- `AppSensitiveTextField` - Password input
- `AppPhoneTextField` - Phone number input
- `AppOTPTextField` - OTP input
- `AppDatePicker` - Date picker
- `AppTimePicker` - Time picker
- `LoaderWidget` - Loading spinner
- `DeviceOfflinePage` - Offline state UI

All widgets use `relative_scale` for responsive design:

```dart
RelativeBuilder(
  builder: (context, height, width, sy, sx) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sx(20),
        vertical: sy(10),
      ),
      child: Text(
        'Hello',
        style: TextStyle(fontSize: sy(16)),
      ),
    );
  },
)
```

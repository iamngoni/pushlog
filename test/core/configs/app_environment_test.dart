import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/app_environment.dart';

void main() {
  test('every flavor uses the canonical API dataset', () {
    for (final environment in AppEnvironment.values) {
      expect(apiBaseUrlFor(environment), primaryApiBaseUrl);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/app_environment.dart';

void main() {
  test('production uses the isolated production API', () {
    expect(
      apiBaseUrlFor(AppEnvironment.production),
      productionApiBaseUrl,
    );
  });

  test('development and staging use the staging API', () {
    expect(apiBaseUrlFor(AppEnvironment.development), stagingApiBaseUrl);
    expect(apiBaseUrlFor(AppEnvironment.staging), stagingApiBaseUrl);
  });
}

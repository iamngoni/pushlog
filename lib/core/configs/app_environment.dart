enum AppEnvironment {
  development,
  staging,
  production,
}

const stagingApiBaseUrl = 'https://pushlog-api-staging.imngonii.workers.dev';
const productionApiBaseUrl = 'https://pushlog-api.imngonii.workers.dev';

String apiBaseUrlFor(AppEnvironment environment) {
  const override = String.fromEnvironment('PUSHLOG_API_URL');
  if (override.isNotEmpty) return override;

  return switch (environment) {
    AppEnvironment.development || AppEnvironment.staging => stagingApiBaseUrl,
    AppEnvironment.production => productionApiBaseUrl,
  };
}

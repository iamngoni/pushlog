enum AppEnvironment {
  development,
  staging,
  production,
}

// The staging-named Worker contains Pushlog's canonical user and workout data.
// Keep every app flavor on this backend until a deliberate data migration is
// completed; changing flavors must never silently switch a user's dataset.
const primaryApiBaseUrl = 'https://pushlog-api-staging.imngonii.workers.dev';

String apiBaseUrlFor(AppEnvironment _) {
  const override = String.fromEnvironment('PUSHLOG_API_URL');
  if (override.isNotEmpty) return override;

  return primaryApiBaseUrl;
}

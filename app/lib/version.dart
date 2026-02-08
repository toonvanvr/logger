/// Build-time version constants injected via --dart-define.
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0-alpha.1',
);
const commitSha = String.fromEnvironment('COMMIT_SHA', defaultValue: '');

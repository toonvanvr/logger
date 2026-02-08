/// Build-time version constants injected via --dart-define.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');
const commitSha = String.fromEnvironment('COMMIT_SHA', defaultValue: '');

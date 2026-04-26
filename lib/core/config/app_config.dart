class AppConfig {
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8070/api/v1',
  );

  static const String wsBase = String.fromEnvironment(
    'WS_BASE',
    defaultValue: 'ws://localhost:8072',
  );

  static const String uploadBase = String.fromEnvironment(
    'UPLOAD_BASE',
    defaultValue: 'http://localhost:8070',
  );
}

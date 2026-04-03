class AppConfig {
  // TODO: サーバのURLに合わせて変更
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
}

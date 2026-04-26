import 'app_config.dart';

@Deprecated('Use AppConfig instead.')
class EnvConfig {
  const EnvConfig._();

  static String get apiBaseUrl => AppConfig.apiBaseUrl;
}

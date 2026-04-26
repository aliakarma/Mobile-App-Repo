import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:8001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8001';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8001';
    }
  }
}

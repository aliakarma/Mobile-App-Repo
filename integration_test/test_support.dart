import 'package:flutter/material.dart';

import 'package:smart_application_intelligence_system/core/di/service_locator.dart';
import 'package:smart_application_intelligence_system/domain/repositories/applications_repository.dart';
import 'package:smart_application_intelligence_system/services/auth_controller.dart';
import 'package:smart_application_intelligence_system/main.dart';

Widget buildTestApp({
  required AuthController authController,
  required ApplicationsRepository applicationsRepository,
}) {
  return SmartApplicationIntelligenceSystemApp(
    authController: authController,
    applicationsRepository: applicationsRepository,
  );
}


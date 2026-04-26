import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/sop_analysis_model.dart';
import 'api_exceptions.dart';

class SopService {
  SopService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<SopAnalysisModel> analyzeSop(String sopText) async {
    debugPrint('[SOP] POST /analyze-sop');

    try {
      final payload = await _apiClient.postJson(
        '/analyze-sop',
        body: {'text': sopText},
      );

      debugPrint('[SOP] Success');
      return SopAnalysisModel.fromJson(payload);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const BackendException(
        userMessage: 'The server returned an invalid response format.',
      );
    }
  }
}

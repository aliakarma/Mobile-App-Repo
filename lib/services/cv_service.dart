import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/cv_analysis_model.dart';
import 'api_exceptions.dart';

class CvService {
  static const Duration _analysisTimeout = Duration(seconds: 90);

  CvService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<CvAnalysisModel> analyzeCv({
    required String cvText,
    required String targetOpportunity,
    String? cvPdfBase64,
    String? cvPdfFilename,
  }) async {
    debugPrint('[CV] POST /analyze-cv');

    try {
      final payload = await _apiClient.postJson(
        '/analyze-cv',
        body: {
          'cv_text': cvText,
          'cv_pdf_base64': cvPdfBase64,
          'cv_pdf_filename': cvPdfFilename,
          'target_opportunity': targetOpportunity,
        },
        timeoutOverride: _analysisTimeout,
      );

      debugPrint('[CV] Success');
      return CvAnalysisModel.fromJson(payload);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const BackendException(
        userMessage: 'The server returned an invalid response format.',
      );
    }
  }
}

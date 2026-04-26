import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cv_analysis_model.dart';

class CvService {
  CvService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;

  static String get defaultBaseUrl {
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

  Future<CvAnalysisModel> analyzeCv({
    required String cvText,
    required String targetOpportunity,
    String? cvPdfBase64,
    String? cvPdfFilename,
  }) async {
    final uri = Uri.parse('$baseUrl/analyze-cv');
    debugPrint('[CV] POST /analyze-cv');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cv_text': cvText,
        'cv_pdf_base64': cvPdfBase64,
        'cv_pdf_filename': cvPdfFilename,
        'target_opportunity': targetOpportunity,
      }),
    );

    debugPrint('[CV] Response status: ${response.statusCode}');

    final decodedBody = _decodeBody(response.body);

    if (response.statusCode != 200) {
      final errorDetail = decodedBody['detail']?.toString() ??
          response.reasonPhrase ??
          'Unknown backend error';
      debugPrint('[CV] Failed: $errorDetail');
      throw Exception('CV analysis failed: $errorDetail');
    }

    debugPrint('[CV] Success');
    return CvAnalysisModel.fromJson(decodedBody);
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format from backend.');
    }
    return decoded;
  }
}

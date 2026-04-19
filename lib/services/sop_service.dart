import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sop_analysis_model.dart';

class SopService {
  SopService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

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

  Future<SopAnalysisModel> analyzeSop(String sopText) async {
    final uri = Uri.parse('$baseUrl/analyze-sop');
    debugPrint('[SOP] POST /analyze-sop');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': sopText}),
    );

    debugPrint('[SOP] Response status: ${response.statusCode}');

    final decodedBody = _decodeBody(response.body);

    if (response.statusCode != 200) {
      final errorDetail = decodedBody['detail']?.toString() ??
          response.reasonPhrase ??
          'Unknown backend error';
      debugPrint('[SOP] Failed: $errorDetail');
      throw Exception('SOP analysis failed: $errorDetail');
    }

    debugPrint('[SOP] Success');
    return SopAnalysisModel.fromJson(decodedBody);
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format from backend.');
    }
    return decoded;
  }
}

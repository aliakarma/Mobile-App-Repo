import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sop_analysis_model.dart';

class SopService {
  const SopService({this.baseUrl = 'http://10.0.2.2:8000'});

  final String baseUrl;

  Future<SopAnalysisModel> analyzeSop(String sopText) async {
    final uri = Uri.parse('$baseUrl/analyze-sop');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': sopText}),
    );

    final decodedBody = _decodeBody(response.body);

    if (response.statusCode != 200) {
      final errorDetail = decodedBody['detail']?.toString() ??
          response.reasonPhrase ??
          'Unknown backend error';
      throw Exception('SOP analysis failed: $errorDetail');
    }

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

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/opportunity_model.dart';

class OpportunityService {
  const OpportunityService({this.baseUrl = 'http://10.0.2.2:8000'});

  // Android emulator can use 10.0.2.2 to reach localhost backend.
  // For physical devices, replace with your machine IP.
  final String baseUrl;

  Future<List<OpportunityModel>> fetchOpportunities() async {
    final uri = Uri.parse('$baseUrl/opportunities');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Backend returned ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception(
          'Invalid response format. Expected a list of opportunities.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OpportunityModel.fromJson)
        .toList();
  }
}

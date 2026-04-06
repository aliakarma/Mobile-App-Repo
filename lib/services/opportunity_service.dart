import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/opportunity_model.dart';

class OpportunitiesFetchResult {
  const OpportunitiesFetchResult({
    required this.opportunities,
    required this.fromCache,
  });

  final List<OpportunityModel> opportunities;
  final bool fromCache;
}

class OpportunityService {
  const OpportunityService({this.baseUrl = 'http://10.0.2.2:8000'});

  // Android emulator can use 10.0.2.2 to reach localhost backend.
  // For physical devices, replace with your machine IP.
  final String baseUrl;
  static const String _cacheKey = 'cached_opportunities';

  Future<OpportunitiesFetchResult> fetchOpportunities() async {
    final uri = Uri.parse('$baseUrl/opportunities');
    try {
      final response = await http.get(uri);
      debugPrint(
          '[OpportunityService] GET /opportunities -> ${response.statusCode}');

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

      final opportunities = decoded
          .whereType<Map<String, dynamic>>()
          .map(OpportunityModel.fromJson)
          .toList();

      await _saveCache(decoded);
      debugPrint(
          '[OpportunityService] Loaded opportunities from API: ${opportunities.length}');

      return OpportunitiesFetchResult(
        opportunities: opportunities,
        fromCache: false,
      );
    } catch (error) {
      debugPrint(
          '[OpportunityService] API failed, attempting cache fallback: $error');
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        debugPrint(
            '[OpportunityService] Loaded opportunities from cache: ${cached.length}');
        return OpportunitiesFetchResult(opportunities: cached, fromCache: true);
      }

      debugPrint('[OpportunityService] No cached opportunities available');
      rethrow;
    }
  }

  Future<void> _saveCache(List<dynamic> rawJsonList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rawJsonList));
  }

  Future<List<OpportunityModel>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null || cached.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(cached);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(OpportunityModel.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

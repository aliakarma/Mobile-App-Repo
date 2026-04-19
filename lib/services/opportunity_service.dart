import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/opportunity_model.dart';

class OpportunitiesFetchResult {
  const OpportunitiesFetchResult({
    required this.opportunities,
    required this.fromCache,
    required this.lastUpdated,
  });

  final List<OpportunityModel> opportunities;
  final bool fromCache;
  final DateTime? lastUpdated;
}

class OpportunityService {
  OpportunityService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  final String baseUrl;
  static const String _cacheKey = 'cached_opportunities';
  static const String _cacheUpdatedAtKey = 'cached_opportunities_updated_at';

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

  Future<OpportunitiesFetchResult> fetchOpportunities({
    bool forceRefresh = false,
  }) async {
    final uri = Uri.parse('$baseUrl/opportunities/live');
    try {
      final response = await http.get(uri);
      debugPrint(
          '[OpportunityService] GET /opportunities/live -> ${response.statusCode}');

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

      final updatedAt = DateTime.now();
      await _saveCache(decoded, updatedAt);
      debugPrint(
          '[OpportunityService] Loaded opportunities from API: ${opportunities.length}');

      return OpportunitiesFetchResult(
        opportunities: opportunities,
        fromCache: false,
        lastUpdated: updatedAt,
      );
    } catch (error) {
      if (forceRefresh) {
        debugPrint('[OpportunityService] Force refresh failed; cache ignored');
        rethrow;
      }

      debugPrint(
          '[OpportunityService] API failed, attempting cache fallback: $error');
      final cached = await _loadCacheWithMetadata();
      if (cached.isNotEmpty) {
        debugPrint(
            '[OpportunityService] Loaded opportunities from cache: ${cached.length}');
        return OpportunitiesFetchResult(
          opportunities: cached,
          fromCache: true,
          lastUpdated: await _loadCacheUpdatedAt(),
        );
      }

      debugPrint('[OpportunityService] No cached opportunities available');
      rethrow;
    }
  }

  Future<void> _saveCache(List<dynamic> rawJsonList, DateTime updatedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rawJsonList));
    await prefs.setString(_cacheUpdatedAtKey, updatedAt.toIso8601String());
  }

  Future<List<OpportunityModel>> _loadCacheWithMetadata() async {
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

  Future<DateTime?> _loadCacheUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheUpdatedAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}

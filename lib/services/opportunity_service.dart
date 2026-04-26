import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/opportunity_model.dart';
import 'api_exceptions.dart';

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
  OpportunityService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;
  static const String _cacheKey = 'cached_opportunities';
  static const String _cacheUpdatedAtKey = 'cached_opportunities_updated_at';

  Future<OpportunitiesFetchResult> fetchOpportunities({
    bool forceRefresh = false,
  }) async {
    try {
      final decoded = await _apiClient.getJsonMap('/opportunities/live');
      final rawOpportunities = decoded['opportunities'];
      final updatedAtRaw = decoded['updated_at'];

      final opportunities = (rawOpportunities is List ? rawOpportunities : const [])
          .whereType<Map<String, dynamic>>()
          .map(OpportunityModel.fromJson)
          .toList();

      final updatedAt = DateTime.tryParse(updatedAtRaw?.toString() ?? '') ??
          DateTime.now();
      await _saveCache(
        rawOpportunities is List ? rawOpportunities : const [],
        updatedAt,
      );
      debugPrint(
          '[OpportunityService] Loaded opportunities from API: ${opportunities.length}');

      return OpportunitiesFetchResult(
        opportunities: opportunities,
        fromCache: false,
        lastUpdated: updatedAt,
      );
    } on ApiException {
      if (forceRefresh) {
        debugPrint('[OpportunityService] Force refresh failed; cache ignored');
        rethrow;
      }

      final cached = await _loadCacheWithMetadata();
      if (cached.isNotEmpty) {
        debugPrint(
          '[OpportunityService] API failed, using cache fallback: ${cached.length}',
        );
        return OpportunitiesFetchResult(
          opportunities: cached,
          fromCache: true,
          lastUpdated: await _loadCacheUpdatedAt(),
        );
      }

      rethrow;
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

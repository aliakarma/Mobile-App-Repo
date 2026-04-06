import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile_model.dart';

class UserProfileService {
  UserProfileService._();

  static const String _profileKey = 'user_profile';
  static final UserProfileService instance = UserProfileService._();

  Future<void> saveProfile(UserProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<UserProfileModel> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);

    if (raw == null || raw.isEmpty) {
      return const UserProfileModel(
        gpa: 3.0,
        fieldOfStudy: 'General',
        researchExperienceLevel: 'none',
        publications: 0,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return UserProfileModel.fromJson(decoded);
      }
    } catch (_) {
      // Fall back to defaults when local data is corrupted.
    }

    return const UserProfileModel(
      gpa: 3.0,
      fieldOfStudy: 'General',
      researchExperienceLevel: 'none',
      publications: 0,
    );
  }
}

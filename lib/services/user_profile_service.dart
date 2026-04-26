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

  UserProfileModel _normalizeScale(UserProfileModel profile) {
    if (profile.gpaScale == 4 || profile.gpaScale == 5) {
      final clampedGpa = profile.gpa.clamp(0.0, profile.gpaScale.toDouble());
      if (clampedGpa == profile.gpa) {
        return profile;
      }

      return UserProfileModel(
        gpa: clampedGpa,
        gpaScale: profile.gpaScale,
        fieldOfStudy: profile.fieldOfStudy,
        researchExperienceLevel: profile.researchExperienceLevel,
        publications: profile.publications,
      );
    }

    final migratedGpa = profile.gpaScale > 0
        ? (profile.gpa / profile.gpaScale) * 5.0
        : profile.gpa;

    return UserProfileModel(
      gpa: migratedGpa.clamp(0.0, 5.0),
      gpaScale: 5,
      fieldOfStudy: profile.fieldOfStudy,
      researchExperienceLevel: profile.researchExperienceLevel,
      publications: profile.publications,
    );
  }

  Future<UserProfileModel> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);

    if (raw == null || raw.isEmpty) {
      return const UserProfileModel(
        gpa: 3.0,
        gpaScale: 4,
        fieldOfStudy: 'General',
        researchExperienceLevel: 'none',
        publications: 0,
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final profile = UserProfileModel.fromJson(decoded);
        final normalizedProfile = _normalizeScale(profile);

        if (!identical(profile, normalizedProfile)) {
          await saveProfile(normalizedProfile);
        }

        return normalizedProfile;
      }
    } catch (_) {
      // Fall back to defaults when local data is corrupted.
    }

    return const UserProfileModel(
      gpa: 3.0,
      gpaScale: 4,
      fieldOfStudy: 'General',
      researchExperienceLevel: 'none',
      publications: 0,
    );
  }
}

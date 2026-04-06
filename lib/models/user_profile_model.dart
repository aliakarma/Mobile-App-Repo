class UserProfileModel {
  const UserProfileModel({
    required this.gpa,
    required this.fieldOfStudy,
    required this.researchExperienceLevel,
    required this.publications,
  });

  final double gpa;
  final String fieldOfStudy;
  final String researchExperienceLevel;
  final int publications;

  Map<String, dynamic> toJson() {
    return {
      'gpa': gpa,
      'fieldOfStudy': fieldOfStudy,
      'researchExperienceLevel': researchExperienceLevel,
      'publications': publications,
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      gpa: (json['gpa'] as num?)?.toDouble() ?? 0.0,
      fieldOfStudy: json['fieldOfStudy'] as String? ?? 'General',
      researchExperienceLevel:
          json['researchExperienceLevel'] as String? ?? 'none',
      publications: (json['publications'] as num?)?.toInt() ?? 0,
    );
  }
}

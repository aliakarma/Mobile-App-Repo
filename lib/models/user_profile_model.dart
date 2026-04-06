class UserProfileModel {
  const UserProfileModel({
    required this.gpa,
    required this.gpaScale,
    required this.fieldOfStudy,
    required this.researchExperienceLevel,
    required this.publications,
  });

  final double gpa;
  final int gpaScale;
  final String fieldOfStudy;
  final String researchExperienceLevel;
  final int publications;

  Map<String, dynamic> toJson() {
    return {
      'gpa': gpa,
      'gpaScale': gpaScale,
      'fieldOfStudy': fieldOfStudy,
      'researchExperienceLevel': researchExperienceLevel,
      'publications': publications,
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      gpa: (json['gpa'] as num?)?.toDouble() ?? 0.0,
      gpaScale: (json['gpaScale'] as num?)?.toInt() ?? 4,
      fieldOfStudy: json['fieldOfStudy'] as String? ?? 'General',
      researchExperienceLevel:
          json['researchExperienceLevel'] as String? ?? 'none',
      publications: (json['publications'] as num?)?.toInt() ?? 0,
    );
  }
}

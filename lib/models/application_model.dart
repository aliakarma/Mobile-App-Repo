class ApplicationModel {
  const ApplicationModel({
    this.id,
    required this.title,
    required this.deadline,
    required this.status,
    required this.fitScore,
    required this.riskLevel,
  });

  final int? id;
  final String title;
  final DateTime deadline;
  final String status;
  final double fitScore;
  final String riskLevel;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline.toIso8601String(),
      'status': status,
      'fit_score': fitScore,
      'risk_level': riskLevel,
    };
  }

  factory ApplicationModel.fromMap(Map<String, Object?> map) {
    return ApplicationModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      deadline: DateTime.parse(map['deadline'] as String),
      status: map['status'] as String,
      fitScore: (map['fit_score'] as num).toDouble(),
      riskLevel: map['risk_level'] as String,
    );
  }
}

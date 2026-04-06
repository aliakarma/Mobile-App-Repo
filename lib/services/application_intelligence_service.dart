enum RiskLevel { low, medium, high }

class ApplicationIntelligenceService {
  const ApplicationIntelligenceService._();

  static double calculateFitScore({
    required double gpa,
    required String field,
    required bool researchExperience,
    required int publications,
  }) {
    final gpaScore = _clamp((gpa / 4.0) * 60.0, 0, 60);
    final fieldScore = _fieldScore(field);
    final researchScore = researchExperience ? 15.0 : 0.0;
    final publicationScore = _clamp(publications * 4.0, 0, 13);

    final total = gpaScore + fieldScore + researchScore + publicationScore;
    return _clamp(total, 0, 100);
  }

  static double calculateReadinessScore({
    required bool documentsComplete,
    required bool sopReady,
    required double checklistProgress,
  }) {
    final documentsScore = documentsComplete ? 40.0 : 0.0;
    final sopScore = sopReady ? 30.0 : 0.0;
    final checklistScore = _clamp(checklistProgress, 0, 100) * 0.30;

    final total = documentsScore + sopScore + checklistScore;
    return _clamp(total, 0, 100);
  }

  static RiskLevel calculateRiskLevel({
    required int daysUntilDeadline,
    required double readinessScore,
  }) {
    final urgencyScore = _deadlineUrgencyScore(daysUntilDeadline);
    final preparednessGap = 100 - _clamp(readinessScore, 0, 100);

    final riskScore = (urgencyScore * 0.65) + (preparednessGap * 0.35);

    if (riskScore >= 70) {
      return RiskLevel.high;
    }
    if (riskScore >= 40) {
      return RiskLevel.medium;
    }
    return RiskLevel.low;
  }

  static double _fieldScore(String field) {
    final normalizedField = field.trim().toLowerCase();

    if (normalizedField.contains('stem') ||
        normalizedField.contains('engineering') ||
        normalizedField.contains('computer')) {
      return 12.0;
    }

    if (normalizedField.contains('health') ||
        normalizedField.contains('medical')) {
      return 10.0;
    }

    if (normalizedField.contains('business') ||
        normalizedField.contains('economics')) {
      return 8.0;
    }

    if (normalizedField.contains('humanities') ||
        normalizedField.contains('arts')) {
      return 6.0;
    }

    return 5.0;
  }

  static double _deadlineUrgencyScore(int daysUntilDeadline) {
    if (daysUntilDeadline <= 3) {
      return 90.0;
    }
    if (daysUntilDeadline <= 7) {
      return 75.0;
    }
    if (daysUntilDeadline <= 14) {
      return 55.0;
    }
    if (daysUntilDeadline <= 30) {
      return 35.0;
    }
    return 15.0;
  }

  static double _clamp(num value, num min, num max) {
    if (value < min) {
      return min.toDouble();
    }
    if (value > max) {
      return max.toDouble();
    }
    return value.toDouble();
  }
}

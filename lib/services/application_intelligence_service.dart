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

  static String getRecommendation({
    required double fitScore,
    required double readinessScore,
    required int daysToDeadline,
  }) {
    final clampedFit = _clamp(fitScore, 0, 100);
    final clampedReadiness = _clamp(readinessScore, 0, 100);
    final urgencyScore = _deadlineUrgencyScore(daysToDeadline);

    // Combined readiness to submit now: profile fit + current preparation.
    final confidenceScore = (clampedFit * 0.55) + (clampedReadiness * 0.45);

    final isVeryUrgent = urgencyScore >= 75;
    final isSoon = urgencyScore >= 55;

    if (confidenceScore >= 75 && clampedReadiness >= 60) {
      return 'Apply';
    }

    // Urgent deadlines with low preparation are high-risk submissions.
    if (isVeryUrgent && clampedReadiness < 45) {
      return 'Skip';
    }

    if (isSoon && confidenceScore >= 65) {
      return 'Apply';
    }

    if (confidenceScore < 45) {
      return 'Skip';
    }

    return 'Prepare More';
  }

  static String getRecommendationReason({
    required double fitScore,
    required double readinessScore,
    required int daysToDeadline,
  }) {
    if (fitScore >= 75 && readinessScore >= 60) {
      return 'Reason: High fit and sufficient readiness.';
    }

    if (daysToDeadline <= 7 && readinessScore < 45) {
      return 'Reason: Deadline is very close and readiness is low.';
    }

    if (fitScore < 45) {
      return 'Reason: Fit is currently too low for this application.';
    }

    if (readinessScore < 60) {
      return 'Reason: Profile is promising but preparation needs improvement.';
    }

    return 'Reason: Moderate fit and timing, improve key sections before applying.';
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

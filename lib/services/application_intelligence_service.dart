enum RiskLevel { low, medium, high }

class ApplicationIntelligenceService {
  const ApplicationIntelligenceService._();

  // -------------------------------------------------------------------------
  // Scoring weight constants — exposed so the UI can display accurate values.
  // These must match the actual calculation below exactly.
  // -------------------------------------------------------------------------
  static const double gpaMaxScore = 60.0; // GPA contributes up to 60 pts
  static const double fieldMaxScore = 12.0; // Field alignment up to 12 pts
  static const double researchScore = 15.0; // Binary: research exp = 15 pts
  static const double publicationMaxScore =
      13.0; // Pubs contribute up to 13 pts

  // Human-readable weight percentages (sum to 100)
  static int get gpaWeightPercent => (gpaMaxScore / 100 * 100).round(); // 60%
  static int get researchWeightPercent =>
      (researchScore / 100 * 100).round(); // 15%
  static int get publicationWeightPercent =>
      (publicationMaxScore / 100 * 100).round(); // 13%
  static int get fieldWeightPercent =>
      (fieldMaxScore / 100 * 100).round(); // 12%

  // -------------------------------------------------------------------------
  // Fit score: 0–100
  // -------------------------------------------------------------------------
  static double calculateFitScore({
    required double gpa,
    required String field,
    required bool researchExperience,
    required int publications,
  }) {
    // GPA: normalised to 4.0 scale before calling this method
    final gpaPoints = _clamp((gpa / 4.0) * gpaMaxScore, 0, gpaMaxScore);
    final fieldPoints = _fieldScore(field);
    final researchPoints = researchExperience ? researchScore : 0.0;
    final publicationPoints =
        _clamp(publications * 4.0, 0, publicationMaxScore);

    final total = gpaPoints + fieldPoints + researchPoints + publicationPoints;
    return _clamp(total, 0, 100);
  }

  // -------------------------------------------------------------------------
  // Readiness score: 0–100
  // -------------------------------------------------------------------------
  static double calculateReadinessScore({
    required bool documentsComplete,
    required bool sopReady,
    required double checklistProgress,
  }) {
    final documentsPoints = documentsComplete ? 40.0 : 0.0;
    final sopPoints = sopReady ? 30.0 : 0.0;
    final checklistPoints = _clamp(checklistProgress, 0, 100) * 0.30;

    final total = documentsPoints + sopPoints + checklistPoints;
    return _clamp(total, 0, 100);
  }

  // -------------------------------------------------------------------------
  // Risk level
  // -------------------------------------------------------------------------
  static RiskLevel calculateRiskLevel({
    required int daysUntilDeadline,
    required double readinessScore,
  }) {
    final urgencyScore = _deadlineUrgencyScore(daysUntilDeadline);
    final preparednessGap = 100 - _clamp(readinessScore, 0, 100);

    final riskScore = (urgencyScore * 0.65) + (preparednessGap * 0.35);

    if (riskScore >= 70) return RiskLevel.high;
    if (riskScore >= 40) return RiskLevel.medium;
    return RiskLevel.low;
  }

  // -------------------------------------------------------------------------
  // Recommendation
  // -------------------------------------------------------------------------
  static String getRecommendation({
    required double fitScore,
    required double readinessScore,
    required int daysToDeadline,
  }) {
    final clampedFit = _clamp(fitScore, 0, 100);
    final clampedReadiness = _clamp(readinessScore, 0, 100);
    final urgencyScore = _deadlineUrgencyScore(daysToDeadline);

    final confidenceScore = (clampedFit * 0.55) + (clampedReadiness * 0.45);

    final isVeryUrgent = urgencyScore >= 75;
    final isSoon = urgencyScore >= 55;

    if (clampedFit < 45) return 'Skip';
    if (confidenceScore >= 75 && clampedReadiness >= 60) return 'Apply';
    if (isVeryUrgent && clampedReadiness < 45) return 'Skip';
    if (isSoon && confidenceScore >= 65) return 'Apply';
    if (confidenceScore < 45) return 'Skip';
    return 'Prepare More';
  }

  // -------------------------------------------------------------------------
  // Recommendation reason
  // -------------------------------------------------------------------------
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
    return 'Reason: Moderate fit and timing — improve key sections before applying.';
  }

  // -------------------------------------------------------------------------
  // Fit breakdown text (UI helper) — always derived from actual constants
  // -------------------------------------------------------------------------
  static String fitBreakdownText() {
    return 'GPA: $gpaWeightPercent% | '
        'Research: $researchWeightPercent% | '
        'Publications: $publicationWeightPercent% | '
        'Field: $fieldWeightPercent%';
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static double _fieldScore(String field) {
    final normalised = field.trim().toLowerCase();

    if (normalised.contains('stem') ||
        normalised.contains('engineering') ||
        normalised.contains('computer') ||
        normalised.contains('artificial intelligence') ||
        normalised.contains('machine learning') ||
        normalised.contains('data science')) {
      return fieldMaxScore; // 12
    }
    if (normalised.contains('health') || normalised.contains('medical')) {
      return 10.0;
    }
    if (normalised.contains('business') ||
        normalised.contains('economics') ||
        normalised.contains('finance')) {
      return 8.0;
    }
    if (normalised.contains('humanities') || normalised.contains('arts')) {
      return 6.0;
    }
    return 5.0;
  }

  static double _deadlineUrgencyScore(int daysUntilDeadline) {
    if (daysUntilDeadline <= 0) return 95.0; // Past deadline = maximum urgency
    if (daysUntilDeadline <= 3) return 90.0;
    if (daysUntilDeadline <= 7) return 75.0;
    if (daysUntilDeadline <= 14) return 55.0;
    if (daysUntilDeadline <= 30) return 35.0;
    return 15.0;
  }

  static double _clamp(num value, num min, num max) {
    if (value < min) return min.toDouble();
    if (value > max) return max.toDouble();
    return value.toDouble();
  }
}

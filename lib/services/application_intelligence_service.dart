enum RiskLevel { low, medium, high }

class RecommendationResult {
  const RecommendationResult({
    required this.label,
    required this.reason,
  });

  final String label;
  final String reason;
}

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
  static RecommendationResult getRecommendationResult({
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

    if (clampedFit < 45) {
      return const RecommendationResult(
        label: 'Skip',
        reason: 'Reason: Fit is currently too low for this application.',
      );
    }

    if (confidenceScore >= 75 && clampedReadiness >= 60) {
      return const RecommendationResult(
        label: 'Apply',
        reason: 'Reason: High fit and sufficient readiness.',
      );
    }

    if (isVeryUrgent && clampedReadiness < 45) {
      return const RecommendationResult(
        label: 'Skip',
        reason: 'Reason: Deadline is very close and readiness is low.',
      );
    }

    if (isSoon && confidenceScore >= 65) {
      return const RecommendationResult(
        label: 'Apply',
        reason: 'Reason: Strong confidence with a near-term deadline.',
      );
    }

    if (confidenceScore < 45) {
      return const RecommendationResult(
        label: 'Skip',
        reason: 'Reason: Readiness and confidence are not strong enough yet.',
      );
    }

    return const RecommendationResult(
      label: 'Prepare More',
      reason:
          'Reason: Moderate fit and timing — improve key sections before applying.',
    );
  }

  static String getRecommendation({
    required double fitScore,
    required double readinessScore,
    required int daysToDeadline,
  }) {
    return getRecommendationResult(
      fitScore: fitScore,
      readinessScore: readinessScore,
      daysToDeadline: daysToDeadline,
    ).label;
  }

  static String getRecommendationReason({
    required double fitScore,
    required double readinessScore,
    required int daysToDeadline,
  }) {
    return getRecommendationResult(
      fitScore: fitScore,
      readinessScore: readinessScore,
      daysToDeadline: daysToDeadline,
    ).reason;
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

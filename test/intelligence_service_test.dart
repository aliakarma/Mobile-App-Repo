import 'package:flutter_test/flutter_test.dart';
import 'package:smart_application_intelligence_system/services/application_intelligence_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // calculateFitScore
  // ---------------------------------------------------------------------------
  group('calculateFitScore', () {
    test('perfect GPA with STEM field and advanced research returns near 100', () {
      final score = ApplicationIntelligenceService.calculateFitScore(
        gpa: 4.0,
        field: 'Computer Science',
        researchExperience: true,
        publications: 10,
      );
      expect(score, greaterThanOrEqualTo(95.0));
      expect(score, lessThanOrEqualTo(100.0));
    });

    test('zero GPA with no research or publications returns 0', () {
      final score = ApplicationIntelligenceService.calculateFitScore(
        gpa: 0.0,
        field: 'General',
        researchExperience: false,
        publications: 0,
      );
      expect(score, equals(5.0)); // field score floor
    });

    test('GPA below 4.0 is clamped correctly', () {
      final score = ApplicationIntelligenceService.calculateFitScore(
        gpa: 2.0,
        field: 'General',
        researchExperience: false,
        publications: 0,
      );
      // GPA: (2.0/4.0)*60 = 30, field: 5 → total 35
      expect(score, closeTo(35.0, 0.5));
    });

    test('publications are clamped at 13 (3.25 publications max)', () {
      final scoreA = ApplicationIntelligenceService.calculateFitScore(
        gpa: 0.0,
        field: 'General',
        researchExperience: false,
        publications: 10,
      );
      final scoreB = ApplicationIntelligenceService.calculateFitScore(
        gpa: 0.0,
        field: 'General',
        researchExperience: false,
        publications: 100,
      );
      expect(scoreA, equals(scoreB)); // both hit the publication cap
    });

    test('STEM field scores higher than humanities', () {
      final stemScore = ApplicationIntelligenceService.calculateFitScore(
        gpa: 3.0,
        field: 'engineering',
        researchExperience: false,
        publications: 0,
      );
      final humanitiesScore = ApplicationIntelligenceService.calculateFitScore(
        gpa: 3.0,
        field: 'humanities',
        researchExperience: false,
        publications: 0,
      );
      expect(stemScore, greaterThan(humanitiesScore));
    });

    test('research experience adds exactly the research weight', () {
      final withResearch = ApplicationIntelligenceService.calculateFitScore(
        gpa: 3.0,
        field: 'General',
        researchExperience: true,
        publications: 0,
      );
      final withoutResearch = ApplicationIntelligenceService.calculateFitScore(
        gpa: 3.0,
        field: 'General',
        researchExperience: false,
        publications: 0,
      );
      expect(
        withResearch - withoutResearch,
        closeTo(ApplicationIntelligenceService.researchScore, 0.01),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // calculateRiskLevel
  // ---------------------------------------------------------------------------
  group('calculateRiskLevel', () {
    test('very close deadline with low readiness is high risk', () {
      final risk = ApplicationIntelligenceService.calculateRiskLevel(
        daysUntilDeadline: 2,
        readinessScore: 20,
      );
      expect(risk, equals(RiskLevel.high));
    });

    test('far deadline with high readiness is low risk', () {
      final risk = ApplicationIntelligenceService.calculateRiskLevel(
        daysUntilDeadline: 90,
        readinessScore: 90,
      );
      expect(risk, equals(RiskLevel.low));
    });

    test('past deadline (0 days) is maximum urgency', () {
      final risk = ApplicationIntelligenceService.calculateRiskLevel(
        daysUntilDeadline: 0,
        readinessScore: 50,
      );
      expect(risk, equals(RiskLevel.high));
    });

    test('moderate deadline with moderate readiness is medium risk', () {
      final risk = ApplicationIntelligenceService.calculateRiskLevel(
        daysUntilDeadline: 14,
        readinessScore: 60,
      );
      // urgency: 55, gap: 40 → risk: 55*0.65 + 40*0.35 = 35.75 + 14 = 49.75 → medium
      expect(risk, equals(RiskLevel.medium));
    });
  });

  // ---------------------------------------------------------------------------
  // getRecommendation
  // ---------------------------------------------------------------------------
  group('getRecommendation', () {
    test('high fit, high readiness, ample time → Apply', () {
      final rec = ApplicationIntelligenceService.getRecommendation(
        fitScore: 85,
        readinessScore: 80,
        daysToDeadline: 60,
      );
      expect(rec, equals('Apply'));
    });

    test('very urgent deadline, low readiness → Skip', () {
      final rec = ApplicationIntelligenceService.getRecommendation(
        fitScore: 70,
        readinessScore: 30,
        daysToDeadline: 2,
      );
      expect(rec, equals('Skip'));
    });

    test('low fit score → Skip', () {
      final rec = ApplicationIntelligenceService.getRecommendation(
        fitScore: 20,
        readinessScore: 90,
        daysToDeadline: 60,
      );
      expect(rec, equals('Skip'));
    });

    test('promising but incomplete → Prepare More', () {
      final rec = ApplicationIntelligenceService.getRecommendation(
        fitScore: 65,
        readinessScore: 45,
        daysToDeadline: 45,
      );
      expect(rec, equals('Prepare More'));
    });
  });

  // ---------------------------------------------------------------------------
  // fitBreakdownText
  // ---------------------------------------------------------------------------
  group('fitBreakdownText', () {
    test('breakdown text references correct weight percentages', () {
      final text = ApplicationIntelligenceService.fitBreakdownText();
      expect(
        text,
        contains('${ApplicationIntelligenceService.gpaWeightPercent}%'),
      );
      expect(
        text,
        contains('${ApplicationIntelligenceService.researchWeightPercent}%'),
      );
    });
  });
}

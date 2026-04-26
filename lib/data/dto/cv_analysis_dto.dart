import '../../domain/models/cv_analysis.dart';

class CvAnalysisDto {
  const CvAnalysisDto({
    required this.overallFitScore,
    required this.strengths,
    required this.gaps,
    required this.tailoringSuggestions,
    required this.missingKeywords,
    required this.recommendedSections,
  });

  final int overallFitScore;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> tailoringSuggestions;
  final List<String> missingKeywords;
  final List<String> recommendedSections;

  factory CvAnalysisDto.fromJson(Map<String, dynamic> json) {
    return CvAnalysisDto(
      overallFitScore: (json['overall_fit_score'] as num?)?.toInt() ?? 0,
      strengths: _toStringList(json['strengths']),
      gaps: _toStringList(json['gaps']),
      tailoringSuggestions: _toStringList(json['tailoring_suggestions']),
      missingKeywords: _toStringList(json['missing_keywords']),
      recommendedSections: _toStringList(json['recommended_sections']),
    );
  }

  CvAnalysis toDomain() {
    return CvAnalysis(
      overallFitScore: overallFitScore,
      strengths: strengths,
      gaps: gaps,
      tailoringSuggestions: tailoringSuggestions,
      missingKeywords: missingKeywords,
      recommendedSections: recommendedSections,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }
}

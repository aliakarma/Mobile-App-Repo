class CvAnalysis {
  const CvAnalysis({
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
}

class SopAnalysisModel {
  const SopAnalysisModel({
    required this.score,
    required this.strengths,
    required this.weaknesses,
    required this.suggestions,
  });

  final int score;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> suggestions;

  factory SopAnalysisModel.fromJson(Map<String, dynamic> json) {
    return SopAnalysisModel(
      score: (json['score'] as num?)?.toInt() ?? 0,
      strengths: _toStringList(json['strengths']),
      weaknesses: _toStringList(json['weaknesses']),
      suggestions: _toStringList(json['suggestions']),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }
}

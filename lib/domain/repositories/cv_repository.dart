import '../models/cv_analysis.dart';

abstract class CvRepository {
  Future<CvAnalysis> analyzeCv({
    required String cvText,
    required String targetOpportunity,
    String? cvPdfBase64,
    String? cvPdfFilename,
  });
}

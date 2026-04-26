import '../models/cv_analysis.dart';
import '../repositories/cv_repository.dart';

class AnalyzeCvParams {
  const AnalyzeCvParams({
    required this.cvText,
    required this.targetOpportunity,
    this.cvPdfBase64,
    this.cvPdfFilename,
  });

  final String cvText;
  final String targetOpportunity;
  final String? cvPdfBase64;
  final String? cvPdfFilename;
}

class AnalyzeCvUseCase {
  const AnalyzeCvUseCase(this._repository);

  final CvRepository _repository;

  Future<CvAnalysis> call(AnalyzeCvParams params) {
    return _repository.analyzeCv(
      cvText: params.cvText,
      targetOpportunity: params.targetOpportunity,
      cvPdfBase64: params.cvPdfBase64,
      cvPdfFilename: params.cvPdfFilename,
    );
  }
}

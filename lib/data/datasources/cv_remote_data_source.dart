import '../../core/network/api_client.dart';
import '../dto/cv_analysis_dto.dart';

class CvRemoteDataSource {
  static const Duration _analysisTimeout = Duration(seconds: 90);

  const CvRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<CvAnalysisDto> analyzeCv({
    required String cvText,
    required String targetOpportunity,
    String? cvPdfBase64,
    String? cvPdfFilename,
  }) async {
    final payload = await _apiClient.postJson(
      '/analyze-cv',
      body: {
        'cv_text': cvText,
        'target_opportunity': targetOpportunity,
        'cv_pdf_base64': cvPdfBase64,
        'cv_pdf_filename': cvPdfFilename,
      },
      timeoutOverride: _analysisTimeout,
    );

    return CvAnalysisDto.fromJson(payload);
  }
}

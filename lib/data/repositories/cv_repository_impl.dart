import '../../domain/models/cv_analysis.dart';
import '../../domain/repositories/cv_repository.dart';
import '../datasources/cv_remote_data_source.dart';

class CvRepositoryImpl implements CvRepository {
  const CvRepositoryImpl(this._remoteDataSource);

  final CvRemoteDataSource _remoteDataSource;

  @override
  Future<CvAnalysis> analyzeCv({
    required String cvText,
    required String targetOpportunity,
    String? cvPdfBase64,
    String? cvPdfFilename,
  }) async {
    final dto = await _remoteDataSource.analyzeCv(
      cvText: cvText,
      targetOpportunity: targetOpportunity,
      cvPdfBase64: cvPdfBase64,
      cvPdfFilename: cvPdfFilename,
    );

    return dto.toDomain();
  }
}

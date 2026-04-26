import 'package:get_it/get_it.dart';

import '../config/app_config.dart';
import '../../data/datasources/cv_remote_data_source.dart';
import '../../data/repositories/cv_repository_impl.dart';
import '../../domain/repositories/cv_repository.dart';
import '../../domain/usecases/analyze_cv_usecase.dart';
import '../network/api_client.dart';

final sl = GetIt.instance;

void setupLocator({
  bool force = false,
  ApiClient? apiClient,
  CvRemoteDataSource? cvRemoteDataSource,
  CvRepository? cvRepository,
  AnalyzeCvUseCase? analyzeCvUseCase,
}) {
  if (!force && sl.isRegistered<ApiClient>()) {
    return;
  }
  if (force) {
    sl.reset(dispose: false);
  }

  sl.registerLazySingleton<ApiClient>(
    () => apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl),
  );

  sl.registerLazySingleton<CvRemoteDataSource>(
    () => cvRemoteDataSource ?? CvRemoteDataSource(sl<ApiClient>()),
  );

  sl.registerLazySingleton<CvRepository>(
    () => cvRepository ?? CvRepositoryImpl(sl<CvRemoteDataSource>()),
  );

  sl.registerLazySingleton<AnalyzeCvUseCase>(
    () => analyzeCvUseCase ?? AnalyzeCvUseCase(sl<CvRepository>()),
  );
}

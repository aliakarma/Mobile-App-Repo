import '../../models/application_model.dart';

abstract class ApplicationsRepository {
  Future<List<ApplicationModel>> fetchApplications();
  Future<int> insertApplication(ApplicationModel application);
  Future<int> deleteApplication(int id);
}


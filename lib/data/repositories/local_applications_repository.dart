import '../../database/local_database.dart';
import '../../domain/repositories/applications_repository.dart';
import '../../models/application_model.dart';

class LocalApplicationsRepository implements ApplicationsRepository {
  LocalApplicationsRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  @override
  Future<List<ApplicationModel>> fetchApplications() {
    return _databaseHelper.fetchApplications();
  }

  @override
  Future<int> insertApplication(ApplicationModel application) {
    return _databaseHelper.insertApplication(application);
  }

  @override
  Future<int> deleteApplication(int id) {
    return _databaseHelper.deleteApplication(id);
  }
}


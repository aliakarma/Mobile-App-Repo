import '../models/application_model.dart';

class ApplicationService {
  const ApplicationService();

  // Placeholder service; backend integration will be added later.
  List<ApplicationModel> getSampleApplications() {
    return const [
      ApplicationModel(
        id: '1',
        title: 'Sample Application',
        status: 'Draft',
      ),
    ];
  }
}

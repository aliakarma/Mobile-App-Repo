import '../models/application_model.dart';

class ApplicationService {
  const ApplicationService();

  // Placeholder service; backend integration will be added later.
  List<ApplicationModel> getSampleApplications() {
    return [
      ApplicationModel(
        id: 1,
        title: 'Sample Application',
        deadline: DateTime.now().add(const Duration(days: 14)),
        status: 'Applied',
        fitScore: 0.0,
        riskLevel: 'Low',
        recommendation: 'Prepare More',
      ),
    ];
  }
}

import 'package:mocktail/mocktail.dart';

import 'package:smart_application_intelligence_system/domain/models/cv_analysis.dart';
import 'package:smart_application_intelligence_system/domain/repositories/applications_repository.dart';
import 'package:smart_application_intelligence_system/domain/usecases/analyze_cv_usecase.dart';
import 'package:smart_application_intelligence_system/models/application_model.dart';
import 'package:smart_application_intelligence_system/models/auth_session_model.dart';
import 'package:smart_application_intelligence_system/models/auth_user_model.dart';
import 'package:smart_application_intelligence_system/services/auth_api_service.dart';
import 'package:smart_application_intelligence_system/services/auth_local_storage.dart';

class MockAuthApiService extends Mock implements AuthApiService {}

class FakeAuthLocalStorage extends Fake implements AuthLocalStorage {
  AuthSessionModel? _session;

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    _session = session;
  }

  @override
  Future<AuthSessionModel?> loadSession() async {
    return _session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}

class InMemoryApplicationsRepository extends Fake implements ApplicationsRepository {
  final List<ApplicationModel> _items = [];
  int _nextId = 1;

  @override
  Future<List<ApplicationModel>> fetchApplications() async {
    return List<ApplicationModel>.unmodifiable(_items);
  }

  @override
  Future<int> insertApplication(ApplicationModel application) async {
    final id = _nextId++;
    _items.add(
      ApplicationModel(
        id: id,
        title: application.title,
        deadline: application.deadline,
        status: application.status,
        fitScore: application.fitScore,
        riskLevel: application.riskLevel,
        recommendation: application.recommendation,
      ),
    );
    return id;
  }

  @override
  Future<int> deleteApplication(int id) async {
    final before = _items.length;
    _items.removeWhere((a) => a.id == id);
    return before - _items.length;
  }
}

class MockAnalyzeCvUseCase extends Mock implements AnalyzeCvUseCase {}

AuthSessionModel buildFakeSession() {
  return AuthSessionModel(
    accessToken: 'test-token',
    tokenType: 'bearer',
    expiresIn: 3600,
    issuedAt: DateTime.now(),
    user: AuthUserModel(
      id: 1,
      fullName: 'Test User',
      email: 'test@example.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
}

CvAnalysis buildFakeCvAnalysis() {
  return const CvAnalysis(
    overallFitScore: 82,
    strengths: ['Strong research background'],
    gaps: ['Add more quantified impact'],
    tailoringSuggestions: ['Match keywords from the description'],
    missingKeywords: ['NLP', 'Publications'],
    recommendedSections: ['Selected projects'],
  );
}


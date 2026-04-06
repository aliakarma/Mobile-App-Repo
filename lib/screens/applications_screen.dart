import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/application_model.dart';
import '../services/application_intelligence_service.dart';
import '../services/user_profile_service.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  List<ApplicationModel> _applications = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
    });

    final applications = await _databaseHelper.fetchApplications();

    if (!mounted) {
      return;
    }

    setState(() {
      _applications = applications;
      _isLoading = false;
    });
  }

  Future<void> _deleteApplication(int id) async {
    await _databaseHelper.deleteApplication(id);
    await _loadApplications();
  }

  Future<void> _showAddApplicationDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    DateTime? selectedDeadline;
    String selectedStatus = 'Applied';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Application'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Applied', child: Text('Applied')),
                        DropdownMenuItem(
                            value: 'In Review', child: Text('In Review')),
                        DropdownMenuItem(
                            value: 'Interview', child: Text('Interview')),
                        DropdownMenuItem(value: 'Offer', child: Text('Offer')),
                        DropdownMenuItem(
                            value: 'Rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDeadline ?? now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (pickedDate == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeadline = pickedDate;
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Deadline',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          selectedDeadline == null
                              ? 'Select a date'
                              : _formatDate(selectedDeadline!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    if (selectedDeadline == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please choose a deadline')),
                      );
                      return;
                    }

                    await _databaseHelper.insertApplication(
                      await _buildScoredApplication(
                        title: titleController.text.trim(),
                        deadline: selectedDeadline!,
                        status: selectedStatus,
                      ),
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    await _loadApplications();
  }

  double _progressFromStatus(String status) {
    switch (status) {
      case 'Applied':
        return 0.2;
      case 'In Review':
        return 0.4;
      case 'Interview':
        return 0.7;
      case 'Offer':
        return 1.0;
      case 'Rejected':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Future<ApplicationModel> _buildScoredApplication({
    required String title,
    required DateTime deadline,
    required String status,
  }) async {
    final profile = await _profileService.getProfile();
    final hasResearch = profile.researchExperienceLevel != 'none';

    final fitScore = ApplicationIntelligenceService.calculateFitScore(
      gpa: profile.gpa,
      field: profile.fieldOfStudy,
      researchExperience: hasResearch,
      publications: profile.publications,
    );

    final readinessScore = _readinessFromStatus(status);
    final daysUntilDeadline = _daysUntilDeadline(deadline);

    final riskLevelEnum = ApplicationIntelligenceService.calculateRiskLevel(
      daysUntilDeadline: daysUntilDeadline,
      readinessScore: readinessScore,
    );

    final recommendation = ApplicationIntelligenceService.getRecommendation(
      fitScore: fitScore,
      readinessScore: readinessScore,
      daysToDeadline: daysUntilDeadline,
    );

    return ApplicationModel(
      title: title,
      deadline: deadline,
      status: status,
      fitScore: fitScore,
      riskLevel: _riskLevelLabel(riskLevelEnum),
      recommendation: recommendation,
    );
  }

  double _readinessFromStatus(String status) {
    switch (status) {
      case 'Applied':
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: false,
          sopReady: true,
          checklistProgress: 35,
        );
      case 'In Review':
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: true,
          sopReady: true,
          checklistProgress: 65,
        );
      case 'Interview':
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: true,
          sopReady: true,
          checklistProgress: 85,
        );
      case 'Offer':
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: true,
          sopReady: true,
          checklistProgress: 100,
        );
      case 'Rejected':
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: true,
          sopReady: true,
          checklistProgress: 100,
        );
      default:
        return ApplicationIntelligenceService.calculateReadinessScore(
          documentsComplete: false,
          sopReady: false,
          checklistProgress: 0,
        );
    }
  }

  int _daysUntilDeadline(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  String _riskLevelLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.green.shade600;
    }
  }

  Color _recommendationColor(String recommendation) {
    switch (recommendation) {
      case 'Apply':
        return Colors.green.shade700;
      case 'Skip':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? const Center(child: Text('No applications yet.'))
              : ListView.separated(
                  itemCount: _applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final application = _applications[index];
                    final progress = _progressFromStatus(application.status);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    application.title,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: application.id == null
                                      ? null
                                      : () =>
                                          _deleteApplication(application.id!),
                                ),
                              ],
                            ),
                            Text(
                                'Deadline: ${_formatDate(application.deadline)}'),
                            Text('Status: ${application.status}'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 10),
                            Text(
                              'Fit Score: ${application.fitScore.toStringAsFixed(1)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  backgroundColor:
                                      _riskColor(application.riskLevel),
                                  label: Text(
                                    'Risk: ${application.riskLevel}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                Chip(
                                  backgroundColor: _recommendationColor(
                                      application.recommendation),
                                  label: Text(
                                    'Recommendation: ${application.recommendation}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddApplicationDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

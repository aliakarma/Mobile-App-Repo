import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/application_model.dart';
import '../services/application_intelligence_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_ui.dart';

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
                    const SizedBox(height: AppSpacing.s12),
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
                    const SizedBox(height: AppSpacing.s12),
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

                    final newApplication = await _buildScoredApplication(
                      title: titleController.text.trim(),
                      deadline: selectedDeadline!,
                      status: selectedStatus,
                    );

                    debugPrint(
                      '[Applications] Create title="${newApplication.title}" fit=${newApplication.fitScore.toStringAsFixed(1)} risk=${newApplication.riskLevel} recommendation=${newApplication.recommendation}',
                    );

                    await _databaseHelper.insertApplication(newApplication);

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

    final normalizedGpa = profile.gpaScale <= 4
        ? profile.gpa
        : (profile.gpa / profile.gpaScale) * 4.0;

    final fitScore = ApplicationIntelligenceService.calculateFitScore(
      gpa: normalizedGpa,
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

  String _recommendationReasonForApplication(ApplicationModel application) {
    final readinessScore = _readinessFromStatus(application.status);
    final daysUntilDeadline = _daysUntilDeadline(application.deadline);

    return ApplicationIntelligenceService.getRecommendationReason(
      fitScore: application.fitScore,
      readinessScore: readinessScore,
      daysToDeadline: daysUntilDeadline,
    );
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
        return Colors.blue.shade700;
      case 'Skip':
        return Colors.grey.shade700;
      default:
        return Colors.indigo.shade600;
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
      appBar: AppBar(title: const Text('Applications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? EmptyStateView(
                  icon: Icons.assignment_outlined,
                  title: 'No applications yet',
                  subtitle: 'Start tracking your first application.',
                  actionLabel: 'Add Application',
                  onAction: _showAddApplicationDialog,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  itemCount: _applications.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s8),
                  itemBuilder: (context, index) {
                    final application = _applications[index];
                    final progress = _progressFromStatus(application.status);

                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  application.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: application.id == null
                                    ? null
                                    : () => _deleteApplication(application.id!),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            'Deadline: ${_formatDate(application.deadline)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            'Status: ${application.status}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            'Fit Score: ${application.fitScore.toStringAsFixed(1)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s8,
                            children: [
                              LabelChip(
                                label: 'Risk: ${application.riskLevel}',
                                backgroundColor:
                                    _riskColor(application.riskLevel),
                              ),
                              LabelChip(
                                label:
                                    'Recommendation: ${application.recommendation}',
                                backgroundColor: _recommendationColor(
                                  application.recommendation,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            _recommendationReasonForApplication(application),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                          ),
                        ],
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

import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/application_model.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
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
                      ApplicationModel(
                        title: titleController.text.trim(),
                        deadline: selectedDeadline!,
                        status: selectedStatus,
                        fitScore: 0.0,
                        riskLevel: 'Medium',
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
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final application = _applications[index];
                    final progress = _progressFromStatus(application.status);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      title: Text(application.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                              'Deadline: ${_formatDate(application.deadline)}'),
                          Text('Status: ${application.status}'),
                          Text(
                            'Fit score: ${application.fitScore.toStringAsFixed(1)} (placeholder)',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: application.id == null
                            ? null
                            : () => _deleteApplication(application.id!),
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

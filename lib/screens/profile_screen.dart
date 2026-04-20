import 'package:flutter/material.dart';

import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_ui.dart';
import 'cv_analyzer_screen.dart';
import 'sop_analyzer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.accountName,
    required this.accountEmail,
  });

  final Future<void> Function() onLogout;
  final String accountName;
  final String accountEmail;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gpaController = TextEditingController();
  final _fieldController = TextEditingController();
  final _publicationsController = TextEditingController();
  final UserProfileService _profileService = UserProfileService.instance;

  String _researchLevel = 'none';
  int _gpaScale = 4;
  bool _isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _gpaController.dispose();
    _fieldController.dispose();
    _publicationsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile();
    if (!mounted) return;
    setState(() {
      _gpaController.text = profile.gpa.toString();
      _fieldController.text = profile.fieldOfStudy;
      _publicationsController.text = profile.publications.toString();
      _researchLevel = profile.researchExperienceLevel;
      _gpaScale = profile.gpaScale;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = UserProfileModel(
      gpa: double.parse(_gpaController.text.trim()),
      gpaScale: _gpaScale,
      fieldOfStudy: _fieldController.text.trim(),
      researchExperienceLevel: _researchLevel,
      publications: int.parse(_publicationsController.text.trim()),
    );

    await _profileService.saveProfile(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully.')),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.onLogout();
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isLoggingOut ? null : _handleLogout,
            icon: _isLoggingOut
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      margin: const EdgeInsets.only(
                        bottom: AppSpacing.s12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              widget.accountName.isNotEmpty
                                  ? widget.accountName[0].toUpperCase()
                                  : 'U',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.accountName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.accountEmail,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: _gpaScale,
                      decoration: const InputDecoration(
                        labelText: 'GPA scale',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('0 – 4')),
                        DropdownMenuItem(value: 10, child: Text('0 – 10')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _gpaScale = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: _gpaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'GPA',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null ||
                            parsed < 0 ||
                            parsed > _gpaScale) {
                          return 'Enter a GPA between 0 and $_gpaScale';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: _fieldController,
                      decoration: const InputDecoration(
                        labelText: 'Field of study',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Field of study is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    DropdownButtonFormField<String>(
                      initialValue: _researchLevel,
                      decoration: const InputDecoration(
                        labelText: 'Research experience',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(value: 'basic', child: Text('Basic')),
                        DropdownMenuItem(
                            value: 'advanced', child: Text('Advanced')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _researchLevel = value);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    TextFormField(
                      controller: _publicationsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Publications',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid non-negative integer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Profile'),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // ---- AI Tools ----
                    Text(
                      'AI Tools',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SopAnalyzerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.text_snippet_outlined),
                      label: const Text('Open SOP Analyzer'),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CvAnalyzerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Open CV Analyzer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

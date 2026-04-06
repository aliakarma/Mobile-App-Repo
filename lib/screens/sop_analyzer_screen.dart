import 'package:flutter/material.dart';

import '../models/sop_analysis_model.dart';
import '../services/sop_service.dart';
import '../widgets/app_ui.dart';

class SopAnalyzerScreen extends StatefulWidget {
  const SopAnalyzerScreen({super.key});

  @override
  State<SopAnalyzerScreen> createState() => _SopAnalyzerScreenState();
}

class _SopAnalyzerScreenState extends State<SopAnalyzerScreen> {
  static const int _minWordCount = 200;
  static const Duration _debounceWindow = Duration(milliseconds: 1200);

  final TextEditingController _sopController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SopService _sopService = const SopService();

  SopAnalysisModel? _analysis;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSubmitAttempt;

  @override
  void dispose() {
    _sopController.dispose();
    super.dispose();
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  Future<void> _submitSop() async {
    final now = DateTime.now();
    if (_lastSubmitAttempt != null &&
        now.difference(_lastSubmitAttempt!) < _debounceWindow) {
      setState(() {
        _errorMessage = 'Please wait a moment before submitting again.';
      });
      return;
    }
    _lastSubmitAttempt = now;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final sopText = _sopController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysis = null;
    });

    try {
      final result = await _sopService.analyzeSop(sopText);
      if (!mounted) {
        return;
      }
      setState(() {
        _analysis = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWordCount = _wordCount(_sopController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('SOP Analyzer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _sopController,
                  maxLines: 12,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Paste your SOP text',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Please enter your SOP text.';
                    }
                    if (_wordCount(text) < _minWordCount) {
                      return 'Minimum $_minWordCount words required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Word count: $currentWordCount / $_minWordCount minimum',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: currentWordCount >= _minWordCount
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: AppSpacing.s12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitSop,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Analyze SOP'),
                ),
                const SizedBox(height: AppSpacing.s16),
                if (_errorMessage != null)
                  ErrorStateView(
                    title: 'SOP analysis failed',
                    message: _errorMessage!,
                    onRetry: _isLoading ? () {} : _submitSop,
                  ),
                if (_analysis != null) ...[
                  _SectionCard(
                    title: 'Score',
                    child: Text(
                      _analysis!.score.toString(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  _SectionCard(
                    title: 'Strengths',
                    child: _BulletedList(items: _analysis!.strengths),
                  ),
                  _SectionCard(
                    title: 'Weaknesses',
                    child: _BulletedList(items: _analysis!.weaknesses),
                  ),
                  _SectionCard(
                    title: 'Suggestions',
                    child: _BulletedList(items: _analysis!.suggestions),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(top: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.s8),
          child,
        ],
      ),
    );
  }
}

class _BulletedList extends StatelessWidget {
  const _BulletedList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No items available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('- $item'),
            ),
          )
          .toList(),
    );
  }
}

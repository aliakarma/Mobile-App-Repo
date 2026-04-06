import 'package:flutter/material.dart';

import '../models/sop_analysis_model.dart';
import '../services/sop_service.dart';

class SopAnalyzerScreen extends StatefulWidget {
  const SopAnalyzerScreen({super.key});

  @override
  State<SopAnalyzerScreen> createState() => _SopAnalyzerScreenState();
}

class _SopAnalyzerScreenState extends State<SopAnalyzerScreen> {
  final TextEditingController _sopController = TextEditingController();
  final SopService _sopService = const SopService();

  SopAnalysisModel? _analysis;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sopController.dispose();
    super.dispose();
  }

  Future<void> _submitSop() async {
    final sopText = _sopController.text.trim();
    if (sopText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your SOP text.';
      });
      return;
    }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOP Analyzer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _sopController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Paste your SOP text',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
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
              child: Text('• $item'),
            ),
          )
          .toList(),
    );
  }
}

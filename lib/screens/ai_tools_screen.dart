import 'package:flutter/material.dart';

import '../presentation/screens/cv_analyzer_screen.dart';
import '../widgets/app_ui.dart';
import 'sop_analyzer_screen.dart';

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('SOP Analyzer'),
              subtitle: const Text('Get structured feedback and a score.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SopAnalyzerScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppCard(
            child: ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('CV Analyzer'),
              subtitle: const Text('Analyze your CV and see strengths/gaps.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CvAnalyzerScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


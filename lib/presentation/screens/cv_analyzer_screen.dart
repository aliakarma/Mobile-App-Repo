import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cv_analysis.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/score_ring.dart';
import '../providers/cv_analyzer_provider.dart';

class CvAnalyzerScreen extends ConsumerWidget {
  const CvAnalyzerScreen({super.key});

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF2E7D32);
    if (score >= 65) return const Color(0xFF1565C0);
    if (score >= 45) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Exceptional Fit';
    if (score >= 65) return 'Strong Fit';
    if (score >= 45) return 'Moderate Fit';
    return 'Low Fit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(cvAnalyzerProvider);
    final notifier = ref.read(cvAnalyzerProvider.notifier);
    final view = viewAsync.value ?? const CvAnalyzerViewState();

    ref.listen(cvAnalyzerProvider, (previous, next) {
      final prevSubmitting = previous?.value?.isSubmitting ?? false;
      final nextValue = next.value;
      if (!prevSubmitting) return;
      if (nextValue == null) return;
      if (nextValue.isSubmitting) return;

      if (nextValue.analysis != null) {
        HapticFeedback.mediumImpact();
      } else if (nextValue.errorMessage != null) {
        HapticFeedback.heavyImpact();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Analyzer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _InfoBanner(),
              const SizedBox(height: AppSpacing.s16),
              TextFormField(
                initialValue: view.targetOpportunity,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Target Scholarship / Internship',
                  hintText:
                      'Paste the opportunity title and description here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.updateTargetOpportunity,
              ),
              const SizedBox(height: AppSpacing.s12),
              OutlinedButton.icon(
                onPressed: view.isSubmitting || view.isPickingPdf
                    ? null
                    : notifier.pickCvPdf,
                icon: view.isPickingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  view.selectedCvPdfName == null
                      ? 'Upload CV PDF (Optional)'
                      : 'PDF Selected: ${view.selectedCvPdfName}',
                ),
              ),
              if (view.selectedCvPdfName != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        view.isSubmitting ? null : notifier.removeSelectedPdf,
                    icon: const Icon(Icons.close),
                    label: const Text('Remove selected PDF'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              TextFormField(
                initialValue: view.cvText,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Your CV / Resume',
                  hintText: 'Paste your full CV text here...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.updateCvText,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                view.selectedCvPdfBytes != null
                    ? 'PDF upload selected. Pasted text is optional.'
                    : 'Word count: ${view.cvWordCount} / $minCvWordCount minimum',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: view.selectedCvPdfBytes != null ||
                              view.cvWordCount >= minCvWordCount
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: AppSpacing.s16),
              ElevatedButton.icon(
                onPressed: view.isSubmitting
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        notifier.analyzeCv();
                      },
                icon: view.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(view.isSubmitting ? 'Analysing...' : 'Analyse CV'),
              ),
              if (view.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s16),
                ErrorStateView(
                  title: 'CV analysis failed',
                  message: view.errorMessage!,
                  onRetry: notifier.analyzeCv,
                ),
              ],
              if (view.analysis != null) ...[
                const SizedBox(height: AppSpacing.s24),
                _ResultsView(
                  analysis: view.analysis!,
                  scoreColor: _scoreColor(view.analysis!.overallFitScore),
                  scoreLabel: _scoreLabel(view.analysis!.overallFitScore),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'AI-Powered CV Analysis',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Paste your CV and target opportunity. The app will score fit and suggest improvements.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.analysis,
    required this.scoreColor,
    required this.scoreLabel,
  });

  final CvAnalysis analysis;
  final Color scoreColor;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Row(
                children: [
                  ScoreRing(
                    score: analysis.overallFitScore,
                    color: scoreColor,
                    label: '/100',
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Fit',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        LabelChip(
                          label: scoreLabel,
                          backgroundColor: scoreColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        _ListSection(
          title: 'Strengths',
          items: analysis.strengths,
          emptyMessage: 'No clear strengths identified for this opportunity.',
        ),
        _ListSection(
          title: 'Gaps',
          items: analysis.gaps,
          emptyMessage: 'No major gaps identified.',
        ),
        _ListSection(
          title: 'Tailoring Suggestions',
          items: analysis.tailoringSuggestions,
          emptyMessage: 'No specific tailoring suggestions.',
        ),
        _ListSection(
          title: 'Missing Keywords',
          items: analysis.missingKeywords,
          emptyMessage: 'No missing keywords identified.',
        ),
        _ListSection(
          title: 'Sections to Add / Strengthen',
          items: analysis.recommendedSections,
          emptyMessage: 'Your CV structure looks complete.',
        ),
      ],
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.items,
    required this.emptyMessage,
  });

  final String title;
  final List<String> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

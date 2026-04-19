import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cv_analysis_model.dart';
import '../services/cv_service.dart';
import '../widgets/app_ui.dart';

class CvAnalyzerScreen extends StatefulWidget {
  const CvAnalyzerScreen({super.key});

  @override
  State<CvAnalyzerScreen> createState() => _CvAnalyzerScreenState();
}

class _CvAnalyzerScreenState extends State<CvAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  static const int _minCvWordCount = 100;
  static const int _minOpportunityLength = 20;

  final TextEditingController _cvController = TextEditingController();
  final TextEditingController _opportunityController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final CvService _cvService = CvService();

  CvAnalysisModel? _analysis;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _scoreAnimationController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _scoreAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _cvController.dispose();
    _opportunityController.dispose();
    _scoreAnimationController.dispose();
    super.dispose();
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  Future<void> _submitAnalysis() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysis = null;
    });
    _scoreAnimationController.reset();

    try {
      final result = await _cvService.analyzeCv(
        cvText: _cvController.text.trim(),
        targetOpportunity: _opportunityController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _isLoading = false;
      });
      _scoreAnimationController.forward();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF2E7D32); // deep green
    if (score >= 65) return const Color(0xFF1565C0); // strong blue
    if (score >= 45) return const Color(0xFFE65100); // amber-orange
    return const Color(0xFFC62828); // red
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Exceptional Fit';
    if (score >= 65) return 'Strong Fit';
    if (score >= 45) return 'Moderate Fit';
    return 'Low Fit';
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _wordCount(_cvController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV Analyzer'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                const _InfoBanner(
                  icon: Icons.document_scanner_outlined,
                  title: 'AI-Powered CV Analysis',
                  subtitle:
                      'Paste your CV and the target opportunity description. '
                      'Gemini will assess your fit and provide tailored suggestions.',
                ),
                const SizedBox(height: AppSpacing.s16),

                // Target opportunity input
                TextFormField(
                  controller: _opportunityController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Target Scholarship / Internship',
                    hintText:
                        'Paste the opportunity title and description here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.school_outlined),
                    ),
                  ),
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < _minOpportunityLength) {
                      return 'Please provide more detail about the opportunity.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s12),

                // CV input
                TextFormField(
                  controller: _cvController,
                  maxLines: 14,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Your CV / Resume',
                    hintText: 'Paste your full CV text here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 100),
                      child: Icon(Icons.article_outlined),
                    ),
                  ),
                  validator: (value) {
                    if (_wordCount(value?.trim() ?? '') < _minCvWordCount) {
                      return 'Minimum $_minCvWordCount words required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Word count: $wordCount / $_minCvWordCount minimum',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: wordCount >= _minCvWordCount
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Analyze button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitAnalysis,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(_isLoading ? 'Analysing...' : 'Analyse CV'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                // Error display
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  ErrorStateView(
                    title: 'CV analysis failed',
                    message: _errorMessage!,
                    onRetry: _submitAnalysis,
                  ),
                ],

                // Results
                if (_analysis != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  _buildResults(_analysis!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(CvAnalysisModel analysis) {
    final scoreColor = _scoreColor(analysis.overallFitScore);
    final scoreLabel = _scoreLabel(analysis.overallFitScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Animated score ring
        Center(
          child: AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              final animatedScore =
                  (analysis.overallFitScore * _scoreAnimation.value).round();
              return Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _ScoreRingPainter(
                        progress: _scoreAnimation.value *
                            analysis.overallFitScore /
                            100,
                        color: scoreColor,
                        backgroundColor: scoreColor.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$animatedScore',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scoreColor,
                                  ),
                            ),
                            Text(
                              '/ 100',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      scoreLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s24),

        // Strengths
        _ResultSection(
          title: 'Strengths',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF2E7D32),
          items: analysis.strengths,
          emptyMessage: 'No clear strengths identified for this opportunity.',
        ),

        // Gaps
        _ResultSection(
          title: 'Gaps',
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFC62828),
          items: analysis.gaps,
          emptyMessage: 'No major gaps identified.',
        ),

        // Tailoring suggestions
        _ResultSection(
          title: 'Tailoring Suggestions',
          icon: Icons.edit_outlined,
          color: const Color(0xFF1565C0),
          items: analysis.tailoringSuggestions,
          emptyMessage: 'No specific tailoring suggestions.',
        ),

        // Missing keywords
        if (analysis.missingKeywords.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.label_off_outlined,
                        color: Color(0xFFE65100), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Missing Keywords',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE65100),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: analysis.missingKeywords
                      .map(
                        (kw) => Chip(
                          label: Text(kw,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor:
                              const Color(0xFFE65100).withValues(alpha: 0.08),
                          side: const BorderSide(
                              color: Color(0xFFE65100), width: 0.8),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

        // Recommended sections
        _ResultSection(
          title: 'Sections to Add / Strengthen',
          icon: Icons.add_box_outlined,
          color: const Color(0xFF6A1B9A),
          items: analysis.recommendedSections,
          emptyMessage: 'Your CV structure looks complete.',
        ),

        const SizedBox(height: AppSpacing.s24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (items.isEmpty)
            Text(
              emptyMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.circle, size: 7, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score ring painter
// ---------------------------------------------------------------------------

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

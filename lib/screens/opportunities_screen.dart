import 'package:flutter/material.dart';

import '../models/opportunity_model.dart';
import '../models/user_profile_model.dart';
import '../services/application_intelligence_service.dart';
import '../services/opportunity_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/app_ui.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final OpportunityService _opportunityService = const OpportunityService();
  final UserProfileService _profileService = UserProfileService.instance;

  List<_RankedOpportunity> _rankedOpportunities = const [];
  bool _isLoading = true;
  bool _isUsingCachedData = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOpportunities();
  }

  Future<void> _loadOpportunities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isUsingCachedData = false;
    });

    try {
      final result = await _opportunityService.fetchOpportunities();
      final profile = await _profileService.getProfile();
      final ranked = _rankOpportunities(result.opportunities, profile);

      if (!mounted) {
        return;
      }

      setState(() {
        _rankedOpportunities = ranked;
        _isUsingCachedData = result.fromCache;
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
      appBar: AppBar(title: const Text('Opportunities')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        title: 'Failed to load opportunities',
        message: _errorMessage!,
        onRetry: _loadOpportunities,
      );
    }

    if (_rankedOpportunities.isEmpty) {
      return const EmptyStateView(
        icon: Icons.travel_explore_outlined,
        title: 'No opportunities found',
        subtitle: 'Try again later or check your backend connection.',
      );
    }

    return Column(
      children: [
        if (_isUsingCachedData)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            color: Colors.amber.shade50,
            child: Text(
              'Showing cached data (offline mode)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOpportunities,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              itemCount: _rankedOpportunities.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, index) {
                final ranked = _rankedOpportunities[index];
                final opportunity = ranked.opportunity;
                final isTopThree = index < 3;

                return AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isTopThree
                              ? Colors.orange.shade600
                              : Colors.blueGrey.shade400,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    opportunity.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (isTopThree)
                                  const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              'Deadline: ${opportunity.deadline}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              'Provider: ${opportunity.provider}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            Text(
                              'Fit Score: ${ranked.fitScore.toStringAsFixed(1)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              'Ranking Score: ${ranked.rankingScore.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<_RankedOpportunity> _rankOpportunities(
    List<OpportunityModel> opportunities,
    UserProfileModel profile,
  ) {
    final normalizedGpa = profile.gpaScale <= 4
        ? profile.gpa
        : (profile.gpa / profile.gpaScale) * 4.0;

    final ranked = opportunities.map((opportunity) {
      final daysToDeadline = _daysToDeadline(opportunity.deadline);
      final fitScore = ApplicationIntelligenceService.calculateFitScore(
        gpa: normalizedGpa,
        field:
            '${profile.fieldOfStudy} ${opportunity.title} ${opportunity.eligibility}',
        researchExperience: profile.researchExperienceLevel != 'none',
        publications: profile.publications,
      );

      final deadlineScore = _deadlineProximityScore(daysToDeadline);
      final rankingScore = (fitScore * 0.7) + (deadlineScore * 0.3);

      return _RankedOpportunity(
        opportunity: opportunity,
        fitScore: fitScore,
        rankingScore: rankingScore,
      );
    }).toList();

    ranked.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return ranked;
  }

  int _daysToDeadline(String deadlineText) {
    final parsedDate = DateTime.tryParse(deadlineText);
    if (parsedDate == null) {
      return 90;
    }

    final days = parsedDate.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  double _deadlineProximityScore(int daysToDeadline) {
    if (daysToDeadline <= 7) {
      return 100;
    }
    if (daysToDeadline <= 14) {
      return 80;
    }
    if (daysToDeadline <= 30) {
      return 60;
    }
    if (daysToDeadline <= 60) {
      return 40;
    }
    return 20;
  }
}

class _RankedOpportunity {
  const _RankedOpportunity({
    required this.opportunity,
    required this.fitScore,
    required this.rankingScore,
  });

  final OpportunityModel opportunity;
  final double fitScore;
  final double rankingScore;
}

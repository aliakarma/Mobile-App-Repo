import 'package:flutter/material.dart';

import '../models/opportunity_model.dart';
import '../models/user_profile_model.dart';
import '../services/application_intelligence_service.dart';
import '../services/opportunity_service.dart';
import '../services/user_profile_service.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final OpportunityService _opportunityService = const OpportunityService();
  final UserProfileService _profileService = UserProfileService.instance;
  List<OpportunityModel> _opportunities = const [];
  List<_RankedOpportunity> _rankedOpportunities = const [];
  bool _isLoading = true;
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
    });

    try {
      final opportunities = await _opportunityService.fetchOpportunities();
      final profile = await _profileService.getProfile();
      final ranked = _rankOpportunities(opportunities, profile);
      if (!mounted) {
        return;
      }
      setState(() {
        _opportunities = opportunities;
        _rankedOpportunities = ranked;
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
        title: const Text('Opportunities'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load opportunities.'),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOpportunities,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_opportunities.isEmpty) {
      return const Center(child: Text('No opportunities available.'));
    }

    return RefreshIndicator(
      onRefresh: _loadOpportunities,
      child: ListView.separated(
        itemCount: _rankedOpportunities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ranked = _rankedOpportunities[index];
          final opportunity = ranked.opportunity;
          final isTopThree = index < 3;

          return Container(
            color: isTopThree ? Colors.amber.shade50 : null,
            child: ListTile(
              title: Text(
                '#${index + 1} ${opportunity.title}',
                style: TextStyle(
                  fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Deadline: ${opportunity.deadline}'),
                  Text('Provider: ${opportunity.provider}'),
                  Text('Fit score: ${ranked.fitScore.toStringAsFixed(1)}'),
                  Text(
                    'Ranking score: ${ranked.rankingScore.toStringAsFixed(1)}',
                  ),
                ],
              ),
              trailing: isTopThree
                  ? const Icon(Icons.workspace_premium, color: Colors.orange)
                  : null,
            ),
          );
        },
      ),
    );
  }

  List<_RankedOpportunity> _rankOpportunities(
    List<OpportunityModel> opportunities,
    UserProfileModel profile,
  ) {
    final ranked = opportunities.map((opportunity) {
      final daysToDeadline = _daysToDeadline(opportunity.deadline);
      final fitScore = ApplicationIntelligenceService.calculateFitScore(
        gpa: profile.gpa,
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

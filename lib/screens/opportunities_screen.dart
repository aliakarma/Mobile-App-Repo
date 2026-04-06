import 'package:flutter/material.dart';

import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final OpportunityService _opportunityService = const OpportunityService();
  List<OpportunityModel> _opportunities = const [];
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
      if (!mounted) {
        return;
      }
      setState(() {
        _opportunities = opportunities;
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
        itemCount: _opportunities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final opportunity = _opportunities[index];
          return ListTile(
            title: Text(opportunity.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Deadline: ${opportunity.deadline}'),
                Text('Provider: ${opportunity.provider}'),
              ],
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}

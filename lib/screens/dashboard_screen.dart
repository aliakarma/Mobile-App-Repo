import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/local_database.dart';
import '../models/application_model.dart';
import '../widgets/app_ui.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  bool _isLoading = true;
  Map<String, int> _statusCounts = const {};

  @override
  void initState() {
    super.initState();
    _loadStatusCounts();
  }

  Future<void> _loadStatusCounts() async {
    setState(() {
      _isLoading = true;
    });

    final applications = await _databaseHelper.fetchApplications();
    final counts = _groupByStatus(applications);

    if (!mounted) {
      return;
    }
    setState(() {
      _statusCounts = counts;
      _isLoading = false;
    });
  }

  Map<String, int> _groupByStatus(List<ApplicationModel> applications) {
    final grouped = <String, int>{};
    for (final app in applications) {
      grouped.update(app.status, (value) => value + 1, ifAbsent: () => 1);
    }
    return grouped;
  }

  Color _segmentColor(int index) {
    final palette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _statusCounts.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const EmptyStateView(
                  icon: Icons.pie_chart_outline,
                  title: 'No application data yet',
                  subtitle: 'Add applications to see status distribution.',
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Applications by Status',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: List.generate(entries.length, (index) {
                                final entry = entries[index];
                                return PieChartSectionData(
                                  color: _segmentColor(index),
                                  value: entry.value.toDouble(),
                                  title: entry.value.toString(),
                                  radius: 72,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      ...List.generate(entries.length, (index) {
                        final entry = entries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _segmentColor(index),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                entry.value.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

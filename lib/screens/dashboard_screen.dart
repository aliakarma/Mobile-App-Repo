import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/local_database.dart';
import '../models/application_model.dart';

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
              ? const Center(child: Text('No application data yet.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Applications by Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
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
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(entries.length, (index) {
                        final entry = entries[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                color: _segmentColor(index),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.key)),
                              Text(entry.value.toString()),
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

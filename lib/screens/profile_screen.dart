import 'package:flutter/material.dart';

import 'sop_analyzer_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SopAnalyzerScreen(),
              ),
            );
          },
          child: const Text('Open SOP Analyzer'),
        ),
      ),
    );
  }
}

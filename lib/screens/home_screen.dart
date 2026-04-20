import 'package:flutter/material.dart';

import '../widgets/app_bottom_navigation.dart';
import 'applications_screen.dart';
import 'dashboard_screen.dart';
import 'opportunities_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onLogout,
    required this.accountName,
    required this.accountEmail,
  });

  final Future<void> Function() onLogout;
  final String accountName;
  final String accountEmail;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const DashboardScreen(),
      const ApplicationsScreen(),
      const OpportunitiesScreen(),
      ProfileScreen(
        onLogout: widget.onLogout,
        accountName: widget.accountName,
        accountEmail: widget.accountEmail,
      ),
    ];
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

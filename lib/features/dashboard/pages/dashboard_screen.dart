import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../profile/providers/profile_provider.dart';
import '../provider/check_in_provider.dart';
import '../provider/task_stats_provider.dart';
import '../widget/check_in_widget.dart';
import '../widget/greeting_card_shimmer.dart';
import '../widget/greeting_card_widget.dart';
import '../widget/task_stats_grid.dart';
import '../widget/task_stats_shimmer.dart';
import '../widget/timer_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  /// Initial load — called once on mount.
  Future<void> _loadAll() async {
    if (!mounted) return;
    await Future.wait([
      context.read<CheckInProvider>().init(),
      context.read<TaskStatsProvider>().fetch(),
    ]);
  }

  /// Pull-to-refresh — refreshes all data with shimmers.
  Future<void> _onRefresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<CheckInProvider>().refresh(),
      context.read<TaskStatsProvider>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final isProfileLoading =
        profileProvider.isLoading && profileProvider.userData == null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFC03355),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              isProfileLoading
                  ? const GreetingCardShimmer()
                  : GreetingCardWidget(profileProvider: profileProvider),
              const SizedBox(height: 16),

              const CheckInWidget(),
              const SizedBox(height: 16),
              isProfileLoading
                  ? const TaskStatsShimmer()
                  : const TaskStatsGrid(),
              const SizedBox(height: 16),
              const TimerWidget(),
              const SizedBox(height: 20),

              // Extra padding so content clears the bottom nav
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

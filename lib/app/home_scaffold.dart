import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

import '../core/const/app_colors.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/connectivity_service.dart';


import '../features/dashboard/pages/dashboard_screen.dart';
import '../features/dashboard/provider/check_in_provider.dart';
import '../features/dashboard/provider/dashboard_task_provider.dart';
import '../features/dashboard/provider/task_stats_provider.dart';
import '../features/homescreen.dart';
import '../features/tasks/pages/task_list_screen.dart';
import '../features/tasks/pages/create_task_screen.dart';
import '../features/tasks/provider/task_provider.dart';
import '../features/employee/pages/employee_list_screen.dart';
import '../features/review/services/review_service.dart';

import '../features/profile/pages/profile_screen.dart';
import '../features/profile/providers/profile_provider.dart';

import '../core/routing/page_transition.dart';
import '../features/company/providers/company_provider.dart';
import '../features/company/widgets/company_selector_widget.dart';
import '../shared/widgets/navigation/app_bottom_nav.dart';
import '../shared/widgets/snackbars/custom_snackbar.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});
  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold>
    with WidgetsBindingObserver {

  bool _isStockUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start connectivity/internet monitoring and seed current server URL
    ConnectivityService.instance.startMonitoring();
    OdooSessionManager.getCurrentSession().then((session) {
      ConnectivityService.instance.setCurrentServerUrl(session?.serverUrl);
      if (mounted) {
        setState(() {
          _isStockUser = session?.isStockUser ?? false;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ReviewService().checkAndShowRating(context);
    });

    // Ensure ProfileProvider fetches user data on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CompanyProvider>().initialize();
        context.read<ProfileProvider>().fetchUserProfile();

      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('[HomeScaffold] App resumed, validating session');
      _validateSession();
      // Refresh profile data (including avatar) when app resumes
      if (mounted) {
        context.read<ProfileProvider>().fetchUserProfile(forceRefresh: true);
      }
    }
  }

  Future<void> _validateSession() async {
    try {
      final isValid = await OdooSessionManager.isSessionValid();
      if (!isValid && mounted) {
        debugPrint('[HomeScaffold] Session invalid, redirecting to login');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/server_setup', (route) => false);
      } else if (mounted) {
        // Refresh permission check on resume
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null && session.isStockUser != _isStockUser) {
          setState(() {
            _isStockUser = session.isStockUser;
          });
        }
      }
    } catch (e) {
      debugPrint('[HomeScaffold] Error validating session: $e');
    }
  }
  int _index = 0;

  static const List<String> _titles = [
    'Dashboard', 'Task', 'Employee', 'Map', 'Time sheet',
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    TaskListScreen(),
    AssigneeListScreen(),
    Homescreen(),
    Homescreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // CompanyProvider is now provided globally in main.dart
    return Scaffold(body: _buildScreenWithAppBar(Container()));
  }

  Widget _buildScreenWithAppBar(Widget screen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _titles[_index],
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: _buildProfileActions(context),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: () async {
                final provider = context.read<TaskProvider>();
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTaskScreen(),
                  ),
                );
                if (created == true && mounted) {
                  provider.refresh();
                }
              },
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        child: AppBottomNav(
          currentIndex: _index,
          onTabSelected: (i) => setState(() => _index = i),
        ),
      ),





    );
  }

  List<Widget> _buildProfileActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      // Company selector
    CompanySelectorWidget(
      onCompanyChanged: () async {
        if (!mounted) return;

        final companyName = context.read<CompanyProvider>()
                .selectedCompany?['name']?.toString() ??
            'company';

        final checkIn = context.read<CheckInProvider>();
        final taskStats = context.read<TaskStatsProvider>();
        final dashTasks = context.read<DashboardTaskProvider>();

        // Clear stale data immediately — shimmer shows while fresh data loads
        checkIn.reset();
        taskStats.reset();
        dashTasks.refresh();

        // Trigger fresh load (IndexedStack keeps DashboardScreen alive, initState won't re-fire)
        unawaited(Future.wait([checkIn.init(), taskStats.fetch()]));

        if (!mounted) return;
        CustomSnackbar.showSuccess(context, 'Switched to $companyName');
      },
    ),
      Container(
        margin: const EdgeInsets.only(right: 8),
        child: Consumer<ProfileProvider>(
          builder: (context, profileProvider, child) {
            final userAvatar = profileProvider.userAvatar;
            final isLoading = profileProvider.isLoading && userAvatar == null;

            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('avatar_loading'),
                        width: 32,
                        height: 32,
                        child: Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                          highlightColor: isDark
                              ? Colors.grey[600]!
                              : Colors.grey[200]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : (userAvatar != null
                    ? ClipOval(
                  child: Image.memory(
                    profileProvider.userAvatar!,
                    height: 30,
                    width: 30,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor:
                        isDark ? Colors.grey[700] : Colors.grey[300],
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedUserCircle,
                          size: 30,
                          color: isDark
                              ? Colors.grey[500]
                              : Colors.grey[600],
                        ),
                      );
                    },
                  ),
                )
                          : CircleAvatar(
                              key: const ValueKey('avatar_placeholder'),
                              radius: 16,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                              child: HugeIcon(icon:
                                HugeIcons.strokeRoundedUserCircle,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 18,
                              ),
                            )),
              ),
              onPressed: () async {
                final provider = context.read<ProfileProvider>();
                await Navigator.push(
                  context,
                  dynamicRoute(context, const ProfileScreen()),
                );
                if (mounted) {
                  provider.fetchUserProfile(forceRefresh: true);
                }
              },
            );
          },
        ),
      ),
    ];
  }
}

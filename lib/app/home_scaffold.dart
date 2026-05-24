import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

import '../core/const/app_colors.dart';
import '../core/services/odoo_session_manager.dart';
import '../core/services/connectivity_service.dart';
import '../features/dashboard/provider/timesheet_provider.dart';
import '../features/dashboard/services/timesheet_service.dart';
import '../features/dashboard/widget/project_picker_sheet.dart';
import '../features/timesheet/pages/add_timesheet_screen.dart';
import '../features/timesheet/provider/timesheet_list_provider.dart';
import '../shared/widgets/snackbars/custom_snackbar.dart' show CustomSnackbar;


import '../features/dashboard/pages/dashboard_screen.dart';
import '../features/dashboard/provider/check_in_provider.dart';
import '../features/dashboard/provider/dashboard_task_provider.dart';
import '../features/dashboard/provider/task_stats_provider.dart';
import '../features/homescreen.dart';
import '../features/map/pages/map_screen.dart';
import '../features/map/provider/map_provider.dart';
import '../features/tasks/pages/task_list_screen.dart';
import '../features/tasks/pages/create_task_screen.dart';
import '../features/tasks/provider/task_provider.dart';
import '../features/employee/pages/employee_list_screen.dart';
import '../features/employee/provider/employee_provider.dart';
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
  static const List<String> _titles = [
    'Dashboard', 'Task', 'Employee', 'Map', 'Time sheet',
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    TaskListScreen(),
    AssigneeListScreen(),
    MapScreen(),
    Homescreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // CompanyProvider is now provided globally in main.dart
    return Scaffold(body: _buildScreenWithAppBar(Container()));
  }

  Widget _buildScreenWithAppBar(Widget screen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final activeIndex = mapProvider.activeHomeTab;
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              _titles[activeIndex],
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
            index: activeIndex,
            children: _screens,
          ),
          floatingActionButton: activeIndex == 0
              ? const _DashboardFab()
              : activeIndex == 1
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
                      child: const Icon(Icons.add_rounded, size: 28),
                    )
                  : activeIndex == 4
                      ? const _TimesheetFab()
                      : null,
          bottomNavigationBar: AppBottomNav(
            currentIndex: activeIndex,
            onTabSelected: (i) => mapProvider.setActiveHomeTab(i),
          ),
        );
      },
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
        final tasks = context.read<TaskProvider>();
        final employees = context.read<AssigneeProvider>();
        final mapProv = context.read<MapProvider>();
        final timesheetList = context.read<TimesheetListProvider>();

        // Clear stale data immediately — shimmer shows while fresh data loads
        checkIn.reset();
        taskStats.reset();
        dashTasks.reset();
        tasks.reset();
        employees.reset();
        timesheetList.reset();
        mapProv.resetTab();

        // Reload all data sources for the new company/account.
        // tasks/employees/timesheetList reset() triggers their screen listeners
        // to auto-call init()/fetchAssignees()/init() from Odoo.
        mapProv.refresh();
        unawaited(Future.wait([
          checkIn.init(),
          taskStats.fetch(),
          dashTasks.refresh(),
        ]));

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

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard expandable FAB
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardFab extends StatefulWidget {
  const _DashboardFab();

  @override
  State<_DashboardFab> createState() => _DashboardFabState();
}

class _DashboardFabState extends State<_DashboardFab> {
  bool _open = false;
  bool _isStarting = false;
  final _service = TimesheetService();

  void _toggle() => setState(() => _open = !_open);
  void _close() => setState(() => _open = false);

  Future<void> _onStartTimer() async {
    _close();
    final task = await ProjectPickerSheet.show(context);
    if (task == null || !mounted) return;

    setState(() => _isStarting = true);

    final timerProv = context.read<TimesheetProvider>();

    if (timerProv.isTimerRunning) {
      await timerProv.autoStopAndSaveRunningTimer();
    }

    final timesheetId = await _service.startTimer(task.id);
    if (!mounted) return;

    if (timesheetId == null) {
      setState(() => _isStarting = false);
      CustomSnackbar.showError(context, 'Could not start timer. Please try again.');
      return;
    }

    timerProv.startGlobalTimer(task, timesheetId);
    setState(() => _isStarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Option buttons
        if (_open) ...[
          _FabOption(
            label: 'Timer Recording',
            icon: Icons.play_arrow_rounded,
            isDark: isDark,
            loading: _isStarting,
            onTap: _onStartTimer,
          ),
          const SizedBox(height: 12),
          _FabOption(
            label: 'Create Task',
            icon: Icons.add_task_rounded,
            isDark: isDark,
            loading: false,
            onTap: () async {
              _close();
              final provider = context.read<TaskProvider>();
              final dashTaskProvider = context.read<DashboardTaskProvider>();
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTaskScreen(),
                ),
              );
              if (created == true && context.mounted) {
                provider.refresh();
                dashTaskProvider.refresh();
              }
            },
          ),
          const SizedBox(height: 16),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timesheet expandable FAB
// ─────────────────────────────────────────────────────────────────────────────

class _TimesheetFab extends StatefulWidget {
  const _TimesheetFab();

  @override
  State<_TimesheetFab> createState() => _TimesheetFabState();
}

class _TimesheetFabState extends State<_TimesheetFab> {
  bool _open = false;
  bool _isStarting = false;
  final _service = TimesheetService();

  void _toggle() => setState(() => _open = !_open);
  void _close() => setState(() => _open = false);

  Future<void> _onStartTimer() async {
    _close();
    final task = await ProjectPickerSheet.show(context);
    if (task == null || !mounted) return;

    setState(() => _isStarting = true);

    final timerProv = context.read<TimesheetProvider>();

    if (timerProv.isTimerRunning) {
      await timerProv.autoStopAndSaveRunningTimer();
    }

    final timesheetId = await _service.startTimer(task.id);
    if (!mounted) return;

    if (timesheetId == null) {
      setState(() => _isStarting = false);
      CustomSnackbar.showError(context, 'Could not start timer. Please try again.');
      return;
    }

    timerProv.startGlobalTimer(task, timesheetId);
    setState(() => _isStarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Option buttons
        if (_open) ...[
          _FabOption(
            label: 'Timer Recording',
            icon: Icons.play_arrow_rounded,
            isDark: isDark,
            loading: _isStarting,
            onTap: _onStartTimer,
          ),
          const SizedBox(height: 12),
          _FabOption(
            label: 'Manual Recording',
            icon: Icons.edit_note_rounded,
            isDark: isDark,
            loading: false,
            onTap: () async {
              _close();
              final saved = await AddTimesheetScreen.push(context);
              if (saved && context.mounted) {
                context.read<TimesheetListProvider>().refresh();
              }
            },
          ),
          const SizedBox(height: 16),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ],
    );
  }
}

class _FabOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final bool loading;
  final VoidCallback onTap;

  const _FabOption({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2D36) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Mini FAB
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

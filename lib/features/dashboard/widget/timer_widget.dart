import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/project_item_model.dart';
import '../services/timesheet_service.dart';
import '../provider/timesheet_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'project_picker_sheet.dart';
import 'timesheet_entry_sheet.dart';

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget>
    with SingleTickerProviderStateMixin {
  bool _isStarting = false;
  final _service = TimesheetService();
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onStart(TimesheetProvider timerProv) async {
    final task = await ProjectPickerSheet.show(context);
    if (task == null || !mounted) return;

    setState(() => _isStarting = true);

    if (timerProv.isTimerRunning) {
      await timerProv.autoStopAndSaveRunningTimer();
    }

    final timesheetId = await _service.startTimer(task.id);
    if (!mounted) return;

    if (timesheetId == null) {
      setState(() => _isStarting = false);
      CustomSnackbar.showError(
          context, 'Could not start timer. Please try again.');
      return;
    }

    timerProv.startGlobalTimer(task, timesheetId);
    setState(() => _isStarting = false);
  }

  void _onPause(TimesheetProvider timerProv) {
    timerProv.pauseGlobalTimer();
  }

  void _onResume(TimesheetProvider timerProv) {
    timerProv.resumeGlobalTimer();
  }

  Future<void> _onStop(TimesheetProvider timerProv) async {
    final task = timerProv.activeTask!;
    final timesheetId = timerProv.activeTimesheetId!;
    final elapsed = timerProv.activeElapsed;

    timerProv.clearGlobalTimer();

    if (!mounted) return;

    await TimesheetEntrySheet.show(
      context,
      task: task,
      timesheetId: timesheetId,
      elapsed: elapsed,
    );
  }

  String _formatted(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerProv = context.watch<TimesheetProvider>();

    if (!timerProv.isTimerRunning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _WorkManagementCard(
            isDark: isDark,
            icon: HugeIcons.strokeRoundedPlay,
            iconColor: primaryColor,
            title: 'Start Timer',
            subtitle: 'Start tracking time for your current project or task',
            loading: _isStarting,
            onTap: () => _onStart(timerProv),
          ),
          const SizedBox(height: 12),
          _WorkManagementCard(
            isDark: isDark,
            icon: HugeIcons.strokeRoundedClipboard,
            iconColor: const Color(0xFFF59E0B),
            title: 'Log Hours',
            subtitle: 'Manually record hours you worked earlier',
            loading: false,
            onTap: () {
              // Log Hours placeholder
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    final isRunning = !timerProv.isTimerPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 14),
        _ProjectOverviewCard(
          isDark: isDark,
          isRunning: isRunning,
          task: timerProv.activeTask,
          formatted: _formatted(timerProv.activeElapsed),
          pulseCtrl: _pulseCtrl,
          onPause: () => _onPause(timerProv),
          onResume: () => _onResume(timerProv),
          onStop: () => _onStop(timerProv),
        ),
        const SizedBox(height: 12),
        _WorkManagementCard(
          isDark: isDark,
          icon: HugeIcons.strokeRoundedClipboard,
          iconColor: const Color(0xFFF59E0B),
          title: 'Log Hours',
          subtitle: 'Manually record hours you worked earlier',
          loading: false,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _WorkManagementCard(
          isDark: isDark,
          icon: HugeIcons.strokeRoundedClipboard,
          iconColor: const Color(0xFF3B82F6),
          title: 'View Tasks',
          subtitle: 'View and manage all your assigned tasks',
          loading: false,
          onTap: () {},
        ),
      ],
    );
  }
}

// ─── Work Management Card ───────────────────────────────────────────────────

class _WorkManagementCard extends StatelessWidget {
  final bool isDark;
  final List<List<dynamic>> icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  const _WorkManagementCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: HugeIcon(
                icon: icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: iconColor, strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Project Overview card ───────────────────────

class _ProjectOverviewCard extends StatelessWidget {
  final bool isDark;
  final bool isRunning;
  final ProjectItem? task;
  final String formatted;
  final AnimationController pulseCtrl;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ProjectOverviewCard({
    required this.isDark,
    required this.isRunning,
    required this.task,
    required this.formatted,
    required this.pulseCtrl,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedHourglass,
                    size: 26,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRunning ? 'Running Timer' : 'Timer Paused',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task?.projectName.isNotEmpty == true
                          ? task!.projectName
                          : (task?.name ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isRunning)
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, _) => Opacity(
                    opacity: 0.55 + pulseCtrl.value * 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22C55E),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PAUSED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              formatted,
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: isRunning
                    ? primaryColor
                    : const Color(0xFFF59E0B),
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 3,
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (task != null)
            Center(
              child: Text(
                task!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isRunning ? onPause : onResume,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isRunning ? 'PAUSE' : 'RESUME',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onStop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'STOP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

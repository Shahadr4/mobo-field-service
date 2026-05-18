import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/project_item_model.dart';
import '../services/timesheet_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import 'project_picker_sheet.dart';
import 'timesheet_entry_sheet.dart';

enum _TimerState { idle, starting, running, paused, stopping }

class TimerWidget extends StatefulWidget {
  const TimerWidget({super.key});

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget>
    with SingleTickerProviderStateMixin {
  _TimerState _state = _TimerState.idle;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  ProjectItem? _task;
  int? _timesheetId;
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

  Future<void> _onStart() async {
    final task = await ProjectPickerSheet.show(context);
    if (task == null || !mounted) return;

    setState(() => _state = _TimerState.starting);

    final timesheetId = await _service.startTimer(task.id);
    if (!mounted) return;

    if (timesheetId == null) {
      setState(() => _state = _TimerState.idle);
      CustomSnackbar.showError(
          context, 'Could not start timer. Please try again.');
      return;
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });

    setState(() {
      _task = task;
      _timesheetId = timesheetId;
      _elapsed = Duration.zero;
      _state = _TimerState.running;
    });
  }

  void _onPause() {
    _ticker?.cancel();
    setState(() => _state = _TimerState.paused);
  }

  void _onResume() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
    setState(() => _state = _TimerState.running);
  }

  Future<void> _onStop() async {
    _ticker?.cancel();
    final task = _task!;
    final timesheetId = _timesheetId!;
    final elapsed = _elapsed;

    setState(() {
      _state = _TimerState.idle;
      _elapsed = Duration.zero;
      _task = null;
      _timesheetId = null;
    });

    if (!mounted) return;

    await TimesheetEntrySheet.show(
      context,
      task: task,
      timesheetId: timesheetId,
      elapsed: elapsed,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _formatted {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    if (_state == _TimerState.idle || _state == _TimerState.starting) {
      content = Column(
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
            loading: _state == _TimerState.starting,
            onTap: _onStart,
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
              // TODO: Implement Log Hours
            },
          ),
          const SizedBox(height: 12),

        ],
      );
    } else {
      content = Column(
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
            state: _state,
            task: _task,
            formatted: _formatted,
            pulseCtrl: _pulseCtrl,
            onPause: _onPause,
            onResume: _onResume,
            onStop: _onStop,
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

    return content;
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
  final _TimerState state;
  final ProjectItem? task;
  final String formatted;
  final AnimationController pulseCtrl;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ProjectOverviewCard({
    required this.isDark,
    required this.state,
    required this.task,
    required this.formatted,
    required this.pulseCtrl,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = state == _TimerState.running;
    final isStopping = state == _TimerState.stopping;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                      isStopping
                          ? 'Saving…'
                          : isRunning
                              ? 'Running Timer'
                              : 'Timer Paused',
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
              else if (state == _TimerState.paused)
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
            child: isStopping
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          color: primaryColor, strokeWidth: 2.5),
                    ),
                  )
                : Text(
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
                  onPressed: isStopping
                      ? null
                      : (isRunning ? _onPause : _onResume),
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
                  onPressed: isStopping ? null : _onStop,
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

  void _onPause() => onPause();
  void _onResume() => onResume();
  void _onStop() => onStop();
}

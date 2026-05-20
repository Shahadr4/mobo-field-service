import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:mobo_feild_service/features/dashboard/model/project_item_model.dart';
import 'package:mobo_feild_service/features/dashboard/widget/timesheet_entry_sheet.dart';
import 'package:mobo_feild_service/features/dashboard/services/timesheet_service.dart';
import 'package:mobo_feild_service/features/dashboard/provider/timesheet_provider.dart';

import '../../model/task_model.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

class TaskInfoCard extends StatefulWidget {
  final TaskModel task;
  final bool isDark;
  final Color stageColor;

  const TaskInfoCard({
    super.key,
    required this.task,
    required this.isDark,
    required this.stageColor,
  });

  @override
  State<TaskInfoCard> createState() => _TaskInfoCardState();
}

class _TaskInfoCardState extends State<TaskInfoCard>
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
    setState(() => _isStarting = true);

    if (timerProv.isTimerRunning) {
      await timerProv.autoStopAndSaveRunningTimer();
    }

    final timesheetId = await _service.startTimer(widget.task.id);
    if (!mounted) return;

    if (timesheetId == null) {
      setState(() => _isStarting = false);
      CustomSnackbar.showError(context, 'Could not start timer. Please try again.');
      return;
    }

    final projectItem = ProjectItem(
      id: widget.task.id,
      name: widget.task.name,
      projectName: widget.task.projectName,
      stageName: widget.task.stageName,
    );

    timerProv.startGlobalTimer(projectItem, timesheetId);
    setState(() => _isStarting = false);
  }

  Future<void> _onStop(TimesheetProvider timerProv) async {
    final timesheetId = timerProv.activeTimesheetId!;
    final elapsed = timerProv.activeElapsed;
    final projectItem = timerProv.activeTask ?? ProjectItem(
      id: widget.task.id,
      name: widget.task.name,
      projectName: widget.task.projectName,
      stageName: widget.task.stageName,
    );

    timerProv.clearGlobalTimer();

    if (!mounted) return;

    await TimesheetEntrySheet.show(
      context,
      task: projectItem,
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

  Widget _buildTimerSection(bool isDark, TimesheetProvider timerProv) {
    final isThisTaskTimerRunning = timerProv.isTimerRunning && timerProv.activeTaskId == widget.task.id;

    if (!isThisTaskTimerRunning) {
      return GestureDetector(
        onTap: _isStarting ? null : () => _onStart(timerProv),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isStarting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                _isStarting ? 'STARTING...' : 'START TIMER',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isRunning = !timerProv.isTimerPaused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHourglass,
                  size: 22,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRunning ? 'Running Timer' : 'Timer Paused',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isRunning)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, _) => Opacity(
                  opacity: 0.55 + _pulseCtrl.value * 0.45,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
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
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _formatted(timerProv.activeElapsed),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: isRunning ? primaryColor : const Color(0xFFF59E0B),
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isRunning
                    ? () => timerProv.pauseGlobalTimer()
                    : () => timerProv.resumeGlobalTimer(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isRunning ? 'PAUSE' : 'RESUME',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _onStop(timerProv),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'STOP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final stageColor = widget.stageColor;
    final task = widget.task;
    final timerProv = context.watch<TimesheetProvider>();

    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (task.stageName.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    task.stageName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stageColor,
                    ),
                  ),
                ),
            ],
          ),
          if (task.assigneeName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.assigneeName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (task.projectName.isNotEmpty)
            Text(
              task.projectName,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (task.partnerName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.partnerName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black87,
              ),
            ),
          ],
          if (task.partnerAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.partnerAddress,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
          if (task.scheduledStart.isNotEmpty || task.scheduledEnd.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (task.scheduledStart.isNotEmpty) task.scheduledStart,
                if (task.scheduledEnd.isNotEmpty) task.scheduledEnd,
              ].join(' → '),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.blue,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
          const SizedBox(height: 12),
          _buildTimerSection(isDark, timerProv),
        ],
      ),
    );
  }
}

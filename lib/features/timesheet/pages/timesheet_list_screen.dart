import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../features/dashboard/provider/timesheet_provider.dart';
import '../../../features/dashboard/widget/timesheet_entry_sheet.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../model/timesheet_entry_model.dart';
import '../provider/timesheet_list_provider.dart';
import '../widgets/timesheet_filter_sheet.dart';
import '../widgets/timesheet_list_body.dart';

class TimesheetListScreen extends StatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  State<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends State<TimesheetListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimesheetListProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<TimesheetListProvider>();
    final timerProv = context.watch<TimesheetProvider>();

    return Column(
      children: [
        _SearchBar(ctrl: _searchCtrl, isDark: isDark),
        _StatusRow(isDark: isDark, p: p),
        if (timerProv.isTimerRunning)
          _TimerBanner(
            isDark: isDark,
            timerProv: timerProv,
            onSaved: () => context.read<TimesheetListProvider>().refresh(),
          ),
        Expanded(
          child: TimesheetListBody(
            clearSearch: () => _searchCtrl.clear(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active timer banner — shown above the list when a timer is running
// ─────────────────────────────────────────────────────────────────────────────

class _TimerBanner extends StatefulWidget {
  final bool isDark;
  final TimesheetProvider timerProv;
  final VoidCallback onSaved;

  const _TimerBanner({required this.isDark, required this.timerProv, required this.onSaved});

  @override
  State<_TimerBanner> createState() => _TimerBannerState();
}

class _TimerBannerState extends State<_TimerBanner>
    with SingleTickerProviderStateMixin {
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

  String _formatted(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _onStop() async {
    final prov = widget.timerProv;
    final task = prov.activeTask!;
    final timesheetId = prov.activeTimesheetId!;
    final elapsed = prov.activeElapsed;
    prov.clearGlobalTimer();
    if (!mounted) return;
    final saved = await TimesheetEntrySheet.show(
      context,
      task: task,
      timesheetId: timesheetId,
      elapsed: elapsed,
    );
    if (saved && mounted) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final prov = widget.timerProv;
    final isDark = widget.isDark;
    final isRunning = !prov.isTimerPaused;
    final task = prov.activeTask;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task?.projectName.isNotEmpty == true
                            ? task!.projectName
                            : (task?.name ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
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
                    animation: _pulseCtrl,
                    builder: (_, _) => Opacity(
                      opacity: 0.55 + _pulseCtrl.value * 0.45,
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
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 11,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      _formatted(prov.activeElapsed),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: isRunning ? primaryColor : const Color(0xFFF59E0B),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (task != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isRunning
                        ? () => prov.pauseGlobalTimer()
                        : () => prov.resumeGlobalTimer(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onStop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
        ),
      ),
    );
  }
}



class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;

  const _SearchBar({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimesheetListProvider>();
    final hasFilter =
        p.hasActiveFilter || p.groupBy != TimesheetGroupBy.none;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2D36) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: TextField(
          controller: ctrl,
          onChanged: (v) =>
              context.read<TimesheetListProvider>().setSearch(v),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search task or description…',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            prefixIcon: GestureDetector(
              onTap: () => TimesheetFilterSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFilterHorizontal,
                  size: 22,
                  color: hasFilter
                      ? primaryColor
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 0),
            suffixIcon: ValueListenableBuilder(
              valueListenable: ctrl,
              builder: (_, val, child) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () {
                        ctrl.clear();
                        context
                            .read<TimesheetListProvider>()
                            .setSearch('');
                      },
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade400),
                    ),
            ),
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status row — active filter / group-by pill + pagination
// ─────────────────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final bool isDark;
  final TimesheetListProvider p;

  const _StatusRow({required this.isDark, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: Row(
        children: [
          if (p.hasActiveFilter)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1 active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            )
          else if (p.groupBy != TimesheetGroupBy.none)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 15,
                      color: isDark ? Colors.black : Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    p.groupBy.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'No filter applied',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          const Spacer(),
          PaginationControls(
            canGoToPreviousPage: p.canGoPrev,
            canGoToNextPage: p.canGoNext,
            onPreviousPage: () =>
                context.read<TimesheetListProvider>().prevPage(),
            onNextPage: () =>
                context.read<TimesheetListProvider>().nextPage(),
            paginationText: p.paginationText,
            isDark: isDark,
            theme: Theme.of(context),
          ),
        ],
      ),
    );
  }
}

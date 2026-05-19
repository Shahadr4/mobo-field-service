import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:shimmer/shimmer.dart';

import '../../model/task_model.dart';
import '../../services/task_service.dart';
import 'shimmer_bone.dart';

class TimesheetContent extends StatefulWidget {
  final TaskModel task;
  final bool isDark;
  const TimesheetContent({super.key, required this.task, required this.isDark});

  @override
  State<TimesheetContent> createState() => _TimesheetContentState();
}

class _TimesheetContentState extends State<TimesheetContent> {
  List<Map<String, dynamic>>? _entries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await TaskService().fetchTimesheets(widget.task.id);
    if (mounted) setState(() { _entries = data; _loading = false; });
  }

  String _fmtDate(dynamic v) {
    if (v == null || v == false) return '';
    final s = v.toString();
    if (s.length < 10) return s;
    final parts = s.substring(0, 10).split('-');
    if (parts.length < 3) return s.substring(0, 10);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    final y = parts[0];
    return '${months[(m - 1).clamp(0, 11)]} $d, $y';
  }

  String _fmtDuration(dynamic v) {
    final h = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final totalMinutes = (h * 60).round();
    final hrs  = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hrs == 0) return '${mins}m';
    if (mins == 0) return '${hrs}h';
    return '${hrs}h ${mins}m';
  }

  String _user(dynamic v) {
    if (v is List && v.length >= 2) return v[1].toString();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = widget.isDark;
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    if (_loading) return _TimesheetShimmer(isDark: isDark);

    final entries = _entries ?? [];

    if (entries.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lotties/empty ghost.json',
                  width: 130, height: 130, fit: BoxFit.contain),
              Text(
                'No timesheet entries',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalHours = entries.fold<double>(
      0,
      (sum, e) => sum + ((e['unit_amount'] is num)
          ? (e['unit_amount'] as num).toDouble()
          : double.tryParse(e['unit_amount']?.toString() ?? '') ?? 0.0),
    );

    return Column(
      children: [
        // ── Pinned header ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    )),
              ),
              Expanded(
                flex: 4,
                child: Text('Description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : Colors.black38,
                    )),
              ),
              Text('Duration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  )),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: divColor, indent: 18, endIndent: 18),

        // ── Scrollable rows ──────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, thickness: 1, color: divColor, indent: 18, endIndent: 18),
            itemBuilder: (_, i) => _TimesheetRow(
              date:     _fmtDate(entries[i]['date']),
              desc:     entries[i]['name']?.toString() == '/'
                            ? _user(entries[i]['user_id'])
                            : (entries[i]['name']?.toString() ?? ''),
              duration: _fmtDuration(entries[i]['unit_amount']),
              user:     _user(entries[i]['user_id']),
              isDark:   isDark,
            ),
          ),
        ),

        // ── Pinned total footer ──────────────────────────────────
        Divider(height: 1, thickness: 1, color: divColor),
        Container(
          color: primaryColor.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              Text(_fmtDuration(totalHours),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimesheetRow extends StatelessWidget {
  final String date;
  final String desc;
  final String duration;
  final String user;
  final bool isDark;

  const _TimesheetRow({
    required this.date,
    required this.desc,
    required this.duration,
    required this.user,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                if (user.isNotEmpty)
                  Text(user,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      )),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              desc.isNotEmpty ? desc : '—',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          Text(duration,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              )),
        ],
      ),
    );
  }
}

class _TimesheetShimmer extends StatelessWidget {
  final bool isDark;
  const _TimesheetShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBone(width: 50, height: 12, base: base),
                ShimmerBone(width: 70, height: 12, base: base),
                ShimmerBone(width: 50, height: 12, base: base),
              ],
            ),
          ),
          Divider(height: 1, color: divColor, indent: 18, endIndent: 18),
          for (int i = 0; i < 4; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBone(width: 64, height: 13, base: base),
                  ShimmerBone(width: 100, height: 13, base: base),
                  ShimmerBone(width: 40, height: 13, base: base),
                ],
              ),
            ),
            if (i < 3) Divider(height: 1, color: divColor, indent: 18, endIndent: 18),
          ],
          Divider(height: 1, color: divColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBone(width: 50, height: 13, base: base),
                ShimmerBone(width: 50, height: 13, base: base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

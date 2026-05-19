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
    return '${months[(m - 1).clamp(0, 11)]} $d, ${parts[0]}';
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

  double _toHours(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _user(dynamic v) {
    if (v is List && v.length >= 2) return v[1].toString();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

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

    final totalHours = entries.fold<double>(0, (s, e) => s + _toHours(e['unit_amount']));

    return Column(
      children: [
        _TableHeader(isDark: isDark),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final name = e['name']?.toString() ?? '';
              final desc = (name.isEmpty || name == '/') ? '' : name;
              return _TableRow(
                index:    i + 1,
                name:     _user(e['user_id']),
                date:     _fmtDate(e['date']),
                desc:     desc,
                duration: _fmtDuration(e['unit_amount']),
                isDark:   isDark,
                isLast:   i == entries.length - 1,
              );
            },
          ),
        ),
        _TotalFooter(duration: _fmtDuration(totalHours), isDark: isDark),
      ],
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final bool isDark;
  const _TableHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white54 : Colors.black54,
      letterSpacing: 0.3,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: style)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: Text('Name', style: style)),
              Expanded(flex: 3, child: Text('Date', style: style)),
              Expanded(flex: 3, child: Text('Description', style: style)),
              SizedBox(
                width: 62,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Duration', style: style),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: divColor),
      ],
    );
  }
}

// ── Single table row ──────────────────────────────────────────────────────────

class _TableRow extends StatelessWidget {
  final int index;
  final String name;
  final String date;
  final String desc;
  final String duration;
  final bool isDark;
  final bool isLast;

  const _TableRow({
    required this.index,
    required this.name,
    required this.date,
    required this.desc,
    required this.duration,
    required this.isDark,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    final cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
    final subStyle = TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white54 : Colors.black45,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // index
              SizedBox(
                width: 24,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // name
              Expanded(
                flex: 3,
                child: Text(
                  name.isNotEmpty ? name : '—',
                  style: cellStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // date
              Expanded(
                flex: 3,
                child: Text(
                  date.isNotEmpty ? date : '—',
                  style: subStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // description
              Expanded(
                flex: 3,
                child: Text(
                  desc.isNotEmpty ? desc : '—',
                  style: subStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // duration pill
              SizedBox(
                width: 62,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, color: divColor, indent: 18, endIndent: 18),
      ],
    );
  }
}

// ── Total footer ──────────────────────────────────────────────────────────────

class _TotalFooter extends StatelessWidget {
  final String duration;
  final bool isDark;
  const _TotalFooter({required this.duration, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: divColor),
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                duration,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

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
          // header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                ShimmerBone(width: 16, height: 12, base: base),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: ShimmerBone(width: 40, height: 12, base: base)),
                Expanded(flex: 3, child: ShimmerBone(width: 36, height: 12, base: base)),
                Expanded(flex: 3, child: ShimmerBone(width: 60, height: 12, base: base)),
                ShimmerBone(width: 55, height: 12, base: base),
              ],
            ),
          ),
          Divider(height: 1, color: divColor),
          // rows
          for (int i = 0; i < 4; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              child: Row(
                children: [
                  ShimmerBone(width: 16, height: 13, base: base),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: ShimmerBone(width: 70, height: 13, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 60, height: 13, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 80, height: 13, base: base)),
                  ShimmerBone(width: 44, height: 26, base: base, radius: 20),
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
                ShimmerBone(width: 40, height: 13, base: base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

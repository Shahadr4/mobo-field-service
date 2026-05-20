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
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await TaskService().fetchTimesheets(widget.task.id);
    if (mounted) {
      setState(() {
        _entries = data;
        _loading = false;
      });
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null || v == false) return '';
    final s = v.toString();
    if (s.length < 10) return s;
    final parts = s.substring(0, 10).split('-');
    if (parts.length < 3) return s.substring(0, 10);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
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
      return SingleChildScrollView(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lotties/empty ghost.json',
                  width: 100, height: 100, fit: BoxFit.contain),
              const SizedBox(height: 8),
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(true),
            trackVisibility: WidgetStateProperty.all(true),
            thickness: WidgetStateProperty.all(6),
            radius: const Radius.circular(5),
            thumbColor: WidgetStateProperty.all(
              isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            trackColor: WidgetStateProperty.all(
              isDark ? Colors.grey[800] : Colors.grey[100],
            ),
            trackBorderColor: WidgetStateProperty.all(
              isDark ? Colors.grey[700] : Colors.grey[100],
            ),
            interactive: true,
            crossAxisMargin: 4,
            mainAxisMargin: 8,
          ),
        ),
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(50),
                  1: FixedColumnWidth(150),
                  2: FixedColumnWidth(120),
                  3: FixedColumnWidth(180),
                  4: FixedColumnWidth(100),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFF8F9FA),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    children: [
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            '#',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            'Name',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            'Duration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;

                    final userName = _user(line['user_id']);
                    final dateStr = _fmtDate(line['date']);
                    final desc = line['name']?.toString() ?? '';
                    final descStr = (desc.isEmpty || desc == '/') ? '—' : desc;
                    final durationStr = _fmtDuration(line['unit_amount']);

                    return TableRow(
                      children: [
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              '${index + 1}.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              userName.isNotEmpty ? userName : '—',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              dateStr.isNotEmpty ? dateStr : '—',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              descStr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.symmetric(

                              vertical: 12,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),

                              child: Text(
                                durationStr,
                                style: const TextStyle(

                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
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

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          children: [
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
      ),
    );
  }
}

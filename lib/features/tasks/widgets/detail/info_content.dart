import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../model/task_model.dart';

String _stripHtml(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?div[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'</?(?:ul|ol)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  text = text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _fmtDate(String raw) {
  if (raw.isEmpty) return '';
  final parts = raw.split('-');
  if (parts.length < 3) return raw;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = int.tryParse(parts[1]) ?? 0;
  final d = int.tryParse(parts[2]) ?? 0;
  return '${months[(m - 1).clamp(0, 11)]} $d, ${parts[0]}';
}

class InfoContent extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const InfoContent({super.key, required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white38 : Colors.black38,
    );
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );

    final allocFmt   = task.allocatedHours > 0
        ? '${task.allocatedHours.toStringAsFixed(2)} h'
        : '';
    final deadlineFmt = task.deadline.isNotEmpty
        ? _fmtDate(task.deadline)
        : 'No deadline';
    final createdFmt  = _fmtDate(task.createDate);

    final rows = <_InfoRow>[
      if (task.projectName.isNotEmpty)
        _InfoRow('Project', task.projectName),
      _InfoRow('Deadline', deadlineFmt),
      if (createdFmt.isNotEmpty)
        _InfoRow('Created', createdFmt),
      if (allocFmt.isNotEmpty)
        _InfoRow('Allocated', allocFmt),
      _InfoRow('Under Warranty', task.underWarranty ? 'Yes' : 'No'),
      if (task.tagNames.isNotEmpty)
        _InfoRow('Tags', task.tagNames),
    ];

    final description = _stripHtml(task.description);

    if (rows.isEmpty && description.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lotties/empty ghost.json',
                  width: 130, height: 130, fit: BoxFit.contain),
              Text('No info available',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  )),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Detail rows ─────────────────────────────────────────
        for (int i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(rows[i].label, style: labelStyle),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: rows[i].label == 'Tags'
                      ? Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: rows[i]
                                  .value
                                  .split(', ')
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF2A2D36)
                                              : const Color(0xFFF1F3F5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(tag,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            )),
                                      ))
                                  .toList(),
                            )
                          : Text(rows[i].value, style: valueStyle),
                ),
              ],
            ),
          ),
        ],

        // ── Description section ──────────────────────────────────
        if (description.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text('Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 0.5,
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

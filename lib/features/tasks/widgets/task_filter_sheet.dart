import 'package:flutter/material.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../model/task_filter.dart';
import '../provider/task_provider.dart';

class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TaskProvider>(),
        child: const TaskFilterSheet(),
      ),
    );
  }

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  int _tab = 0;
  late Set<TaskFilterBy> _selectedFilters;
  late TaskGroupBy _groupBy;

  @override
  void initState() {
    super.initState();
    final p = context.read<TaskProvider>();
    _selectedFilters = {...p.selectedFilters};
    _groupBy = p.groupBy;
  }

  Future<void> _apply() async {
    final p = context.read<TaskProvider>();
    p.setGroupBy(_groupBy);
    await p.setFilters(_selectedFilters);
    if (mounted) Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _selectedFilters.clear();
      _groupBy = TaskGroupBy.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF1E2028) : const Color(0xFFF6F6F6);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // ── Title row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter & Group By',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab toggle ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2D36)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Filter',
                    selected: _tab == 0,
                    isDark: isDark,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  _TabButton(
                    label: 'Group By',
                    selected: _tab == 1,
                    isDark: isDark,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: _tab == 0
                ? _FilterBody(
                    selected: _selectedFilters,
                    isDark: isDark,
                    onToggle: (f) => setState(() {
                      _selectedFilters.contains(f)
                          ? _selectedFilters.remove(f)
                          : _selectedFilters.add(f);
                    }),
                  )
                : _GroupByBody(
                    selected: _groupBy,
                    isDark: isDark,
                    onSelect: (g) => setState(() => _groupBy = g),
                  ),
          ),

          // ── Bottom action buttons ────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1E2028) : Colors.white,
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPad),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : primaryColor,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter body ───────────────────────────────────────────────────────────────

class _FilterBody extends StatelessWidget {
  final Set<TaskFilterBy> selected;
  final bool isDark;
  final void Function(TaskFilterBy) onToggle;

  const _FilterBody({
    required this.selected,
    required this.isDark,
    required this.onToggle,
  });

  static final _sections = <(String, List<(TaskFilterBy, String)>)>[
    ('STATUS', [
      (TaskFilterBy.openTasks,   'Open Tasks'),
      (TaskFilterBy.closedTasks, 'Closed Tasks'),
      (TaskFilterBy.myTasks,     'My Tasks'),
      (TaskFilterBy.unassigned,  'Unassigned'),
    ]),
    ('STAGE', [
      (TaskFilterBy.stageNew,        'New'),
      (TaskFilterBy.stagePlanned,    'Planned'),
      (TaskFilterBy.stageInProgress, 'In Progress'),
      (TaskFilterBy.stageDone,       'Done'),
      (TaskFilterBy.stageCancelled,  'Cancelled'),
    ]),
    ('PRIORITY', [
      (TaskFilterBy.priorityHigh,   'High'),
      (TaskFilterBy.priorityMedium, 'Medium'),
      (TaskFilterBy.priorityNormal, 'Normal'),
    ]),
    ('TIME', [
      (TaskFilterBy.withDeadline, 'Has Deadline'),
      (TaskFilterBy.overdue,      'Overdue'),
      (TaskFilterBy.dueToday,     'Due Today'),
      (TaskFilterBy.dueThisWeek,  'Due This Week'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

    // All active filter items flattened across sections
    final activeItems = _sections
        .expand((s) => s.$2)
        .where((e) => selected.contains(e.$1))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active filters — flat list, no section headings
          if (activeItems.isNotEmpty) ...[
            Text(
              'Active Filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeItems.map((e) => _ActiveFilterChip(
                label: e.$2,
                onRemove: () => onToggle(e.$1),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: divColor),
            const SizedBox(height: 16),
          ],

          // Sectioned filter chips
          ..._sections.expand((section) {
            final heading = section.$1;
            final items   = section.$2;
            return [
              Text(
                heading,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: items.map((e) {
                  final isSel = selected.contains(e.$1);
                  return _FilterChip(
                    label: e.$2,
                    selected: isSel,
                    isDark: isDark,
                    onTap: () => onToggle(e.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ];
          }),
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: primaryColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: primaryColor),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? primaryColor
                : (isDark
                    ? Colors.white24
                    : Colors.black.withValues(alpha: 0.18)),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group By body ─────────────────────────────────────────────────────────────

class _GroupByBody extends StatelessWidget {
  final TaskGroupBy selected;
  final bool isDark;
  final void Function(TaskGroupBy) onSelect;

  const _GroupByBody({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  static final _items = <(TaskGroupBy, String, String)>[
    (TaskGroupBy.none,     'None',     'Display as a simple list'),
    (TaskGroupBy.stage,    'Stage',    ''),
    (TaskGroupBy.project,  'Project',  ''),
    (TaskGroupBy.priority, 'Priority', ''),
    (TaskGroupBy.deadline, 'Deadline', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group by',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ..._items.map((e) {
            final isSel = selected == e.$1;
            return Column(
              children: [
                InkWell(
                  onTap: () => onSelect(e.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        // Custom radio
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? primaryColor
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.black26),
                              width: isSel ? 6.5 : 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.$2,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              if (e.$3.isNotEmpty && isSel) ...[
                                const SizedBox(height: 3),
                                Text(
                                  e.$3,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: divColor),
              ],
            );
          }),
        ],
      ),
    );
  }
}

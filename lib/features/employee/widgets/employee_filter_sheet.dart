import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../model/employee_filter.dart';
import '../provider/employee_provider.dart';

class AssigneeFilterSheet extends StatefulWidget {
  const AssigneeFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AssigneeProvider>(),
        child: const AssigneeFilterSheet(),
      ),
    );
  }

  @override
  State<AssigneeFilterSheet> createState() => _AssigneeFilterSheetState();
}

class _AssigneeFilterSheetState extends State<AssigneeFilterSheet> {
  int _tab = 0;
  late Set<AssigneeFilterBy> _selected;
  late AssigneeGroupBy _groupBy;

  @override
  void initState() {
    super.initState();
    final p = context.read<AssigneeProvider>();
    _selected = {...p.filters};
    _groupBy = p.groupBy;
  }

  Future<void> _apply() async {
    final p = context.read<AssigneeProvider>();
    p.setGroupBy(_groupBy);
    await p.setFilters(_selected);
    if (mounted) Navigator.pop(context);
  }

  void _clearAll() => setState(() {
        _selected.clear();
        _groupBy = AssigneeGroupBy.none;
      });

  Widget _buildActionBar(BuildContext context, bool isDark) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
      ),
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
                      :primaryColor,
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
              child: const Text('Apply',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2028) : const Color(0xFFF6F6F6);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          /// Title row
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),

          /// Tab toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2D36) : Colors.white,
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
                  _TabBtn(
                      label: 'Filter',
                      selected: _tab == 0,
                      isDark: isDark,
                      onTap: () => setState(() => _tab = 0)),
                  _TabBtn(
                      label: 'Group By',
                      selected: _tab == 1,
                      isDark: isDark,
                      onTap: () => setState(() => _tab = 1)),
                ],
              ),
            ),
          ),

          /// Body
          Flexible(
            child: _tab == 0
                ? _FilterBody(
                    selected: _selected,
                    isDark: isDark,
                    onToggle: (f) => setState(() => _selected.contains(f)
                        ? _selected.remove(f)
                        : _selected.add(f)),
                  )
                : _GroupByBody(
                    selected: _groupBy,
                    isDark: isDark,
                    onSelect: (g) => setState(() => _groupBy = g),
                  ),
          ),

          /// Action Bar
          _buildActionBar(context, isDark),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label,
      required this.selected,
      required this.isDark,
      required this.onTap});

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
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white38 : Colors.black38),
              )),
        ),
      ),
    );
  }
}

class _FilterBody extends StatelessWidget {
  final Set<AssigneeFilterBy> selected;
  final bool isDark;
  final void Function(AssigneeFilterBy) onToggle;

  const _FilterBody(
      {required this.selected,
      required this.isDark,
      required this.onToggle});

  static const _items = <(AssigneeFilterBy, String)>[
    (AssigneeFilterBy.myDepartment, 'My Department'),
    (AssigneeFilterBy.myTeam, 'My Team'),
    (AssigneeFilterBy.archived, 'Archived'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeItems = _items.where((e) => selected.contains(e.$1)).toList();
    final divColor =
        isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeItems.isNotEmpty) ...[
            const Text('Active Filters',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: primaryColor)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeItems
                  .map((e) => _ActiveChip(
                      label: e.$2, onRemove: () => onToggle(e.$1)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: divColor),
            const SizedBox(height: 16),
          ],
          Text('FILTERS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _items.map((e) {
              final isSel = selected.contains(e.$1);
              return _Chip(
                  label: e.$2,
                  selected: isSel,
                  isDark: isDark,
                  onTap: () => onToggle(e.$1));
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor)),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.selected,
      required this.isDark,
      required this.onTap});

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
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87))),
          ],
        ),
      ),
    );
  }
}

class _GroupByBody extends StatelessWidget {
  final AssigneeGroupBy selected;
  final bool isDark;
  final void Function(AssigneeGroupBy) onSelect;

  const _GroupByBody(
      {required this.selected,
      required this.isDark,
      required this.onSelect});

  static const _items = <(AssigneeGroupBy, String)>[
    (AssigneeGroupBy.none, 'None'),
    (AssigneeGroupBy.department, 'Department'),
    (AssigneeGroupBy.jobTitle, 'Job Title'),
    (AssigneeGroupBy.manager, 'Manager'),
  ];

  @override
  Widget build(BuildContext context) {
    final divColor =
        isDark ? const Color(0xFF2A2D36) : const Color(0xFFF0F0F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Group by',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87)),
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
                        Text(e.$2,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
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

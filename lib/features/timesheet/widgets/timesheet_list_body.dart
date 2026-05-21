import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../model/timesheet_entry_model.dart';
import '../provider/timesheet_list_provider.dart';
import 'timesheet_card.dart';
import 'timesheet_shimmer.dart';

class TimesheetListBody extends StatelessWidget {
  final VoidCallback clearSearch;

  const TimesheetListBody({super.key, required this.clearSearch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<TimesheetListProvider>();

    Future<void> onRefresh() async {
      await p.refreshAndClearSearch();
      clearSearch();
    }

    if (p.isLoading) return TimesheetShimmerList(isDark: isDark);

    if (p.entries.isEmpty) {
      return RefreshIndicator(
        color: primaryColor,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _EmptyState(isDark: isDark),
          ),
        ),
      );
    }

    if (p.groupBy != TimesheetGroupBy.none) {
      return RefreshIndicator(
        color: primaryColor,
        onRefresh: onRefresh,
        child: _GroupedList(grouped: p.grouped, isDark: isDark),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: onRefresh,
      child: _FlatList(entries: p.entries, isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat list
// ─────────────────────────────────────────────────────────────────────────────

class _FlatList extends StatelessWidget {
  final List<TimesheetEntry> entries;
  final bool isDark;

  const _FlatList({required this.entries, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: entries.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) =>
          TimesheetCard(entry: entries[i], isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grouped list
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  final Map<String, List<TimesheetEntry>> grouped;
  final bool isDark;

  const _GroupedList({required this.grouped, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: grouped.entries
          .map((e) => _GroupSection(
                label: e.key,
                entries: e.value,
                isDark: isDark,
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group section — expandable tile (employee list pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _GroupSection extends StatefulWidget {
  final String label;
  final List<TimesheetEntry> entries;
  final bool isDark;

  const _GroupSection({
    required this.label,
    required this.entries,
    required this.isDark,
  });

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1E2028) : Colors.white;
    final divider = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    final groupHours = widget.entries.fold(0.0, (s, e) => s + e.hours);
    final h = groupHours.floor();
    final m = ((groupHours - h) * 60).round();
    final hoursLabel =
        h > 0 ? (m > 0 ? '${h}h ${m}m' : '${h}h') : '${m}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: widget.isDark ? 0.18 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Hours badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hoursLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF2A2D36)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.entries.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Animated chevron
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: widget.isDark
                            ? Colors.white38
                            : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Rows ────────────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(height: 1, thickness: 1, color: divider),
                  ...List.generate(widget.entries.length, (i) {
                    final entry = widget.entries[i];
                    final isLast = i == widget.entries.length - 1;
                    return Column(
                      children: [
                        _EntryRow(entry: entry, isDark: widget.isDark),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                            color: divider,
                          ),
                      ],
                    );
                  }),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Row inside an expandable group ───────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final TimesheetEntry entry;
  final bool isDark;

  const _EntryRow({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent dot
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.taskName.isEmpty ? 'No Task' : entry.taskName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.formattedHours,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.projectName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.projectName,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(entry.date),
                      style: TextStyle(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class TimesheetEmptyState extends StatelessWidget {
  final bool isDark;

  const TimesheetEmptyState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/lotties/empty ghost.json',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          Text(
            'No timesheets found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing here for this filter',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}

// local alias used only inside this file
class _EmptyState extends TimesheetEmptyState {
  const _EmptyState({required super.isDark});
}

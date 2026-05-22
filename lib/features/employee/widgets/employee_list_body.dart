import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../model/employee_filter.dart';
import '../model/employee_model.dart';
import '../pages/employee_detail_screen.dart';
import '../provider/employee_provider.dart';
import 'employee_card.dart';
import 'employee_shimmer.dart';

class AssigneeListBody extends StatelessWidget {
  const AssigneeListBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<AssigneeProvider>();

    if (p.isLoading) return EmployeeShimmerList(isDark: isDark);

    if (p.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: Colors.grey.shade400, size: 40),
            const SizedBox(height: 12),
            Text('Failed to load assignees',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.read<AssigneeProvider>().fetchAssignees(),
              child: const Text('Retry',
                  style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      );
    }

    if (p.assignees.isEmpty) {
      final hasFilter = p.hasActiveFilter || p.search.isNotEmpty;
      return EmptyState(
        lottieAsset: 'assets/lotties/empty ghost.json',
        title: 'No Employees Found',
        subtitle: hasFilter
            ? 'No employees match your current filter'
            : 'No employees available',
        actionLabel: hasFilter ? 'Clear Filter' : 'Retry',
        onAction: hasFilter
            ? () => context.read<AssigneeProvider>().clearFilters()
            : () => context.read<AssigneeProvider>().fetchAssignees(),
      );
    }

    final grouped = p.grouped;
    final isGrouped = p.groupBy != AssigneeGroupBy.none;

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () => context.read<AssigneeProvider>().refresh(),
      child: isGrouped
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: grouped.entries
                  .map((e) => _GroupSection(
                        label: e.key,
                        assignees: e.value,
                        isDark: isDark,
                      ))
                  .toList(),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: grouped['']?.length ?? 0,
              itemBuilder: (_, i) {
                final a = grouped['']![i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeDetailScreen(assignee: a),
                      ),
                    ),
                    child: AssigneeCard(assignee: a, isDark: isDark),
                  ),
                );
              },
            ),
    );
  }
}

// ── Group expandable tile ─────────────────────────────────────────────────────

class _GroupSection extends StatefulWidget {
  final String label;
  final List<AssigneeModel> assignees;
  final bool isDark;

  const _GroupSection({
    required this.label,
    required this.assignees,
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
            // Header
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.assignees.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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

            // Rows
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  Divider(height: 1, thickness: 1, color: divider),
                  ...List.generate(widget.assignees.length, (i) {
                    final a = widget.assignees[i];
                    final isLast = i == widget.assignees.length - 1;
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmployeeDetailScreen(assignee: a),
                            ),
                          ),
                          child: _AssigneeRow(
                              assignee: a, isDark: widget.isDark),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1,
                              thickness: 1,
                              indent: 72,
                              color: divider),
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

// ── Flat row inside group tile ────────────────────────────────────────────────

class _AssigneeRow extends StatelessWidget {
  final AssigneeModel assignee;
  final bool isDark;

  const _AssigneeRow({required this.assignee, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final subtitleColor = isDark ? Colors.white38 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AssigneeAvatar(assignee: assignee, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        assignee.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (assignee.jobTitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          assignee.jobTitle,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (assignee.phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(assignee.phone,
                      style:
                          TextStyle(fontSize: 12, color: subtitleColor)),
                ],
                if (assignee.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(assignee.email,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: subtitleColor)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

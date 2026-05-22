import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../model/task_filter.dart';
import '../provider/task_provider.dart';
import '../widgets/task_list_body.dart';
import '../widgets/task_search_bar.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const _TaskListScreenWrapper());

  @override
  Widget build(BuildContext context) => const _TaskListScreenWrapper();
}

class _TaskListScreenWrapper extends StatelessWidget {
  const _TaskListScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return const _TaskListView();
  }
}

class _TaskListView extends StatefulWidget {
  const _TaskListView();

  @override
  State<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<_TaskListView> {
  final _searchCtrl = TextEditingController();
  late final TaskProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<TaskProvider>();
    _provider.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_provider.tasks.isEmpty && !_provider.isLoading) {
        _provider.init();
      }
    });
  }

  void _onProviderChanged() {
    // When reset() clears tasks and loading stops, re-fetch from Odoo
    if (_provider.tasks.isEmpty && !_provider.isLoading && _provider.error == null) {
      _provider.init();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p      = context.watch<TaskProvider>();

    final isMyTasks = p.selectedFilters.contains(TaskFilterBy.myTasks);

    return Column(
      children: [
        TaskSearchBar(ctrl: _searchCtrl, isDark: isDark),
        // ── My / All toggle ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CapsuleTab(
                    label: 'My',
                    selected: isMyTasks,
                    isDark: isDark,
                    onTap: () {
                      if (!isMyTasks) {
                        context.read<TaskProvider>().toggleMyTasks(true);
                      }
                    },
                  ),
                  _CapsuleTab(
                    label: 'All',
                    selected: !isMyTasks,
                    isDark: isDark,
                    onTap: () {
                      if (isMyTasks) {
                        context.read<TaskProvider>().toggleMyTasks(false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
          child: Row(
            children: [
              // ── Filter status indicator ──────────────────────────
              if (p.selectedFilters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.selectedFilters.length} active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
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
              // ── Pagination controls ──────────────────────────────
              PaginationControls(
                canGoToPreviousPage: p.canGoPrev,
                canGoToNextPage:     p.canGoNext,
                onPreviousPage:      () => context.read<TaskProvider>().prevPage(),
                onNextPage:          () => context.read<TaskProvider>().nextPage(),
                paginationText:      p.paginationText,
                isDark:              isDark,
                theme:               Theme.of(context),
              ),
            ],
          ),
        ),
        const Expanded(child: TaskListBody()),
      ],
    );
  }
}

class _CapsuleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _CapsuleTab({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

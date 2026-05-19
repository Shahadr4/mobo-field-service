import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/pagination/pagination_controls.dart';
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
    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..init(),
      child: const _TaskListView(),
    );
  }
}

class _TaskListView extends StatefulWidget {
  const _TaskListView();

  @override
  State<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<_TaskListView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p      = context.watch<TaskProvider>();

    return Column(
      children: [
        TaskSearchBar(ctrl: _searchCtrl, isDark: isDark),
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
                    borderRadius: BorderRadius.circular(20),
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

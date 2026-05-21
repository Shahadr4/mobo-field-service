import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../model/timesheet_entry_model.dart';
import '../provider/timesheet_list_provider.dart';
import '../widgets/timesheet_filter_sheet.dart';
import '../widgets/timesheet_list_body.dart';

class TimesheetListScreen extends StatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  State<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends State<TimesheetListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimesheetListProvider>().init();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.watch<TimesheetListProvider>();

    return Column(
      children: [
        _SearchBar(ctrl: _searchCtrl, isDark: isDark),
        _StatusRow(isDark: isDark, p: p),
        Expanded(
          child: TimesheetListBody(
            clearSearch: () => _searchCtrl.clear(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar — filter icon as prefix, clear button as suffix
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;

  const _SearchBar({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimesheetListProvider>();
    final hasFilter =
        p.hasActiveFilter || p.groupBy != TimesheetGroupBy.none;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2D36) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: TextField(
          controller: ctrl,
          onChanged: (v) =>
              context.read<TimesheetListProvider>().setSearch(v),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search task or description…',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            prefixIcon: GestureDetector(
              onTap: () => TimesheetFilterSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFilterHorizontal,
                  size: 22,
                  color: hasFilter
                      ? primaryColor
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 0),
            suffixIcon: ValueListenableBuilder(
              valueListenable: ctrl,
              builder: (_, val, child) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () {
                        ctrl.clear();
                        context
                            .read<TimesheetListProvider>()
                            .setSearch('');
                      },
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade400),
                    ),
            ),
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status row — active filter / group-by pill + pagination
// ─────────────────────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final bool isDark;
  final TimesheetListProvider p;

  const _StatusRow({required this.isDark, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: Row(
        children: [
          if (p.hasActiveFilter)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1 active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            )
          else if (p.groupBy != TimesheetGroupBy.none)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 15,
                      color: isDark ? Colors.black : Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    p.groupBy.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
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
          PaginationControls(
            canGoToPreviousPage: p.canGoPrev,
            canGoToNextPage: p.canGoNext,
            onPreviousPage: () =>
                context.read<TimesheetListProvider>().prevPage(),
            onNextPage: () =>
                context.read<TimesheetListProvider>().nextPage(),
            paginationText: p.paginationText,
            isDark: isDark,
            theme: Theme.of(context),
          ),
        ],
      ),
    );
  }
}

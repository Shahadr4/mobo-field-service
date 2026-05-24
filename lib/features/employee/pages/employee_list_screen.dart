import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/pagination/pagination_controls.dart';
import '../model/employee_filter.dart';
import '../provider/employee_provider.dart';
import '../widgets/employee_filter_sheet.dart';
import '../widgets/employee_list_body.dart';

class AssigneeListScreen extends StatefulWidget {
  const AssigneeListScreen({super.key});

  @override
  State<AssigneeListScreen> createState() => _AssigneeListScreenState();
}

class _AssigneeListScreenState extends State<AssigneeListScreen> {
  final _searchCtrl = TextEditingController();
  late final AssigneeProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AssigneeProvider>();
    _provider.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_provider.assignees.isEmpty && !_provider.isLoading) {
        _provider.fetchAssignees();
      }
    });
  }

  void _onProviderChanged() {
    if (!_provider.hasFetched && !_provider.isLoading && _provider.error == null) {
      _provider.fetchAssignees();
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
    final p = context.watch<AssigneeProvider>();

    return Column(
      children: [
        _SearchBar(ctrl: _searchCtrl, isDark: isDark),

        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
          child: Row(
            children: [
              if (p.filters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.filters.length}  active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                )
                else if (p.groupBy != AssigneeGroupBy.none)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                      Icon(
                      Icons.layers_outlined,
                      size: 15,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                        SizedBox(width: 5,),
                        Text(
                          '${p.groupBy.label}',
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
                    context.read<AssigneeProvider>().prevPage(),
                onNextPage: () =>
                    context.read<AssigneeProvider>().nextPage(),
                paginationText: p.paginationText,
                isDark: isDark,
                theme: Theme.of(context),
              ),
            ],
          ),
        ),

        const Expanded(child: AssigneeListBody()),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;

  const _SearchBar({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasFilter = context.watch<AssigneeProvider>().hasActiveFilter;

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
          onChanged: (v) => context.read<AssigneeProvider>().setSearch(v),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search assignees',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            prefixIcon: GestureDetector(
              onTap: () => AssigneeFilterSheet.show(context),
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
                        context.read<AssigneeProvider>().setSearch('');
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

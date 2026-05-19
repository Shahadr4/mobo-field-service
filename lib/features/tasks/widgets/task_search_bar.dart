import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:provider/provider.dart';

import '../provider/task_provider.dart';
import 'task_filter_sheet.dart';

class TaskSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;

  const TaskSearchBar({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasFilter = context.watch<TaskProvider>().hasActiveFilter;

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
          onChanged: (v) => context.read<TaskProvider>().setSearch(v),
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: 'Search by task name',
            hintStyle: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            // ── Filter icon with active dot ───────────────────────
            prefixIcon: GestureDetector(
              onTap: () => TaskFilterSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedFilterHorizontal,
                      size: 22,
                      color: hasFilter
                          ? primaryColor
                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                    ),

                  ],
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 0),
            suffixIcon: ValueListenableBuilder(
              valueListenable: ctrl,
              builder: (_, val, _) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () {
                        ctrl.clear();
                        context.read<TaskProvider>().setSearch('');
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

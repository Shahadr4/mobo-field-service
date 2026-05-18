import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../provider/task_provider.dart';

class TaskSearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;

  const TaskSearchBar({super.key, required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1E2028) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: ctrl,
        onChanged: (v) => context.read<TaskProvider>().setSearch(v),
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Search tasks…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ),
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
                        size: 18, color: Colors.grey.shade400),
                  ),
          ),
          filled: true,
          fillColor: isDark
              ? const Color(0xFF2A2D36)
              : const Color(0xFFF5F5F7),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

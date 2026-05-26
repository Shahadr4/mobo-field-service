import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';
import '../provider/map_provider.dart';

/// ── Map / List view toggle button ─────────────────────────────────────────────

class MapViewToggle extends StatelessWidget {
  final bool isMap;
  final bool isDark;
  final VoidCallback onToggle;

  const MapViewToggle({
    super.key,
    required this.isMap,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMap ? Icons.list_rounded : Icons.map_outlined,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              isMap ? 'List' : 'Map',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Top bar (shared between map & list view) ──────────────────────────────────

class MapTopBar extends StatelessWidget {
  final MapProvider provider;
  final bool isDark;

  const MapTopBar({super.key, required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = provider.filteredTasks.length;
    final isMap = !provider.isListMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMapsLocation01,
                color: primaryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Tasks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  total == 0
                      ? 'No tasks assigned'
                      : '$total task${total == 1 ? '' : 's'} assigned',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          MapViewToggle(
            isMap: isMap,
            isDark: isDark,
            onToggle: () => provider.setViewMode(
              isMap ? MapViewMode.list : MapViewMode.map,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: provider.refresh,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 17,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

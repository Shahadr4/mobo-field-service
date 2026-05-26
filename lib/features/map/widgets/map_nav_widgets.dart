import 'package:flutter/material.dart';

import '../../../core/const/app_colors.dart';
import '../../dashboard/model/dashboard_task_model.dart';
import 'map_shared_widgets.dart';

/// ── Navigation top banner ─────────────────────────────────────────────────────

class MapNavTopBanner extends StatelessWidget {
  final DashboardTask? task;
  final double distanceMeters;
  final double durationSeconds;
  final bool isDark;
  final VoidCallback onClose;

  const MapNavTopBanner({
    super.key,
    required this.task,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.isDark,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final eta = formatEta(durationSeconds);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.navigation_rounded, color: Color(0xFF22C55E), size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      formatDuration(durationSeconds),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${formatDistance(distanceMeters)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    if (eta.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ETA $eta',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  task?.partnerName.isNotEmpty == true
                      ? task!.partnerName
                      : (task?.partnerAddress ?? 'Destination'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
            tooltip: 'Stop navigation',
          ),
        ],
      ),
    );
  }
}

/// ── Navigation bottom bar ─────────────────────────────────────────────────────

class MapNavBottomBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onStop;
  final VoidCallback onExternal;

  const MapNavBottomBar({
    super.key,
    required this.isDark,
    required this.onStop,
    required this.onExternal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop Navigation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onExternal,
            icon: const Icon(Icons.assistant_direction_rounded, size: 18),
            label: const Text('Open in Google Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

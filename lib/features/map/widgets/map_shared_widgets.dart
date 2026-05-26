import 'package:flutter/material.dart';

import '../../../core/const/app_colors.dart';

/// ── Format helpers ────────────────────────────────────────────────────────────

String formatDistance(double meters) {
  if (meters <= 0) return '—';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

String formatDuration(double seconds) {
  if (seconds <= 0) return '—';
  final mins = (seconds / 60).round();
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatEta(double seconds) {
  if (seconds <= 0) return '';
  final arrival = DateTime.now().add(Duration(seconds: seconds.round()));
  final h = arrival.hour;
  final m = arrival.minute.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final hr12 = h % 12 == 0 ? 12 : h % 12;
  return '$hr12:$m $suffix';
}

bool isOverdue(String deadline) {
  final d = DateTime.tryParse(deadline);
  return d != null && d.isBefore(DateTime.now());
}

Color stageColor(String stage) {
  final s = stage.toLowerCase();
  if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
  if (s.contains('done') || s.contains('complete')) return const Color(0xFF22C55E);
  if (s.contains('cancel')) return const Color(0xFFEF4444);
  if (s.contains('plan')) return const Color(0xFFF59E0B);
  if (s.contains('new')) return const Color(0xFF3B82F6);
  return primaryColor;
}

/// ── StageBadge ────────────────────────────────────────────────────────────────

class MapStageBadge extends StatelessWidget {
  final String label;
  final Color color;

  const MapStageBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// ── InfoChip ──────────────────────────────────────────────────────────────────

class MapInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final bool accent;
  final int maxLines;

  const MapInfoChip({
    super.key,
    required this.icon,
    required this.text,
    required this.isDark,
    this.accent = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = accent
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white70 : Colors.black54);
    final bgColor = accent
        ? const Color(0xFFEF4444).withValues(alpha: 0.08)
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.04));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── InfoRow ───────────────────────────────────────────────────────────────────

class MapInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final Color? textColor;
  final int maxLines;

  const MapInfoRow({
    super.key,
    required this.icon,
    required this.text,
    required this.isDark,
    this.textColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? (isDark ? Colors.white54 : Colors.black54);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// ── OpenTaskButton ────────────────────────────────────────────────────────────

class MapOpenTaskButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const MapOpenTaskButton({super.key, required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        children: [
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, size: 16),
                SizedBox(width: 6),
                Text('Open Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ── NavigateButton ────────────────────────────────────────────────────────────

class MapNavigateButton extends StatelessWidget {
  final VoidCallback onTap;

  const MapNavigateButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: primaryColor,
          elevation: 0,
          side: const BorderSide(color: primaryColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(44),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_rounded, size: 16),
            SizedBox(width: 6),
            Text('Start', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

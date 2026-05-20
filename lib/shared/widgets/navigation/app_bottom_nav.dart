import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Navigation items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                label: 'Dashboard',
                icon: HugeIcons.strokeRoundedHome01,
                isActive: currentIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _NavItem(
                label: 'Task',
                icon: HugeIcons.strokeRoundedClipboard,
                isActive: currentIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              _NavItem(
                label: 'Employee',
                icon: HugeIcons.strokeRoundedUserGroup,
                isActive: currentIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _NavItem(
                label: 'Map',
                icon: HugeIcons.strokeRoundedLocation01,
                isActive: currentIndex == 3,
                onTap: () => onTabSelected(3),
              ),
              _NavItem(
                label: 'Timesheet',
                icon: HugeIcons.strokeRoundedClock01,
                isActive: currentIndex == 4,
                onTap: () => onTabSelected(4),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator line (Thick and Rounded)
            Container(
              width: 70,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),
            HugeIcon(
              icon: icon,
              color: isActive
                  ? primary
                  : (isDark ? Colors.white38 : const Color(0xFF9E9E9E)),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? primary
                    : (isDark ? Colors.white38 : const Color(0xFF9E9E9E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

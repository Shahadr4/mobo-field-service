import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onScanPressed;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onScanPressed,
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
                label: 'Operations',
                icon: HugeIcons.strokeRoundedPackage,
                isActive: currentIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              const SizedBox(width: 80), // Space for FAB
              _NavItem(
                label: 'Count Inventory',
                icon: HugeIcons.strokeRoundedTask01,
                isActive: currentIndex == 2,
                onTap: () => onTabSelected(2),
              ),
            ],
          ),

          // Center Scan button with Halo
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White Halo
                  Container(
                    height: 90,
                    width: 90,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Red FAB
                  GestureDetector(
                    onTap: onScanPressed,
                    child: Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  static const _items = [
    (icon: HugeIcons.strokeRoundedDashboardSquare02, label: 'Dashboard'),
    (icon: HugeIcons.strokeRoundedTask01,            label: 'Task'),
    (icon: HugeIcons.strokeRoundedUserGroup,         label: 'Employee'),
    (icon: HugeIcons.strokeRoundedLocation01,        label: 'Map'),
    (icon: HugeIcons.strokeRoundedClock01,           label: 'Timesheet'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1C23) : Colors.white;

    return SnakeNavigationBar.color(
      height: 64,
      elevation: 8,
      shadowColor: Colors.black26,
      behaviour: SnakeBarBehaviour.pinned,
      snakeShape: SnakeShape.indicator,

      backgroundColor: bgColor,
      snakeViewColor: isDark ? Colors.white : primaryColor,
      selectedItemColor: isDark ? Colors.white : primaryColor,
      unselectedItemColor:
          isDark ? Colors.white38 : const Color(0xFF9E9E9E),
      selectedLabelStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
      unselectedLabelStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      currentIndex: currentIndex,
      onTap: onTabSelected,
      items: List.generate(_items.length, (i) {
        final e = _items[i];
        final isActive = i == currentIndex;
        return BottomNavigationBarItem(
          icon: HugeIcon(
            icon: e.icon,
            color: isActive
                ? (isDark ? Colors.white : primaryColor)
                : (isDark ? Colors.white38 : const Color(0xFF9E9E9E)),
            size: 26,
          ),
          label: e.label,
        );
      }),
    );
  }
}

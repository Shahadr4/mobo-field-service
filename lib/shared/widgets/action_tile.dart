import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = destructive
        ? const Color(0xFFD32F2F)
        : (isDark ? Colors.white : Colors.black87);
    final Color iconColor = destructive
        ? const Color(0xFFD32F2F)
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return ListTile(
      leading: HugeIcon(icon: icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

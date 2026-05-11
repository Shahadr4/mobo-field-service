import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final List<Widget> children;
  final Widget? headerTrailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon(icon, size: 20, color: Theme.of(context).primaryColor),
                // const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (headerTrailing != null) ...[
                  // const Spacer(),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          // Divider(height: 1, color: borderColor),
          ...children,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../model/employee_model.dart';
import '../employee_card.dart';

class EmployeeHeroCard extends StatelessWidget {
  final AssigneeModel assignee;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const EmployeeHeroCard({
    super.key,
    required this.assignee,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AssigneeAvatar(assignee: assignee, size: 88),
          const SizedBox(height: 14),
          Text(
            assignee.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (assignee.jobTitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                assignee.jobTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
          if (assignee.department.isNotEmpty || assignee.manager.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                if (assignee.department.isNotEmpty)
                  _MetaChip(
                    icon: Icons.business_outlined,
                    label: assignee.department,
                    isDark: isDark,
                  ),
                if (assignee.manager.isNotEmpty)
                  _MetaChip(
                    icon: Icons.person_outline_rounded,
                    label: assignee.manager,
                    isDark: isDark,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

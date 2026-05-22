import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/const/app_colors.dart';
import '../../model/employee_model.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

class EmployeeContactCard extends StatelessWidget {
  final AssigneeModel assignee;
  final bool isDark;
  final Color cardBg;
  final BoxShadow shadow;

  const EmployeeContactCard({
    super.key,
    required this.assignee,
    required this.isDark,
    required this.cardBg,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final hasEmail = assignee.email.isNotEmpty;
    final hasPhone = assignee.phone.isNotEmpty;
    if (!hasEmail && !hasPhone) return const SizedBox.shrink();

    final labelColor = isDark ? Colors.white38 : Colors.black38;
    final valueColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [shadow],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          if (hasEmail)
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: assignee.email,
              labelColor: labelColor,
              valueColor: valueColor,
              isDark: isDark,
              onTap: () {
                Clipboard.setData(ClipboardData(text: assignee.email));
                CustomSnackbar.showSuccess(
                    context, 'Email copied to clipboard');
              },
            ),
          if (hasEmail && hasPhone)
            Divider(
              height: 1,
              thickness: 1,
              indent: 66,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          if (hasPhone)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: assignee.phone,
              labelColor: labelColor,
              valueColor: valueColor,
              isDark: isDark,
              onTap: () {
                Clipboard.setData(ClipboardData(text: assignee.phone));
                CustomSnackbar.showSuccess(
                    context, 'Phone copied to clipboard');
              },
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 15, color: labelColor),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/const/app_colors.dart';
import '../model/employee_model.dart';
import '../widgets/employee_card.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final AssigneeModel assignee;

  const EmployeeDetailScreen({super.key, required this.assignee});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
      blurRadius: 14,
      offset: const Offset(0, 4),
    );
    final labelColor = isDark ? Colors.white38 : Colors.black38;
    final valueColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        title: Text(
          'Employee Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero card ──────────────────────────────────────────────
            Container(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF22C55E).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF22C55E)
                              .withValues(alpha: 0.20),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [shadow],
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (assignee.email.isNotEmpty)
                    _InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: assignee.email,
                      labelColor: labelColor,
                      valueColor: valueColor,
                      isDark: isDark,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: assignee.email));
                        CustomSnackbar.showSuccess(
                            context, 'Email copied to clipboard');
                      },
                    ),
                  if (assignee.email.isNotEmpty && assignee.phone.isNotEmpty)
                    _Divider(isDark: isDark),
                  if (assignee.phone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: assignee.phone,
                      labelColor: labelColor,
                      valueColor: valueColor,
                      isDark: isDark,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: assignee.phone));
                        CustomSnackbar.showSuccess(
                            context, 'Phone copied to clipboard');
                      },
                    ),
                  if (assignee.phone.isNotEmpty &&
                      assignee.department.isNotEmpty)
                    _Divider(isDark: isDark),
                  if (assignee.department.isNotEmpty)
                    _InfoRow(
                      icon: Icons.business_outlined,
                      label: 'Department',
                      value: assignee.department,
                      labelColor: labelColor,
                      valueColor: valueColor,
                      isDark: isDark,
                    ),
                  if (assignee.department.isNotEmpty &&
                      assignee.manager.isNotEmpty)
                    _Divider(isDark: isDark),
                  if (assignee.manager.isNotEmpty)
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Manager',
                      value: assignee.manager,
                      labelColor: labelColor,
                      valueColor: valueColor,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final bool isDark;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.isDark,
    this.onTap,
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
            if (onTap != null)
              Icon(
                Icons.copy_rounded,
                size: 15,
                color: labelColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}

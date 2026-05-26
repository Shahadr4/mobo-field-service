import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/const/app_colors.dart';
import '../model/employee_model.dart';

class AssigneeCard extends StatelessWidget {
  final AssigneeModel assignee;
  final bool isDark;

  const AssigneeCard({super.key, required this.assignee, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final nameColor = isDark ? Colors.white : Colors.black87;
    final metaColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Dynamic Top-Aligned Avatar with a premium border-radius
          AssigneeAvatar(assignee: assignee, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Name and Job Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        assignee.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: nameColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (assignee.jobTitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.20),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          assignee.jobTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                /// Metadata Rows with larger icons and beautifully spaced typography
                if (assignee.phone.isNotEmpty)
                  _MetaRow(
                    icon: Icons.phone_outlined,
                    label: assignee.phone,
                    color: metaColor,
                  ),

                if (assignee.email.isNotEmpty) ...[
                  if (assignee.phone.isNotEmpty) const SizedBox(height: 8),
                  _MetaRow(
                    icon: Icons.mail_outline_rounded,
                    label: assignee.email,
                    color: metaColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Meta row ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// ── Avatar ────────────────────────────────────────────────────────────────────

class AssigneeAvatar extends StatelessWidget {
  final AssigneeModel assignee;
  final double size;

  const AssigneeAvatar({super.key, required this.assignee, required this.size});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    if (assignee.avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          Uint8List.fromList(assignee.avatar),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => _Initials(name: assignee.name, size: size),
        ),
      );
    }
    return _Initials(name: assignee.name, size: size);
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;
  const _Initials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: primaryColor,
        ),
      ),
    );
  }
}

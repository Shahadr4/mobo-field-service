import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Common, theme-aware popup dialog used across the app
/// Supports: title, description, optional input field, 1-2 action buttons, and optional leading icon.
class CommonDialog extends StatelessWidget {
  final String title;
  final String? message;
  final List<List<dynamic>>? icon;
  final bool showInput;
  final String? inputHint;
  final TextEditingController? controller;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructivePrimary;
  /// When true, renders the icon at the top center with centered title/message
  /// to match the app's confirmation/discard dialog design.
  final bool topIconCentered;
  /// Optional custom body placed between the header and action buttons
  final Widget? body;

  const CommonDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.showInput = false,
    this.inputHint,
    this.controller,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructivePrimary = false,
    this.topIconCentered = false,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;

    final primaryBg =  primary;
    final primaryFg = Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (topIconCentered) ...[
              if (icon != null) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:  primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),

                    ),
                    child: HugeIcon(
                     icon:  icon!,
                      size: 26,
                      color: destructivePrimary ? Colors.red : primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (destructivePrimary ? Colors.red : primary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (destructivePrimary ? Colors.red : primary).withOpacity(0.2),
                        ),
                      ),
                      child: HugeIcon(
                       icon:  icon!,
                        size: 20,
                        color: destructivePrimary ? Colors.red : primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null && message!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ],
            if (body != null) ...[
              const SizedBox(height: 12),
              body!,
            ],
            if (showInput) ...[
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: inputHint ?? 'Placeholder',
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (secondaryLabel != null && onSecondary != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: Text(
                        secondaryLabel!,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBg,
                      foregroundColor: primaryFg,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helpers
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
        List<List<dynamic>>? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        primaryLabel: confirmText,
        onPrimary: () => Navigator.of(ctx).pop(true),
        secondaryLabel: cancelText,
        onSecondary: () => Navigator.of(ctx).pop(false),
        destructivePrimary: destructive,
      ),
    );
  }

  static Future<String?> prompt(
    BuildContext context, {
    required String title,
    String? message,
    String placeholder = 'Enter value',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
        List<List<dynamic>>? icon,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => CommonDialog(
        title: title,
        message: message,
        icon: icon,
        showInput: true,
        controller: controller,
        inputHint: placeholder,
        primaryLabel: confirmText,
        onPrimary: () => Navigator.of(ctx).pop(controller.text.trim()),
        secondaryLabel: cancelText,
        onSecondary: () => Navigator.of(ctx).pop(null),
      ),
    );
  }
}

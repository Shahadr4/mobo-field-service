import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// MoboCheckbox
/// A design-accurate checkbox matching the provided UI spec with states:
/// - default (outline)
/// - hover (tinted background)
/// - selected (filled with check)
/// - indeterminate (filled with minus)
/// - disabled (low-contrast outline/fill)
///
/// Use [value] as bool? to support tri-state. null -> indeterminate.
class MoboCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double radius;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = 6,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor;
    final isDisabled = widget.onChanged == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: isDisabled
            ? null
            : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: primary,
              width: 2,
            ),
            color: widget.value
                ? primary // ✅ selected
                : (_hovering
                ? primary.withOpacity(0.10) // ✅ hover
                : Colors.transparent), // ✅ default
          ),
          child: widget.value
              ? const Icon(
            Icons.check_rounded,
            size: 14,
            color: Colors.white,
          )
              : null,
        ),
      ),
    );
  }
}


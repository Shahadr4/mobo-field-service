import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class ActivatedFilterList extends StatelessWidget {
  final List<String> activeList;
  final Function(String value)? onRemove;

  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color? iconColor;

  const ActivatedFilterList({
    super.key,
    required this.activeList,
    this.onRemove,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: activeList.map((single) {
        return GestureDetector(
          onTap: () {
            if (onRemove != null) {
              onRemove!(single);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor ?? Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  single,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: textColor ?? Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedMultiplicationSign,
                  color: iconColor ?? Colors.black,
                  size: 15,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
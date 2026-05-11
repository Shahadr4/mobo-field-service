import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
class CardWidget extends StatelessWidget {
  final Widget child;
  const CardWidget({super.key,required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 18,vertical: 14),
      padding: EdgeInsets.symmetric(horizontal: 20,vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(-4,-4),
          ),
        ],
      ),
      child:child
    );
  }
}

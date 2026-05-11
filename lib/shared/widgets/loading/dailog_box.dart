import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';

dialogBox(
    BuildContext context,
    String title,
    Widget icon,
    Widget child,
    ) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// ICON CIRCLE
              Container(
                height: 60,
                width: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? primaryColor.withOpacity(0.25)
                      : primaryColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),

              const SizedBox(height: 20),


              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 10),
              DefaultTextStyle(
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                child: child,
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:shimmer/shimmer.dart';

import '../../model/task_model.dart';
import 'shimmer_bone.dart';

class TaskHoursBottomSheet extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const TaskHoursBottomSheet({super.key, required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg         = isDark ? const Color(0xFF1E2028) :  primaryColor.withAlpha(10);
    final labelColor = isDark ? Colors.white54 : Colors.black;
    final valueColor = isDark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
        boxShadow: [

        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Allocated Hours',
                      style: TextStyle(color: labelColor, fontWeight: FontWeight.w500)),
                  Text(task.allocatedHours.toStringAsFixed(2),
                      style: TextStyle(color: valueColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Effective Hours',
                      style: TextStyle(color: labelColor, fontWeight: FontWeight.w500)),
                  Text(task.effectiveHours.toStringAsFixed(2),
                      style: TextStyle(color: valueColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              color: primaryColor,
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining Hours',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(task.remainingHours.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskHoursBottomSheetShimmer extends StatelessWidget {
  final bool isDark;
  const TaskHoursBottomSheetShimmer({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base      = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final bg        = isDark ? const Color(0xFF1E2028) : Colors.white;
    final divColor  = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        color: bg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBone(width: 120, height: 14, base: base),
                    ShimmerBone(width: 40, height: 14, base: base),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: divColor, indent: 20, endIndent: 20),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBone(width: 110, height: 14, base: base),
                    ShimmerBone(width: 40, height: 14, base: base),
                  ],
                ),
              ),
              Container(
                color: primaryColor.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBone(width: 130, height: 16, base: Colors.white24),
                    ShimmerBone(width: 40, height: 16, base: Colors.white24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

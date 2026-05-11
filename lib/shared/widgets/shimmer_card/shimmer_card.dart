import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FullCardShimmer extends StatelessWidget {
  final double height;
  final double radius;

  const FullCardShimmer({
    super.key,
    this.height = 120,
    this.radius = 12
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

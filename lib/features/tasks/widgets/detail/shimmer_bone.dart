import 'package:flutter/material.dart';

class ShimmerBone extends StatelessWidget {
  final double width;
  final double height;
  final Color base;
  final double radius;

  const ShimmerBone({
    super.key,
    required this.width,
    required this.height,
    required this.base,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

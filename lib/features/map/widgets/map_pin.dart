import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/const/app_colors.dart';

/// ── Pin shape ─────────────────────────────────────────────────────────────────

class MapPinShape extends StatelessWidget {
  final bool isSelected;
  final Widget child;
  final int? badge;

  const MapPinShape({
    super.key,
    required this.isSelected,
    required this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: MapPinPainter(isSelected: isSelected),
          child: Padding(
            padding: EdgeInsets.only(bottom: isSelected ? 18 : 15),
            child: Center(child: child),
          ),
        ),
        if (badge != null && badge! > 1)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  badge! > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MapPinPainter extends CustomPainter {
  final bool isSelected;
  const MapPinPainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final fillColor = isSelected ? primaryColor : Colors.white;
    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 0 : 2.5;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final cx = size.width / 2;
    final headR = size.width * 0.42;
    final tipY = size.height - 2;
    final headCY = headR + (isSelected ? 2.0 : 1.5);

    final path = ui.Path();
    path.addOval(Rect.fromCircle(center: Offset(cx, headCY), radius: headR));
    path.moveTo(cx - headR * 0.35, headCY + headR * 0.75);
    path.quadraticBezierTo(cx, tipY + 2, cx + headR * 0.35, headCY + headR * 0.75);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawPath(path, paint);
    if (!isSelected) canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(MapPinPainter old) => old.isSelected != isSelected;
}

/// ── Destination pin ───────────────────────────────────────────────────────────

class MapDestinationPinChild extends StatelessWidget {
  const MapDestinationPinChild({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.flag_rounded, size: 18, color: Colors.white);
  }
}

/// ── Cluster pin child ─────────────────────────────────────────────────────────

class MapClusterPinChild extends StatelessWidget {
  final bool isSelected;

  const MapClusterPinChild({super.key, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: HugeIcons.strokeRoundedTask01,
      size: isSelected ? 20 : 17,
      color: isSelected ? Colors.white : primaryColor,
    );
  }
}

/// ── User location dot ─────────────────────────────────────────────────────────

class MapUserDot extends StatelessWidget {
  final double? heading;

  const MapUserDot({super.key, this.heading});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
          ),
        ),
        if (heading != null)
          Transform.rotate(
            angle: heading! * 3.1415926535 / 180,
            child: const Icon(
              Icons.navigation_rounded,
              color: Color(0xFF2563EB),
              size: 34,
              shadows: [
                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          )
        else
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2563EB),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

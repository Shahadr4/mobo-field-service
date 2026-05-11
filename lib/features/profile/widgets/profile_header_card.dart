import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

class ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String? jobFunction;
  final Uint8List? avatar;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onTap;
  final bool showCameraButton;

  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.email,
    this.jobFunction,
    this.avatar,
    this.onCameraPressed,
    this.onTap,
    this.showCameraButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double rs(double size) {
      final w = MediaQuery.of(context).size.width;
      final scale = (w / 390.0).clamp(0.85, 1.2);
      return size * scale;
    }

    Widget photoWidget = avatar != null
        ? ClipOval(
      child: Image.memory(
        avatar!,
        height: 50,
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CircleAvatar(
            radius: 25,
            backgroundColor:
            isDark ? Colors.grey[700] : Colors.grey[300],
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserCircle,
              size: 30,
              color: isDark
                  ? Colors.grey[500]
                  : Colors.grey[600],
            ),
          );
        },
      ),
    )
        : CircleAvatar(
            radius: 34,
            backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
            child: HugeIcon(
              icon:HugeIcons.strokeRoundedUserCircle,
              size: 30,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          );

    final content = Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[200]!, width: 2),
                    ),
                    child: photoWidget,
                  ),
                ),
                if (showCameraButton && onCameraPressed != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: onCameraPressed,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const HugeIcon(
                         icon: HugeIcons.strokeRoundedCamera02,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: rs(18),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: rs(14),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.7,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // if (jobFunction != null && jobFunction!.isNotEmpty) ...[
                //   const SizedBox(height: 2),
                //   Text(
                //     jobFunction!,
                //     style: GoogleFonts.manrope(
                //       color: Colors.white,
                //       fontSize: 12,
                //       fontWeight: FontWeight.w500,
                //       letterSpacing: 0.7,
                //       height: 1.2,
                //     ),
                //     maxLines: 1,
                //     overflow: TextOverflow.ellipsis,
                //   ),
                // ],
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: HugeIcon(
               icon:  HugeIcons.strokeRoundedArrowRight01,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

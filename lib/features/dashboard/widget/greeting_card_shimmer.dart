import 'package:flutter/material.dart';
import '../../../shared/widgets/loaders/shimmer_skeleton.dart';

class GreetingCardShimmer extends StatelessWidget {
  const GreetingCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tinted pink to match the primaryColor card behind it
    final cardBg  = isDark ? const Color(0xFF2E1A22) : const Color(0xFFC8788E);
    final block1  = isDark ? const Color(0xFF3D2530) : const Color(0xFFD4909F);
    final block2  = isDark ? const Color(0xFF3D2530) : const Color(0xFFD4909F);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Shimmer(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(
            left: 15, right: 15, top: 28, bottom: 28,
          ),
          color: cardBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left — greeting text lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Good Morning, Name!!!"
                    Container(
                      height: 18,
                      width: 220,
                      decoration: BoxDecoration(
                        color: block1,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // "Manage Your Field Service Efficiently"
                    Container(
                      height: 13,
                      width: 170,
                      decoration: BoxDecoration(
                        color: block2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right — avatar circle
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: block1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

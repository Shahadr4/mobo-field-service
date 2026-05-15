import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../../profile/providers/profile_provider.dart';

class GreetingCardWidget extends StatelessWidget {
  final ProfileProvider profileProvider;
  const GreetingCardWidget({super.key, required this.profileProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: primaryColor,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, top: 28, bottom: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${profileProvider.getGreeting()} ${profileProvider.userData?['name']?.toString() ?? 'Unknown User'}!!!",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    "Manage Your Field Service Efficiently",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
            profileProvider.userAvatar == null || profileProvider.userAvatar!.isEmpty
                ? CircleAvatar(
                    radius: 34,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUserCircle,
                      size: 30,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  )
                : ClipOval(
                    child: Image.memory(
                      profileProvider.userAvatar!,
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return CircleAvatar(
                          radius: 25,
                          backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedUserCircle,
                            size: 30,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/const/app_colors.dart';



IconData getKanbanIcon(String? state) {
  switch (state) {
    case 'done':
      return Icons.circle;
    case 'normal':
      return Icons.circle;
    case 'blocked':
      return Icons.warning;
    case 'cancel':
      return Icons.cancel;
    default:
      return Icons.help_outline;
  }
}

Color getKanbanColor(String kanbanState) {
  switch (kanbanState.toLowerCase()) {
    case 'normal':
      return Colors.grey;
    case 'done':
      return Colors.green;
    case 'blocked':
      return Colors.orange;
    case 'cancel':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Widget getIcont(String? iconName,String? iconstate) {
  if (iconName == null || iconName == 'false'||iconstate == null) {
    return const  HugeIcon(
      icon: HugeIcons.strokeRoundedClock01,
      color: Colors.grey,
      size: 20,
    );
  }

  final name = iconName.toLowerCase();

  switch (name) {
    case 'fa-check':
      return  Icon(Icons.check, size: 20,color: getColor(iconstate),);

    case 'fa-phone':
      return  Icon(Icons.phone, size: 20,color: getColor(iconstate));

    case 'fa-users':
      return  Icon(Icons.people_outline, size: 20,color: getColor(iconstate));

    case 'fa-envelope':
      return  Icon(Icons.email, size: 20,color: getColor(iconstate));

    default:
      return  HugeIcon(
          icon: HugeIcons.strokeRoundedClock01,
          size: 20,
          color: getColor(iconstate)
      );
  }
}

Color getColor(String? kanbanState) {
  if(kanbanState == null){
    return backgroundColor;
  }
  switch (kanbanState.toLowerCase()) {
    case 'today':
      return Colors.orange;
    case 'planned':
      return Colors.green;
    case 'overdue':
      return Colors.red;
    case 'cancel':
      return Colors.red;
    default:
      return Colors.grey;
  }
}


String cleanedError(String error){
  final errorMessage =
  error.toString().split("message:").last.split(",").first.trim();
  return errorMessage;

}
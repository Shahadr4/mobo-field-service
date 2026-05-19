import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../model/task_model.dart';

String _stripHtml(String html) {
  // Replace block-level tags with newlines so paragraphs stay readable
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>',        caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?p[^>]*>',       caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?div[^>]*>',     caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?li[^>]*>',      caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'</?(?:ul|ol)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'),          '');   // strip remaining tags

  // Decode common HTML entities
  text = text
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;',  "'")
      .replaceAll('&apos;', "'");

  // Collapse 3+ consecutive newlines into 2
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}

class DescriptionContent extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const DescriptionContent({super.key, required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final plain = _stripHtml(task.description);

    if (plain.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/lotties/empty ghost.json',
                  width: 130, height: 130, fit: BoxFit.contain),
              Text(
                'No description',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        plain,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}

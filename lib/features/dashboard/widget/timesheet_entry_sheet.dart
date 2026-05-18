import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/project_item_model.dart';
import '../provider/timesheet_provider.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../../../core/const/app_colors.dart';

class TimesheetEntrySheet extends StatefulWidget {
  final ProjectItem task;
  final int timesheetId;
  final Duration elapsed;

  const TimesheetEntrySheet({
    super.key,
    required this.task,
    required this.timesheetId,
    required this.elapsed,
  });

  static Future<bool> show(
    BuildContext context, {
    required ProjectItem task,
    required int timesheetId,
    required Duration elapsed,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => TimesheetProvider(),
        child: TimesheetEntrySheet(
          task: task,
          timesheetId: timesheetId,
          elapsed: elapsed,
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<TimesheetEntrySheet> createState() => _TimesheetEntrySheetState();
}

class _TimesheetEntrySheetState extends State<TimesheetEntrySheet> {
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _cancel(TimesheetProvider provider) async {
    await provider.cancelTimer(
      timesheetId: widget.timesheetId,
      taskId: widget.task.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _submit(TimesheetProvider provider) async {

    final ok = await provider.stopTimer(
      taskId: widget.task.id,
      timesheetId: widget.timesheetId,
      elapsed: widget.elapsed,
      description: _descCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      CustomSnackbar.show(
        context: context,
        title: 'Timesheet Saved',
        message:
            'Logged ${_formatElapsed(widget.elapsed)} for "${widget.task.name}".',
        type: SnackbarType.success,
      );
    } else {
      CustomSnackbar.showError(
        context,
        provider.error ?? 'Failed to save timesheet.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimesheetProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Save Timesheet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            // Duration in pink
            Text(
              'Duration: ${_formatElapsed(widget.elapsed)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            // Description field
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              minLines: 4,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'What did you work on?',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descCtrl,
              builder: (_, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return Row(
                  children: [
                    // Cancel — outlined
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.isSubmitting
                            ? null
                            : () => _cancel(provider),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(
                              color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save — grey when empty, primary pink when typed
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: provider.isSubmitting
                              ? null
                              : () => hasText == false? null:_submit(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasText
                                ? primaryColor
                                : const Color(0xFFDDDDDD),
                            foregroundColor:
                                hasText ? Colors.white : Colors.black45,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: provider.isSubmitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: hasText
                                        ? Colors.white
                                        : Colors.black45,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

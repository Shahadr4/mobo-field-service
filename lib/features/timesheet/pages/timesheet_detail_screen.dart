import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/const/app_colors.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';
import '../model/timesheet_entry_model.dart';
import '../services/timesheet_list_service.dart';

enum _DetailAction { edit, delete }

class TimesheetDetailScreen extends StatefulWidget {
  final TimesheetEntry entry;

  const TimesheetDetailScreen({super.key, required this.entry});

  /// Returns true if the list should be refreshed (saved or deleted).
  static Future<bool> push(BuildContext context, TimesheetEntry entry) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TimesheetDetailScreen(entry: entry),
      ),
    );
    return result ?? false;
  }
  @override
  State<TimesheetDetailScreen> createState() => _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends State<TimesheetDetailScreen> {
  final _service = TimesheetListService();
  final _hoursCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stt = stt.SpeechToText();

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _textBeforeSpeech = '';
  late DateTime _date;

  /// Holds the current live values (updated on save)
  late TimesheetEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _resetFields();
    _hoursCtrl.addListener(_rebuild);
    _initSpeech();
  }

  void _rebuild() => setState(() {});

  void _resetFields() {
    _hoursCtrl.text = _entry.hours == _entry.hours.truncate()
        ? _entry.hours.toInt().toString()
        : _entry.hours.toStringAsFixed(2);
    _descCtrl.text = _entry.description;
    _date = DateTime.tryParse(_entry.date) ?? DateTime.now();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _stt.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') setState(() => _isListening = false);
      },
    );
  }

  @override
  void dispose() {
    _stt.stop();
    _hoursCtrl.removeListener(_rebuild);
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final h = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
    return h > 0;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final lastDate = DateTime(today.year, today.month, today.day);
    final initialDate = _date.isAfter(lastDate) ? lastDate : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: primaryColor,
            onPrimary: Colors.white,
            onSurface: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1E2028)
                : Colors.white,
            headerBackgroundColor: primaryColor,
            headerForegroundColor: Colors.white,
            dayOverlayColor:
                WidgetStateProperty.all(primaryColor.withValues(alpha: 0.12)),
            todayForegroundColor:
                WidgetStateProperty.all(primaryColor),
            todayBackgroundColor:
                WidgetStateProperty.all(Colors.transparent),
            todayBorder: const BorderSide(color: primaryColor, width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primaryColor),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
    } else {
      _textBeforeSpeech = _descCtrl.text;
      setState(() => _isListening = true);
      await _stt.listen(
        onResult: (r) {
          final words = r.recognizedWords;
          if (words.isNotEmpty) {
            _descCtrl.text = _textBeforeSpeech.isEmpty ? words : '$_textBeforeSpeech $words';
            _descCtrl.selection =
                TextSelection.fromPosition(TextPosition(offset: _descCtrl.text.length));
            if (r.finalResult) _textBeforeSpeech = _descCtrl.text;
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          localeId: 'en_US',
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final hours = double.parse(_hoursCtrl.text.trim());
    final ok = await _service.updateEntry(
      id: _entry.id,
      hours: hours,
      date: _date,
      description: _descCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      /// Rebuild local entry with updated values
      String pad(int n) => n.toString().padLeft(2, '0');
      _entry = TimesheetEntry(
        id: _entry.id,
        taskName: _entry.taskName,
        projectName: _entry.projectName,
        taskId: _entry.taskId,
        projectId: _entry.projectId,
        hours: hours,
        date: '${_date.year}-${pad(_date.month)}-${pad(_date.day)}',
        description: _descCtrl.text.trim(),
      );
      setState(() => _editing = false);
      CustomSnackbar.showSuccess(context, 'Timesheet updated successfully.');
      Navigator.of(context).pop(true);
    } else {
      CustomSnackbar.showError(context, 'Failed to save. Please try again.');
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2028) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Timesheet',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          content: Text(
            'This entry will be permanently deleted. This action cannot be undone.',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: isDark ? Colors.white38 :primaryColor, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                foregroundColor: isDark ? Colors.white70 : primaryColor,
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    final ok = await _service.deleteEntry(_entry.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (ok) {
      CustomSnackbar.showSuccess(context, 'Timesheet deleted.');
      Navigator.of(context).pop(true);
    } else {
      CustomSnackbar.showError(context, 'Failed to delete. Please try again.');
    }
  }

  Widget _card({required bool isDark, required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.2)),
          const SizedBox(height: 12),
          Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _labeled(bool isDark, String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 6),
          child,
        ],
      );

  BoxDecoration _fieldDeco(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(10),
      );

  Widget _readField(bool isDark, IconData icon, String value) {
    return Container(
      decoration: _fieldDeco(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 17, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                  fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14161E) : const Color(0xFFF2F3F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(   _editing ? 'Edit Timesheet' : 'Timesheet Detail',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
        actions: [
          if (_editing) ...[
            TextButton(
              onPressed: () {
                _resetFields();
                setState(() => _editing = false);
              },
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45)),
            ),
            const SizedBox(width: 4),
          ] else if (_deleting) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.redAccent, strokeWidth: 2)),
            ),
          ] else ...[
            PopupMenuButton<_DetailAction>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 22,
                  color: isDark ? Colors.white70 : Colors.black54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: isDark ? const Color(0xFF1E2028) : Colors.white,
              onSelected: (action) {
                if (action == _DetailAction.edit) {
                  setState(() => _editing = true);
                } else {
                  _confirmDelete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _DetailAction.edit,
                  child: Text('Edit',
                      style: TextStyle(
                          fontSize: 14,
                          color:
                          isDark ? Colors.white : Colors.black87)),
                ),
                PopupMenuItem(
                  value: _DetailAction.delete,
                  child: const Text('Delete',
                      style: TextStyle(
                          fontSize: 14, color: primaryColor)),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _card(
                  isDark: isDark,
                  title: 'Project Details',
                  children: [
                    _labeled(isDark, 'Project',
                        _readField(isDark, Icons.folder_outlined,
                            _entry.projectName)),
                    const SizedBox(height: 16),
                    _labeled(isDark, 'Task',
                        _readField(isDark, Icons.task_alt_rounded,
                            _entry.taskName)),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  isDark: isDark,
                  title: 'Time & Date',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Hours
                        Expanded(
                          child: _labeled(
                            isDark,
                            'Hours',
                            _editing
                                ? Container(
                                    decoration: _fieldDeco(isDark),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_rounded,
                                            size: 17,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _hoursCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'^\d*\.?\d{0,2}')),
                                            ],
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                            decoration: InputDecoration(
                                              hintText: '0.0',
                                              hintStyle: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 13),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _readField(isDark, Icons.access_time_rounded,
                                    _entry.formattedHours),
                          ),
                        ),
                        const SizedBox(width: 12),
                        /// Date
                        Expanded(
                          child: _labeled(
                            isDark,
                            'Date',
                            _editing
                                ? GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      decoration: _fieldDeco(isDark),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 13),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_outlined,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38),
                                          const SizedBox(width: 8),
                                          Text(_formatDate(_date),
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87)),
                                        ],
                                      ),
                                    ),
                                  )
                                : _readField(
                                    isDark,
                                    Icons.calendar_today_outlined,
                                    _formatDate(
                                        DateTime.tryParse(_entry.date) ??
                                            DateTime.now())),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _card(
                  isDark: isDark,
                  title: 'Description',
                  children: [
                    _labeled(
                      isDark,
                      'What did you work on?',
                      _editing
                          ? Stack(
                              children: [
                                TextField(
                                  controller: _descCtrl,
                                  maxLines: 5,
                                  minLines: 5,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  decoration: InputDecoration(
                                    hintText: _isListening
                                        ? 'Listening...'
                                        : 'Describe your task...',
                                    hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: _isListening
                                            ? primaryColor
                                            : (isDark
                                                ? Colors.white38
                                                : Colors.black38)),
                                    filled: true,
                                    fillColor: _isListening
                                        ? primaryColor.withValues(alpha: 0.04)
                                        : (isDark
                                            ? const Color(0xFF2A2D3E)
                                            : const Color(0xFFF1F3F5)),
                                    contentPadding: const EdgeInsets.fromLTRB(
                                        14, 14, 48, 14),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: _isListening
                                            ? const BorderSide(
                                                color: primaryColor, width: 1.4)
                                            : BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: primaryColor, width: 1.4)),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: GestureDetector(
                                    onTap: _toggleListening,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _isListening
                                            ? primaryColor
                                            : primaryColor
                                                .withValues(alpha: 0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isListening
                                            ? Icons.mic
                                            : Icons.mic_none_rounded,
                                        size: 17,
                                        color: _isListening
                                            ? Colors.white
                                            : primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 80),
                              padding: const EdgeInsets.all(14),
                              decoration: _fieldDeco(isDark),
                              child: Text(
                                _entry.description.isEmpty
                                    ? '—'
                                    : _entry.description,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _entry.description.isEmpty
                                        ? (isDark
                                            ? Colors.white38
                                            : Colors.black38)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87)),
                              ),
                            ),
                    ),
                  ],
                ),

                if (_editing) ...[
                  const SizedBox(height: 28),
                  _SaveButton(
                      enabled: _canSave, saving: _saving, onTap: _save),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
class _SaveButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  const _SaveButton(
      {required this.enabled, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: enabled
            ? primaryColor
            : (isDark ? const Color(0xFF2A2D36) : const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !saving ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_outlined,
                          size: 18,
                          color: enabled
                              ? Colors.white
                              : (isDark ? Colors.white24 : Colors.black26)),
                      const SizedBox(width: 8),
                      Text('Save Changes',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.black26))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

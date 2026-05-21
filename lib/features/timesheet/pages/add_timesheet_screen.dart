import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/const/app_colors.dart';
import '../../../features/dashboard/model/project_item_model.dart';
import '../../../features/dashboard/provider/timesheet_provider.dart';
import '../../../features/dashboard/services/timesheet_service.dart';
import '../../../shared/widgets/snackbars/custom_snackbar.dart';

class AddTimesheetScreen extends StatefulWidget {
  const AddTimesheetScreen({super.key});

  static Future<bool> push(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTimesheetScreen()),
    );
    return result ?? false;
  }

  @override
  State<AddTimesheetScreen> createState() => _AddTimesheetScreenState();
}

class _AddTimesheetScreenState extends State<AddTimesheetScreen> {
  final _service = TimesheetService();
  final _hoursCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stt = stt.SpeechToText();

  ProjectItem? _selectedTask;
  DateTime _date = DateTime.now();
  bool _submitting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _textBeforeSpeech = '';

  @override
  void initState() {
    super.initState();
    _hoursCtrl.addListener(_rebuild);
    _descCtrl.addListener(_rebuild);
    _initSpeech();
  }

  void _rebuild() => setState(() {});

  Future<void> _initSpeech() async {
    _speechAvailable = await _stt.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _stt.stop();
    _hoursCtrl.removeListener(_rebuild);
    _descCtrl.removeListener(_rebuild);
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selectedTask == null) return false;
    final h = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
    if (h <= 0) return false;
    return true;
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
            _descCtrl.text = _textBeforeSpeech.isEmpty
                ? words
                : '$_textBeforeSpeech $words';
            _descCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _descCtrl.text.length),
            );
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

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    final hours = double.parse(_hoursCtrl.text.trim());
    final ok = await _service.logManual(
      taskId: _selectedTask!.id,
      hours: hours,
      date: _date,
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
      CustomSnackbar.show(
        context: context,
        title: 'Timesheet Saved',
        message: 'Logged ${_hoursCtrl.text.trim()}h for "${_selectedTask!.name}".',
        type: SnackbarType.success,
      );
    } else {
      CustomSnackbar.showError(context, 'Failed to save. Please try again.');
    }
  }

  // ── Layout helpers (matching create_task_screen pattern) ──────────────────

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
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
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

  Widget _gap() => const SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14161E) : const Color(0xFFF2F3F7);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,

          appBar: AppBar(
            elevation: 0,
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Add Timesheet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87)),
          ),
      body: Column(

        children: [

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Project Details ────────────────────────────────────────
                _card(
                  isDark: isDark,
                  title: 'Project Details',
                  children: [
                    _labeled(
                      isDark,
                      'Select Project',
                      GestureDetector(
                        child: Container(
                          decoration: _fieldDeco(isDark),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined,
                                  size: 17,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedTask?.projectName.isNotEmpty == true
                                      ? _selectedTask!.projectName
                                      : 'Field Service',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedTask != null
                                        ? (isDark
                                            ? Colors.white
                                            : Colors.black87)
                                        : (isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _gap(),
                    _labeled(
                      isDark,
                      'Select Task',
                      GestureDetector(
                        onTap: () async {
                          final task = await _TaskPickerSheet.show(context,
                              isDark: isDark);
                          if (task != null) {
                            setState(() => _selectedTask = task);
                          }
                        },
                        child: Container(
                          decoration: _fieldDeco(isDark),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Icon(Icons.task_alt_rounded,
                                  size: 17,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedTask?.name.isNotEmpty == true
                                      ? _selectedTask!.name
                                      : 'Search task...',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedTask != null
                                        ? (isDark
                                            ? Colors.white
                                            : Colors.black87)
                                        : (isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Time & Date ────────────────────────────────────────────
                _card(
                  isDark: isDark,
                  title: 'Time & Date',
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hours
                        Expanded(
                          child: _labeled(
                            isDark,
                            'Hours',
                            Container(
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
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
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
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date
                        Expanded(
                          child: _labeled(
                            isDark,
                            'Date',
                            GestureDetector(
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
                                    Text(
                                      _formatDate(_date),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Description ────────────────────────────────────────────
                _card(
                  isDark: isDark,
                  title: 'Description',
                  children: [
                    _labeled(
                      isDark,
                      'What did you work on?',
                      Stack(
                        children: [
                          TextField(
                            controller: _descCtrl,
                            maxLines: 5,
                            minLines: 5,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
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
                                        : Colors.black38),
                              ),
                              filled: true,
                              fillColor: _isListening
                                  ? primaryColor.withValues(alpha: 0.04)
                                  : (isDark
                                      ? const Color(0xFF2A2D3E)
                                      : const Color(0xFFF1F3F5)),
                              contentPadding:
                                  const EdgeInsets.fromLTRB(14, 14, 48, 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: _isListening
                                    ? const BorderSide(
                                        color: primaryColor, width: 1.4)
                                    : BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: primaryColor, width: 1.4),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: GestureDetector(
                              onTap: _toggleListening,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? primaryColor
                                      : primaryColor.withValues(alpha: 0.10),
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                _LogTimeButton(
                  enabled: _canSubmit,
                  submitting: _submitting,
                  onTap: _submit,
                ),
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

class _LogTimeButton extends StatelessWidget {
  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;

  const _LogTimeButton({
    required this.enabled,
    required this.submitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? primaryColor : (isDark ? const Color(0xFF2A2D36) : const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled && !submitting ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: enabled ? Colors.white : (isDark ? Colors.white24 : Colors.black26),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Log Time',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: enabled
                                ? Colors.white
                                : (isDark ? Colors.white24 : Colors.black26),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task picker bottom sheet (reuses TimesheetProvider)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskPickerSheet extends StatefulWidget {
  final bool isDark;
  const _TaskPickerSheet({required this.isDark});

  static Future<ProjectItem?> show(BuildContext context,
      {required bool isDark}) {
    return showModalBottomSheet<ProjectItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: Provider.of<TimesheetProvider>(context, listen: false),
        child: _TaskPickerSheet(isDark: isDark),
      ),
    );
  }

  @override
  State<_TaskPickerSheet> createState() => _TaskPickerSheetState();
}

class _TaskPickerSheetState extends State<_TaskPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TimesheetProvider>().fetchTasks();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final sheetBg = isDark ? const Color(0xFF1E2028) : Colors.white;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white54 : Colors.black45),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => context.read<TimesheetProvider>().setQuery(v),
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search tasks…',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _searchCtrl,
                  builder: (_, val, _) => val.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            context.read<TimesheetProvider>().setQuery('');
                          },
                          icon: Icon(Icons.close,
                              size: 16, color: Colors.grey.shade400),
                        ),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2D36)
                    : const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // List
          Flexible(child: _PickerList(isDark: isDark)),
        ],
      ),
    );
  }
}

class _PickerList extends StatelessWidget {
  final bool isDark;
  const _PickerList({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimesheetProvider>();

    if (p.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: CircularProgressIndicator(
                color: primaryColor, strokeWidth: 2.5)),
      );
    }

    final items = p.filtered;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(
            p.query.isEmpty
                ? 'No field service tasks assigned to you'
                : 'No tasks match "${p.query}"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final task = items[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: InkWell(
            onTap: () => Navigator.of(ctx).pop(task),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTask01,
                        size: 24,
                        color: Color(0xFFE67E22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (task.projectName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: primaryColor, size: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

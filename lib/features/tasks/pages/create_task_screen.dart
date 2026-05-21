import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../services/task_service.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CreateTaskScreen
// ─────────────────────────────────────────────────────────────────────────────

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});
  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _service    = TaskService();
  final _formKey    = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  // Plain text fields
  final _titleCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Meta lists loaded once
  List<Map<String, dynamic>> _projects   = [];
  List<Map<String, dynamic>> _stages     = [];
  List<Map<String, dynamic>> _worksheets = [];
  List<Map<String, dynamic>> _users      = [];
  List<Map<String, dynamic>> _tags       = [];

  // Selections
  Map<String, dynamic>? _selectedProject;
  Map<String, dynamic>? _selectedStage;
  Map<String, dynamic>? _selectedWorksheet;
  final Set<int> _assigneeIds = {};
  final Set<int> _tagIds      = {};
  Map<String, dynamic>? _selectedCustomer;
  int       _priority     = 0;
  DateTime? _plannedStart;
  DateTime? _plannedEnd;
  bool      _underWarranty = false;

  // FSM feature flags — false until confirmed by Odoo settings fetch
  bool _showWorksheetSection = false;
  bool _showWarrantySection  = false;

  bool _loadingMeta = true;
  bool _saving      = false;

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty &&
      _selectedProject != null &&
      _selectedCustomer != null;

  // ── Typeahead controllers / focus / links ─────────────────────────────────

  // Project
  final _projectCtrl  = TextEditingController();
  final _projectFocus = FocusNode();
  final _projectLink  = LayerLink();
  OverlayEntry? _projectOverlay;

  // Stage
  final _stageCtrl  = TextEditingController();
  final _stageFocus = FocusNode();
  final _stageLink  = LayerLink();
  OverlayEntry? _stageOverlay;

  // Worksheet
  final _worksheetCtrl  = TextEditingController();
  final _worksheetFocus = FocusNode();
  final _worksheetLink  = LayerLink();
  OverlayEntry? _worksheetOverlay;

  // Assignees (checkbox overlay — same pattern as tags)
  final _assigneeLink  = LayerLink();
  OverlayEntry? _assigneeOverlay;

  // Customer
  final _customerCtrl  = TextEditingController();
  final _customerFocus = FocusNode();
  final _customerLink  = LayerLink();
  OverlayEntry? _customerOverlay;
  bool   _searchingCustomer = false;
  Timer? _customerDebounce;

  // Tags (checkbox overlay, no text search needed)
  final _tagFocus = FocusNode();
  final _tagLink  = LayerLink();
  OverlayEntry? _tagOverlay;

  void _showProjectOverlay() {
    if (_selectedProject != null) return;
    if (_projectOverlay != null) return;
    _showSimpleOverlay(
      link: _projectLink,
      overlayRef: (e) => _projectOverlay = e,
      items: _filterList(_projects, _projectCtrl.text),
      onSelect: (item) {
        setState(() => _selectedProject = item);
        _projectCtrl.text = item['name']?.toString() ?? '';
        _projectOverlay?.remove();
        _projectOverlay = null;
        _projectFocus.unfocus();
        _loadStagesForProject((item['id'] as num).toInt());
      },
    );
  }

  void _showStageOverlay() {
    if (_selectedStage != null) return;
    if (_stageOverlay != null) return;
    _showSimpleOverlay(
      link: _stageLink,
      overlayRef: (e) => _stageOverlay = e,
      items: _filterList(_stages, _stageCtrl.text),
      onSelect: (item) {
        setState(() => _selectedStage = item);
        _stageCtrl.text = item['name']?.toString() ?? '';
        _stageOverlay?.remove();
        _stageOverlay = null;
        _stageFocus.unfocus();
      },
      colorFn: (name) => _stageColor(name),
    );
  }

  void _showWorksheetOverlay() {
    if (_selectedWorksheet != null) return;
    if (_worksheetOverlay != null) return;
    _showSimpleOverlay(
      link: _worksheetLink,
      overlayRef: (e) => _worksheetOverlay = e,
      items: _filterList(_worksheets, _worksheetCtrl.text),
      onSelect: (item) {
        setState(() => _selectedWorksheet = item);
        _worksheetCtrl.text = item['name']?.toString() ?? '';
        _worksheetOverlay?.remove();
        _worksheetOverlay = null;
        _worksheetFocus.unfocus();
      },
    );
  }

  Future<void> _onCustomerFocus() async {
    if (_selectedCustomer != null) return;
    if (!mounted) return;
    if (_customerOverlay != null) return;

    setState(() => _searchingCustomer = true);
    final res = await _service.fetchCustomers(search: _customerCtrl.text.trim());
    if (!mounted) return;
    setState(() => _searchingCustomer = false);

    _showCustomerOverlay(res);
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_rebuild);
    _setupFocusListener(_projectFocus,
        onFocus: _showProjectOverlay,
        onBlur: () => _removeOverlay(_projectOverlay, (_) => _projectOverlay = null));
    _setupFocusListener(_stageFocus,
        onFocus: _showStageOverlay,
        onBlur: () => _removeOverlay(_stageOverlay, (_) => _stageOverlay = null));
    _setupFocusListener(_worksheetFocus,
        onFocus: _showWorksheetOverlay,
        onBlur: () => _removeOverlay(_worksheetOverlay, (_) => _worksheetOverlay = null));
    _setupFocusListener(_customerFocus,
        onFocus: _onCustomerFocus,
        onBlur: () => _removeOverlay(_customerOverlay, (_) => _customerOverlay = null));
    _loadMeta();
  }

  void _setupFocusListener(FocusNode node,
      {VoidCallback? onFocus, VoidCallback? onBlur}) {
    node.addListener(() {
      if (node.hasFocus) {
        onFocus?.call();
      } else {
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) onBlur?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _removeAllOverlays();
    _customerDebounce?.cancel();
    _titleCtrl.removeListener(_rebuild);
    for (final c in [
      _titleCtrl, _hoursCtrl, _phoneCtrl, _descriptionCtrl,
      _projectCtrl, _stageCtrl, _worksheetCtrl,
      _customerCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _projectFocus, _stageFocus, _worksheetFocus,
      _customerFocus, _tagFocus,
    ]) {
      f.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _removeAllOverlays() {
    _projectOverlay?.remove();   _projectOverlay  = null;
    _stageOverlay?.remove();     _stageOverlay    = null;
    _worksheetOverlay?.remove(); _worksheetOverlay = null;
    _assigneeOverlay?.remove();  _assigneeOverlay  = null;
    _customerOverlay?.remove();  _customerOverlay  = null;
    _tagOverlay?.remove();       _tagOverlay       = null;
  }

  void _removeOverlay(OverlayEntry? entry, void Function(dynamic) setter) {
    entry?.remove();
    setter(null);
  }

  // ── Load meta ──────────────────────────────────────────────────────────────

  Future<void> _loadMeta() async {
    final results = await Future.wait([
      _service.fetchProjects(),
      _service.fetchWorksheetTemplates(),
      _service.fetchUsers(),
      _service.fetchTags(),
      _service.fetchFsmSettings(),
    ]);
    if (!mounted) return;
    final fsmSettings = results[4] as ({bool worksheetEnabled, bool warrantyEnabled});
    setState(() {
      _projects               = results[0] as List<Map<String, dynamic>>;
      _stages                 = [];
      _worksheets             = results[1] as List<Map<String, dynamic>>;
      _users                  = results[2] as List<Map<String, dynamic>>;
      _tags                   = results[3] as List<Map<String, dynamic>>;
      _showWorksheetSection   = fsmSettings.worksheetEnabled;
      _showWarrantySection    = fsmSettings.warrantyEnabled;
      _loadingMeta            = false;
    });
  }

  Future<void> _loadStagesForProject(int? projectId) async {
    if (projectId == null) {
      setState(() {
        _stages = [];
        _selectedStage = null;
        _stageCtrl.clear();
      });
      return;
    }
    final stages = await _service.fetchStageObjects(projectId: projectId);
    if (!mounted) return;
    setState(() {
      _stages = stages;
      if (_stages.isNotEmpty) {
        final hasCurrent = _stages.any((s) => s['id'] == _selectedStage?['id']);
        if (!hasCurrent) {
          _selectedStage = _stages.first;
          _stageCtrl.text = _stages.first['name']?.toString() ?? '';
        }
      } else {
        _selectedStage = null;
        _stageCtrl.clear();
      }
    });
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filterList(
      List<Map<String, dynamic>> list, String q) {
    if (q.trim().isEmpty) return list;
    return list
        .where((item) => (item['name']?.toString() ?? '')
            .toLowerCase()
            .contains(q.toLowerCase()))
        .toList();
  }


  // ── Simple overlay (single-select: project / stage / worksheet / assignee) ─

  void _showSimpleOverlay({
    required LayerLink link,
    required void Function(OverlayEntry) overlayRef,
    required List<Map<String, dynamic>> items,
    required void Function(Map<String, dynamic>) onSelect,
    Color Function(String)? colorFn,
  }) {
    if (items.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldWidth = (link.leaderSize != null && link.leaderSize!.width > 0)
        ? link.leaderSize!.width
        : (MediaQuery.of(context).size.width - 64);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2C2F3A) : Colors.white,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final name = item['name']?.toString() ?? '';
                    final color = colorFn?.call(name);
                    return InkWell(
                      onTap: () => onSelect(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            if (color != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlayRef(entry);
    Overlay.of(context).insert(entry);
  }

  // ── Assignee checkbox overlay (same pattern as tags) ──────────────────────

  void _openAssigneeOverlay() {
    _assigneeOverlay?.remove();
    _assigneeOverlay = null;
    if (_users.isEmpty) return;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final pending = Set<int>.from(_assigneeIds);
    final fieldWidth = (_assigneeLink.leaderSize != null && _assigneeLink.leaderSize!.width > 0)
        ? _assigneeLink.leaderSize!.width
        : (MediaQuery.of(context).size.width - 64);

    _assigneeOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _assigneeLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2C2F3A) : Colors.white,
            child: _AssigneeCheckboxPanel(
              isDark: isDark,
              allUsers: _users,
              initialSelected: pending,
              onAdd: (selected) {
                setState(() {
                  _assigneeIds
                    ..clear()
                    ..addAll(selected);
                });
                _assigneeOverlay?.remove();
                _assigneeOverlay = null;
              },
              onCancel: () {
                _assigneeOverlay?.remove();
                _assigneeOverlay = null;
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_assigneeOverlay!);
  }

  // ── Customer typeahead ─────────────────────────────────────────────────────

  void _showCustomerOverlay(List<Map<String, dynamic>> res) {
    _customerOverlay?.remove();
    _customerOverlay = null;
    if (res.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldWidth = (_customerLink.leaderSize != null && _customerLink.leaderSize!.width > 0)
        ? _customerLink.leaderSize!.width
        : (MediaQuery.of(context).size.width - 64);

    _customerOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _customerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2C2F3A) : Colors.white,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: res.length,
                  itemBuilder: (_, i) {
                    final c    = res[i];
                    final name = c['name']?.toString() ?? '';
                    final ph   = c['phone']?.toString() ?? '';
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCustomer = c);
                        _customerCtrl.text = name;
                        if (ph.isNotEmpty) _phoneCtrl.text = ph;
                        _customerOverlay?.remove();
                        _customerOverlay = null;
                        _customerFocus.unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  primaryColor.withValues(alpha: 0.13),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87)),
                                  if (ph.isNotEmpty)
                                    Text(ph,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_customerOverlay!);
  }

  void _onCustomerChanged(String q) {
    _customerDebounce?.cancel();
    if (q.trim().isEmpty) {
      _customerOverlay?.remove();
      _customerOverlay = null;
      return;
    }
    _customerDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searchingCustomer = true);
      final res = await _service.fetchCustomers(search: q.trim());
      if (!mounted) return;
      setState(() => _searchingCustomer = false);
      _showCustomerOverlay(res);
    });
  }

  // ── Tag checkbox overlay ───────────────────────────────────────────────────

  void _openTagOverlay() {
    _tagOverlay?.remove();
    _tagOverlay = null;
    if (_tags.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = Set<int>.from(_tagIds);
    final fieldWidth = (_tagLink.leaderSize != null && _tagLink.leaderSize!.width > 0)
        ? _tagLink.leaderSize!.width
        : (MediaQuery.of(context).size.width - 64);

    _tagOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _tagLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2C2F3A) : Colors.white,
            child: _TagCheckboxPanel(
              isDark: isDark,
              allTags: _tags,
              initialSelected: pending,
              onAdd: (selected) {
                setState(() {
                  _tagIds
                    ..clear()
                    ..addAll(selected);
                });
                _tagOverlay?.remove();
                _tagOverlay = null;
                _tagFocus.unfocus();
              },
              onCancel: () {
                _tagOverlay?.remove();
                _tagOverlay = null;
                _tagFocus.unfocus();
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_tagOverlay!);
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isStart}) async {
    final init = (isStart ? _plannedStart : _plannedEnd) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: primaryColor,
            onPrimary: Colors.white,
            onSurface: Theme.of(ctx).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
            surface: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1E2028)
                : Colors.white,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1E2028)
                : Colors.white,
            hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? primaryColor
                    : (Theme.of(ctx).brightness == Brightness.dark
                        ? const Color(0xFF2A2D3E)
                        : const Color(0xFFF1F3F5))),
            hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : (Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87)),
            dialHandColor: primaryColor,
            dialBackgroundColor: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF2A2D3E)
                : const Color(0xFFF1F3F5),
            entryModeIconColor: primaryColor,
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
    if (time == null || !mounted) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isStart) {
      if (_plannedEnd != null && dt.isAfter(_plannedEnd!)) {
        CustomSnackbar.showWarning(context, 'Planned start date must be before planned end date.');
        return;
      }
      setState(() => _plannedStart = dt);
    } else {
      if (_plannedStart != null && dt.isBefore(_plannedStart!)) {
        CustomSnackbar.showWarning(context, 'Planned end date must be after planned start date.');
        return;
      }
      setState(() => _plannedEnd = dt);
    }
    setState(() {
      _recalcHours();
    });
  }

  void _recalcHours() {
    if (_plannedStart == null || _plannedEnd == null) return;
    if (_plannedEnd!.isBefore(_plannedStart!)) return;
    final diff  = _plannedEnd!.difference(_plannedStart!);
    final hours = diff.inMinutes / 60.0;
    _hoursCtrl.text = hours % 1 == 0
        ? hours.toInt().toString()
        : hours.toStringAsFixed(2);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0.0;
    final id = await _service.createTask(
      name:                _titleCtrl.text.trim(),
      projectId:           (_selectedProject!['id'] as num).toInt(),
      stageId:             _selectedStage != null
          ? (_selectedStage!['id'] as num).toInt()
          : null,
      assigneeIds:         _assigneeIds.toList(),
      plannedDateBegin:    _plannedStart,
      plannedDateEnd:      _plannedEnd,
      allocatedHours:      hours,
      tagIds:              _tagIds.toList(),
      partnerId:           _selectedCustomer != null
          ? (_selectedCustomer!['id'] as num).toInt()
          : null,
      underWarranty:       _underWarranty,
      worksheetTemplateId: _selectedWorksheet != null
          ? (_selectedWorksheet!['id'] as num).toInt()
          : null,
      description:         _descriptionCtrl.text.trim(),
      priority:            _priority,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      CustomSnackbar.showSuccess(context, 'Task created successfully');
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.showError(context, 'Failed to create task. Please try again.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF14161E) : const Color(0xFFF2F3F7);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _removeAllOverlays();
      },
      child: Scaffold(
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
          title: Text('Create Task',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
        ),
        body: _loadingMeta
            ? const Center(
                child: CircularProgressIndicator(
                    color: primaryColor, strokeWidth: 2.5))
            : Form(
                key: _formKey,
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // ── Main card ──────────────────────────────────────
                    _card(
                      isDark: isDark,
                      title: 'General',
                      children: [
                      _labeled(isDark, 'Name',
                          _plainInput(isDark, _titleCtrl, 'Enter task name',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null)),
                      _gap(),
                      _labeled(isDark, 'Project *',
                          _typeaheadField(
                            isDark: isDark,
                            ctrl: _projectCtrl,
                            focus: _projectFocus,
                            link: _projectLink,
                            hint: 'Search project...',
                            selected: _selectedProject,
                            onTap: _showProjectOverlay,
                            onClear: () {
                              setState(() => _selectedProject = null);
                              _projectCtrl.clear();
                              _loadStagesForProject(null);
                            },
                            onChanged: (q) {
                              _projectOverlay?.remove();
                              _projectOverlay = null;
                              _showSimpleOverlay(
                                link: _projectLink,
                                overlayRef: (e) => _projectOverlay = e,
                                items: _filterList(_projects, q),
                                onSelect: (item) {
                                  setState(() => _selectedProject = item);
                                  _projectCtrl.text =
                                      item['name']?.toString() ?? '';
                                  _projectOverlay?.remove();
                                  _projectOverlay = null;
                                  _projectFocus.unfocus();
                                  _loadStagesForProject((item['id'] as num).toInt());
                                },
                              );
                            },
                          )),
                      if (_selectedProject != null || _selectedStage != null) ...[
                        _gap(),
                        _labeled(isDark, 'Status',
                            _typeaheadField(
                              isDark: isDark,
                              ctrl: _stageCtrl,
                              focus: _stageFocus,
                              link: _stageLink,
                              hint: 'Search status...',
                              selected: _selectedStage,
                              selectedColor: _selectedStage != null
                                  ? _stageColor(
                                      _selectedStage!['name']?.toString() ?? '')
                                  : null,
                              onTap: _showStageOverlay,
                              onClear: () {
                                setState(() => _selectedStage = null);
                                _stageCtrl.clear();
                              },
                              onChanged: (q) {
                                _stageOverlay?.remove();
                                _stageOverlay = null;
                                _showSimpleOverlay(
                                  link: _stageLink,
                                  overlayRef: (e) => _stageOverlay = e,
                                  items: _filterList(_stages, q),
                                  colorFn: _stageColor,
                                  onSelect: (item) {
                                    setState(() => _selectedStage = item);
                                    _stageCtrl.text =
                                        item['name']?.toString() ?? '';
                                    _stageOverlay?.remove();
                                    _stageOverlay = null;
                                    _stageFocus.unfocus();
                                  },
                                );
                              },
                            )),
                      ],
                      _gap(),
                      _labeled(isDark, 'Assigned to',
                          _assigneeField(isDark)),
                      _gap(),
                      _labeled(isDark, 'Customer *',
                          _customerField(isDark)),
                    ]),
                    const SizedBox(height: 16),

                    // ── Information ────────────────────────────────────
                    _card(
                      isDark: isDark,
                      title: 'Information',
                      children: [
                      _labeled(isDark, 'Priority', _priorityStars(isDark)),
                      if (_showWorksheetSection) ...[
                        _gap(),
                        _labeled(isDark, 'Worksheet Template',
                            _typeaheadField(
                              isDark: isDark,
                              ctrl: _worksheetCtrl,
                              focus: _worksheetFocus,
                              link: _worksheetLink,
                              hint: 'Search worksheet...',
                              selected: _selectedWorksheet,
                              onTap: _showWorksheetOverlay,
                              onClear: () {
                                setState(() => _selectedWorksheet = null);
                                _worksheetCtrl.clear();
                              },
                              onChanged: (q) {
                                _worksheetOverlay?.remove();
                                _worksheetOverlay = null;
                                _showSimpleOverlay(
                                  link: _worksheetLink,
                                  overlayRef: (e) => _worksheetOverlay = e,
                                  items: _filterList(_worksheets, q),
                                  onSelect: (item) {
                                    setState(() => _selectedWorksheet = item);
                                    _worksheetCtrl.text =
                                        item['name']?.toString() ?? '';
                                    _worksheetOverlay?.remove();
                                    _worksheetOverlay = null;
                                    _worksheetFocus.unfocus();
                                  },
                                );
                              },
                            )),
                      ],
                      _gap(),
                      _labeled(isDark, 'Contact Number',
                          _plainInput(isDark, _phoneCtrl, 'Phone number',
                              keyboardType: TextInputType.phone)),
                      _gap(),
                      _labeled(isDark, 'Tags', _tagsField(isDark)),
                      if (_showWarrantySection) ...[
                        _gap(),
                        _labeled(
                            isDark, 'Under Warranty', _warrantyField(isDark)),
                      ],
                    ]),
                    const SizedBox(height: 16),

                    // ── Description ────────────────────────────────────
                    _card(
                      isDark: isDark,
                      title: 'Description',
                      children: [
                        _plainInput(
                          isDark,
                          _descriptionCtrl,
                          'Enter task description here...',
                          maxLines: null,
                          minLines: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Schedule ───────────────────────────────────────
                    _card(
                      isDark: isDark,
                      title: 'Schedule',
                      children: [
                      _labeled(isDark, 'Planned Start',
                          _dateField(isDark, _plannedStart,
                              'Select date & time',
                              () => _pickDateTime(isStart: true),
                              () => setState(() => _plannedStart = null))),
                      _gap(),
                      _labeled(isDark, 'Planned End',
                          _dateField(isDark, _plannedEnd,
                              'Select date & time',
                              () => _pickDateTime(isStart: false),
                              () => setState(() => _plannedEnd = null))),
                      _gap(),
                      _labeled(isDark, 'Allocated Time (hrs)',
                          _plainInput(isDark, _hoursCtrl, '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ])),
                    ]),
                    const SizedBox(height: 28),
                    _createButton(isDark),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Field widgets ──────────────────────────────────────────────────────────

  // Generic typeahead field (project / status / worksheet)
  Widget _typeaheadField({
    required bool isDark,
    required TextEditingController ctrl,
    required FocusNode focus,
    required LayerLink link,
    required String hint,
    required Map<String, dynamic>? selected,
    required VoidCallback onClear,
    required ValueChanged<String> onChanged,
    VoidCallback? onTap,
    Color? selectedColor,
  }) {
    return CompositedTransformTarget(
      link: link,
      child: Container(
        decoration: _fieldDeco(isDark),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          readOnly: selected != null,
          onTap: selected != null ? null : onTap,
          style: TextStyle(
              fontSize: 14,
              fontWeight: selected != null ? FontWeight.w500 : FontWeight.w400,
              color: selectedColor ?? (isDark ? Colors.white : Colors.black87)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: InputBorder.none,
            prefixIcon: selected == null
                ? Icon(Icons.search_rounded,
                    size: 17,
                    color: isDark ? Colors.white38 : Colors.black38)
                : null,
            suffixIcon: selected != null
                ? GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded,
                        size: 17,
                        color: isDark ? Colors.white38 : Colors.black45))
                : Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black38),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Assignees multi-select (checkbox overlay — same pattern as tags)
  Widget _assigneeField(bool isDark) {
    final selected = _users
        .where((u) => _assigneeIds.contains((u['id'] as num).toInt()))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected.map((u) {
              final id   = (u['id'] as num).toInt();
              final name = u['name']?.toString() ?? '';
              return _chip(isDark, name, primaryColor.withValues(alpha: 0.12),
                  primaryColor, () => setState(() => _assigneeIds.remove(id)));
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        CompositedTransformTarget(
          link: _assigneeLink,
          child: GestureDetector(
            onTap: _openAssigneeOverlay,
            child: Container(
              decoration: _fieldDeco(isDark),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 17,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selected.isEmpty
                          ? 'Select assignees...'
                          : 'Edit assignees (${selected.length})',
                      style: TextStyle(
                          fontSize: 14,
                          color: selected.isNotEmpty
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : (isDark ? Colors.white38 : Colors.black38)),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Customer single-select typeahead
  Widget _customerField(bool isDark) {
    return CompositedTransformTarget(
      link: _customerLink,
      child: Container(
        decoration: _fieldDeco(isDark),
        child: TextField(
          controller: _customerCtrl,
          focusNode: _customerFocus,
          readOnly: _selectedCustomer != null,
          onTap: _selectedCustomer != null ? null : _onCustomerFocus,
          style: TextStyle(
              fontSize: 14,
              fontWeight: _selectedCustomer != null
                  ? FontWeight.w500
                  : FontWeight.w400,
              color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search customer...',
            hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: InputBorder.none,
            prefixIcon: _selectedCustomer == null
                ? Icon(Icons.search_rounded,
                    size: 17,
                    color: isDark ? Colors.white38 : Colors.black38)
                : null,
            suffixIcon: _selectedCustomer != null
                ? GestureDetector(
                    onTap: () {
                      setState(() => _selectedCustomer = null);
                      _customerCtrl.clear();
                      _phoneCtrl.clear();
                      _customerOverlay?.remove();
                      _customerOverlay = null;
                    },
                    child: Icon(Icons.close_rounded,
                        size: 17,
                        color: isDark ? Colors.white38 : Colors.black45))
                : _searchingCustomer
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: primaryColor, strokeWidth: 2)))
                    : Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black38),
          ),
          onChanged:
              _selectedCustomer != null ? null : _onCustomerChanged,
        ),
      ),
    );
  }

  // Tags field — shows selected chips + tap to open checkbox overlay
  Widget _tagsField(bool isDark) {
    final selected =
        _tags.where((t) => _tagIds.contains((t['id'] as num).toInt())).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected.map((t) {
              final id   = (t['id'] as num).toInt();
              final name = t['name']?.toString() ?? '';
              return _chip(
                  isDark,
                  name,
                  isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  isDark ? Colors.white70 : Colors.black87,
                  () => setState(() => _tagIds.remove(id)));
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        CompositedTransformTarget(
          link: _tagLink,
          child: GestureDetector(
            onTap: _openTagOverlay,
            child: Container(
              decoration: _fieldDeco(isDark),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 17,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selected.isEmpty
                          ? 'Select tags...'
                          : 'Edit tags (${selected.length})',
                      style: TextStyle(
                          fontSize: 14,
                          color: selected.isNotEmpty
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : (isDark ? Colors.white38 : Colors.black38)),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared small widgets ───────────────────────────────────────────────────

  Widget _plainInput(
    bool isDark,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLines = 1,
    int? minLines,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      style: TextStyle(
          fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryColor, width: 1.4)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.4)),
      ),
      validator: validator,
    );
  }

  Widget _dateField(bool isDark, DateTime? value, String hint,
      VoidCallback onTap, VoidCallback onClear) {
    final txt = value == null
        ? null
        : '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/'
            '${value.year}  '
            '${value.hour.toString().padLeft(2, '0')}:'
            '${value.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _fieldDeco(isDark),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: value != null
                    ? primaryColor
                    : (isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(txt ?? hint,
                  style: TextStyle(
                      fontSize: 14,
                      color: txt != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38))),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38),
              ),
          ],
        ),
      ),
    );
  }

  Widget _priorityStars(bool isDark) {
    return Row(
      children: List.generate(3, (i) {
        final filled = i < _priority;
        return GestureDetector(
          onTap: () =>
              setState(() => _priority = (i + 1 == _priority) ? 0 : i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 28,
              color: filled
                  ? const Color(0xFFFFB800)
                  : (isDark ? Colors.white30 : Colors.black26),
            ),
          ),
        );
      }),
    );
  }

  Widget _warrantyField(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _underWarranty = !_underWarranty),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: _fieldDeco(isDark),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _underWarranty ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: _underWarranty
                      ? primaryColor
                      : (isDark ? Colors.white38 : Colors.black38),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: _underWarranty
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              'Under Warranty',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(bool isDark, String label, Color bg, Color fg,
      VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 7, 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 14, color: fg.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }

  Widget _createButton(bool isDark) {
    final enabled = _canSubmit && !_saving;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: enabled
            ? primaryColor
            : (isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? _submit : null,
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.2))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_task_rounded,
                          size: 20,
                          color: enabled
                              ? Colors.white
                              : (isDark ? Colors.white30 : Colors.black38)),
                      const SizedBox(width: 8),
                      Text('Create Task',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: enabled
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white30
                                      : Colors.black38))),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Layout helpers ─────────────────────────────────────────────────────────

  Widget _card({required bool isDark, String? title, required List<Widget> children}) {
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
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);

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

  Color _stageColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('new')) return Colors.blue;
    if (n.contains('plan')) return Colors.orange;
    if (n.contains('progress') || n.contains('ongoing')) return Colors.indigo;
    if (n.contains('done') || n.contains('complete')) return Colors.green;
    if (n.contains('cancel')) return Colors.red;
    return primaryColor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag checkbox panel (rendered inside overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _TagCheckboxPanel extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> allTags;
  final Set<int> initialSelected;
  final ValueChanged<Set<int>> onAdd;
  final VoidCallback onCancel;

  const _TagCheckboxPanel({
    required this.isDark,
    required this.allTags,
    required this.initialSelected,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<_TagCheckboxPanel> createState() => _TagCheckboxPanelState();
}

class _TagCheckboxPanelState extends State<_TagCheckboxPanel> {
  late Set<int> _pending;
  late List<Map<String, dynamic>> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pending  = Set<int>.from(widget.initialSelected);
    _filtered = List.from(widget.allTags);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) => setState(() {
        _filtered = q.trim().isEmpty
            ? List.from(widget.allTags)
            : widget.allTags
                .where((t) => (t['name']?.toString() ?? '')
                    .toLowerCase()
                    .contains(q.toLowerCase()))
                .toList();
      });

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final cardBg  = isDark ? const Color(0xFF2C2F3A) : Colors.white;
    final divClr  = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);
    final textClr = isDark ? Colors.white : Colors.black87;
    final hintClr = isDark ? Colors.white38 : Colors.black38;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 13, color: textClr),
              decoration: InputDecoration(
                hintText: 'Search tags...',
                hintStyle: TextStyle(fontSize: 13, color: hintClr),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 16, color: hintClr),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E2230)
                    : const Color(0xFFF1F3F5),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: _filter,
            ),
          ),
          Divider(height: 1, thickness: 1, color: divClr),

          // Fixed-height scrollable list
          SizedBox(
            height: 210,
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No tags found',
                        style: TextStyle(fontSize: 13, color: hintClr)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final id      = (_filtered[i]['id'] as num).toInt();
                      final name    = _filtered[i]['name']?.toString() ?? '';
                      final checked = _pending.contains(id);
                      return InkWell(
                        onTap: () => setState(() => checked
                            ? _pending.remove(id)
                            : _pending.add(id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: checked
                                      ? primaryColor
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: checked ? primaryColor : hintClr,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: checked
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: checked
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: textClr)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Divider(height: 1, thickness: 1, color: divClr),

          // Cancel / Add buttons
          Container(
            color: cardBg,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: hintClr)),
                    ),
                  ),
                ),
                Container(width: 1, height: 44, color: divClr),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onAdd(Set.from(_pending)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _pending.isEmpty
                            ? 'Add'
                            : 'Add (${_pending.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assignee checkbox panel (rendered inside overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _AssigneeCheckboxPanel extends StatefulWidget {
  final bool isDark;
  final List<Map<String, dynamic>> allUsers;
  final Set<int> initialSelected;
  final ValueChanged<Set<int>> onAdd;
  final VoidCallback onCancel;

  const _AssigneeCheckboxPanel({
    required this.isDark,
    required this.allUsers,
    required this.initialSelected,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<_AssigneeCheckboxPanel> createState() => _AssigneeCheckboxPanelState();
}

class _AssigneeCheckboxPanelState extends State<_AssigneeCheckboxPanel> {
  late Set<int> _pending;
  late List<Map<String, dynamic>> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pending  = Set<int>.from(widget.initialSelected);
    _filtered = List.from(widget.allUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) => setState(() {
        _filtered = q.trim().isEmpty
            ? List.from(widget.allUsers)
            : widget.allUsers
                .where((u) => (u['name']?.toString() ?? '')
                    .toLowerCase()
                    .contains(q.toLowerCase()))
                .toList();
      });

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final cardBg  = isDark ? const Color(0xFF2C2F3A) : Colors.white;
    final divClr  = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);
    final textClr = isDark ? Colors.white : Colors.black87;
    final hintClr = isDark ? Colors.white38 : Colors.black38;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 13, color: textClr),
              decoration: InputDecoration(
                hintText: 'Search assignees...',
                hintStyle: TextStyle(fontSize: 13, color: hintClr),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: hintClr),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E2230)
                    : const Color(0xFFF1F3F5),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              onChanged: _filter,
            ),
          ),
          Divider(height: 1, thickness: 1, color: divClr),

          // Fixed-height scrollable list
          SizedBox(
            height: 210,
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No users found',
                        style: TextStyle(fontSize: 13, color: hintClr)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final id      = (_filtered[i]['id'] as num).toInt();
                      final name    = _filtered[i]['name']?.toString() ?? '';
                      final checked = _pending.contains(id);
                      return InkWell(
                        onTap: () => setState(() =>
                            checked ? _pending.remove(id) : _pending.add(id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: checked
                                      ? primaryColor
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: checked ? primaryColor : hintClr,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: checked
                                    ? const Icon(Icons.check_rounded,
                                        size: 13, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 13,
                                backgroundColor:
                                    primaryColor.withValues(alpha: 0.13),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: checked
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: textClr)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Divider(height: 1, thickness: 1, color: divClr),

          // Cancel / Add buttons
          Container(
            color: cardBg,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: hintClr)),
                    ),
                  ),
                ),
                Container(width: 1, height: 44, color: divClr),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onAdd(Set.from(_pending)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _pending.isEmpty ? 'Add' : 'Add (${_pending.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

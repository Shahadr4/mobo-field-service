import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

import '../model/task_model.dart';
import '../services/task_service.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EditTaskScreen
// ─────────────────────────────────────────────────────────────────────────────

class EditTaskScreen extends StatefulWidget {
  final TaskModel task;
  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
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

  // Change detection logic
  bool get _hasChanges {
    final titleChanged = _titleCtrl.text.trim() != widget.task.name;
    
    final origProjId = widget.task.projectId;
    final newProjId = (_selectedProject?['id'] as num?)?.toInt();
    final projectChanged = newProjId != origProjId;

    final origStageId = widget.task.stageId;
    final newStageId = (_selectedStage?['id'] as num?)?.toInt();
    final stageChanged = newStageId != origStageId;

    final origAssignees = widget.task.assigneeIds.toSet();
    final assigneesChanged = !_setEquals(_assigneeIds, origAssignees);

    final origTags = widget.task.tagIds.toSet();
    final tagsChanged = !_setEquals(_tagIds, origTags);

    final origCustId = widget.task.partnerId;
    final newCustId = (_selectedCustomer?['id'] as num?)?.toInt();
    final customerChanged = newCustId != origCustId;

    final phoneChanged = _phoneCtrl.text.trim() != widget.task.partnerPhone;
    final warrantyChanged = _showWarrantySection && _underWarranty != widget.task.underWarranty;
    final priorityChanged = _priority != widget.task.priority;

    final origWorksheetId = widget.task.worksheetTemplateId;
    final newWorksheetId = (_selectedWorksheet?['id'] as num?)?.toInt();
    final worksheetChanged = _showWorksheetSection && newWorksheetId != origWorksheetId;

    final startChanged = _plannedStart != widget.task.plannedDateBegin;
    final endChanged = _plannedEnd != widget.task.plannedDateEnd;

    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0.0;
    final hoursChanged = hours != widget.task.allocatedHours;

    final descriptionChanged = _descriptionCtrl.text.trim() != widget.task.description;

    return titleChanged ||
        projectChanged ||
        stageChanged ||
        assigneesChanged ||
        tagsChanged ||
        customerChanged ||
        phoneChanged ||
        warrantyChanged ||
        priorityChanged ||
        startChanged ||
        endChanged ||
        hoursChanged ||
        descriptionChanged ||
        worksheetChanged;
  }

  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  bool get _canSubmit =>
      _titleCtrl.text.trim().isNotEmpty && _selectedProject != null && _hasChanges;

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

  // Customer
  final _customerCtrl  = TextEditingController();
  final _customerFocus = FocusNode();
  final _customerLink  = LayerLink();
  OverlayEntry? _customerOverlay;
  bool _searchingCustomers = false;
  List<Map<String, dynamic>> _customerResults = [];
  Timer? _customerDebounce;

  // Assignee / Tag links
  final _assigneeLink = LayerLink();
  final _tagLink      = LayerLink();
  OverlayEntry? _assigneeOverlay;
  OverlayEntry? _tagOverlay;
  final _tagFocus = FocusNode();

  // ── Init state ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.task.name;
    _descriptionCtrl.text = widget.task.description;
    _hoursCtrl.text = widget.task.allocatedHours > 0 ? widget.task.allocatedHours.toString() : '';
    _plannedStart = widget.task.plannedDateBegin;
    _plannedEnd = widget.task.plannedDateEnd;
    _underWarranty = widget.task.underWarranty;
    _priority = widget.task.priority;
    _assigneeIds.addAll(widget.task.assigneeIds);
    _tagIds.addAll(widget.task.tagIds);

    // Initial setup for controller listeners
    _titleCtrl.addListener(_rebuild);
    _projectCtrl.addListener(_rebuild);
    _hoursCtrl.addListener(_rebuild);
    _phoneCtrl.addListener(_rebuild);
    _descriptionCtrl.addListener(_rebuild);

    // Setup focus node behaviors
    _projectFocus.addListener(() {
      if (!_projectFocus.hasFocus) {
        _projectOverlay?.remove();
        _projectOverlay = null;
      }
    });
    _stageFocus.addListener(() {
      if (!_stageFocus.hasFocus) {
        _stageOverlay?.remove();
        _stageOverlay = null;
      }
    });
    _worksheetFocus.addListener(() {
      if (!_worksheetFocus.hasFocus) {
        _worksheetOverlay?.remove();
        _worksheetOverlay = null;
      }
    });
    _customerFocus.addListener(() {
      if (!_customerFocus.hasFocus) {
        _customerOverlay?.remove();
        _customerOverlay = null;
      }
    });

    _loadMeta();
  }

  @override
  void dispose() {
    _removeAllOverlays();
    _customerDebounce?.cancel();
    _titleCtrl.removeListener(_rebuild);
    _projectCtrl.removeListener(_rebuild);
    _hoursCtrl.removeListener(_rebuild);
    _phoneCtrl.removeListener(_rebuild);
    _descriptionCtrl.removeListener(_rebuild);

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
    _customerOverlay?.remove();  _customerOverlay = null;
    _assigneeOverlay?.remove();  _assigneeOverlay = null;
    _tagOverlay?.remove();       _tagOverlay      = null;
  }

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
      colorFn: _stageColor,
      onSelect: (item) {
        setState(() => _selectedStage = item);
        _stageCtrl.text = item['name']?.toString() ?? '';
        _stageOverlay?.remove();
        _stageOverlay = null;
        _stageFocus.unfocus();
      },
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
      _projects              = results[0] as List<Map<String, dynamic>>;
      _worksheets            = results[1] as List<Map<String, dynamic>>;
      _users                 = results[2] as List<Map<String, dynamic>>;
      _tags                  = results[3] as List<Map<String, dynamic>>;
      _showWorksheetSection  = fsmSettings.worksheetEnabled;
      _showWarrantySection   = fsmSettings.warrantyEnabled;
      _loadingMeta           = false;

      // Pre-populate worksheet from task
      if (widget.task.worksheetTemplateId != null) {
        final match = (results[1] as List<Map<String, dynamic>>).firstWhere(
          (w) => (w['id'] as num).toInt() == widget.task.worksheetTemplateId,
          orElse: () => {
            'id': widget.task.worksheetTemplateId,
            'name': widget.task.worksheetTemplateName,
          },
        );
        _selectedWorksheet = match;
        _worksheetCtrl.text = match['name']?.toString() ?? '';
      }
    });

    // Match selected project from task
    if (widget.task.projectId != null) {
      final matchedProj = _projects.firstWhere(
        (p) => (p['id'] as num).toInt() == widget.task.projectId,
        orElse: () => {'id': widget.task.projectId, 'name': widget.task.projectName},
      );
      setState(() {
        _selectedProject = matchedProj;
        _projectCtrl.text = matchedProj['name']?.toString() ?? '';
      });

      // Load stages for that project
      final stages = await _service.fetchStageObjects(projectId: widget.task.projectId);
      if (!mounted) return;
      setState(() {
        _stages = stages;
        if (widget.task.stageId != null) {
          final matchedStage = _stages.firstWhere(
            (s) => (s['id'] as num).toInt() == widget.task.stageId,
            orElse: () => {'id': widget.task.stageId, 'name': widget.task.stageName},
          );
          _selectedStage = matchedStage;
          _stageCtrl.text = matchedStage['name']?.toString() ?? '';
        }
      });
    }

    // Match customer from task
    if (widget.task.partnerId != null) {
      setState(() {
        _selectedCustomer = {
          'id': widget.task.partnerId,
          'name': widget.task.partnerName,
        };
        _customerCtrl.text = widget.task.partnerName;
        _phoneCtrl.text = widget.task.partnerPhone;
      });
    }

    setState(() {
      _loadingMeta = false;
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

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('progress') || s.contains('ongoing')) return const Color(0xFF06B6D4);
    if (s.contains('done') || s.contains('complete'))    return const Color(0xFF22C55E);
    if (s.contains('approve'))                           return const Color(0xFF22C55E);
    if (s.contains('cancel'))                            return const Color(0xFFEF4444);
    if (s.contains('plan'))                              return const Color(0xFFF59E0B);
    if (s.contains('new'))                               return const Color(0xFF3B82F6);
    return primaryColor;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0.0;
    
    final errorMsg = await _service.updateTask(
      taskId:              widget.task.id,
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
      underWarranty:       _showWarrantySection ? _underWarranty : null,
      worksheetTemplateId: _showWorksheetSection && _selectedWorksheet != null
          ? (_selectedWorksheet!['id'] as num).toInt()
          : null,
      description:         _descriptionCtrl.text.trim(),
      priority:            _priority,
    );
    
    if (!mounted) return;
    setState(() => _saving = false);
    if (errorMsg == null) {
      CustomSnackbar.showSuccess(context, 'Task updated successfully');
      
      String parseOdooDt(dynamic v) {
        if (v == null) return '';
        final s = v.toString();
        return s.length >= 10 ? s.substring(0, 10) : s;
      }

      String fmt12(DateTime dt) {
        final months = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
        final date   = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
        final h      = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final m      = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour < 12 ? 'AM' : 'PM';
        return '$date  $h:$m $period';
      }

      final currentAssigneeNames = _users
          .where((u) => _assigneeIds.contains((u['id'] as num).toInt()))
          .map((u) => u['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final currentTagNames = _tags
          .where((t) => _tagIds.contains((t['id'] as num).toInt()))
          .map((t) => t['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      final updatedTask = widget.task.copyWith(
        name:                _titleCtrl.text.trim(),
        projectName:         _selectedProject?['name']?.toString() ?? widget.task.projectName,
        stageName:           _selectedStage?['name']?.toString() ?? widget.task.stageName,
        assigneeName:        currentAssigneeNames.isNotEmpty ? currentAssigneeNames.join(', ') : widget.task.assigneeName,
        partnerName:         _selectedCustomer?['name']?.toString() ?? widget.task.partnerName,
        partnerStreet:       _selectedCustomer?['street']?.toString() ?? widget.task.partnerStreet,
        partnerCity:         _selectedCustomer?['city']?.toString() ?? widget.task.partnerCity,
        partnerCountry:      _selectedCustomer?['country_id'] is List 
            ? (_selectedCustomer!['country_id'] as List)[1].toString()
            : widget.task.partnerCountry,
        partnerPhone:        _selectedCustomer?['phone']?.toString() ?? widget.task.partnerPhone,
        scheduledStart:      _plannedStart != null ? fmt12(_plannedStart!) : '',
        scheduledEnd:        _plannedEnd != null ? fmt12(_plannedEnd!) : '',
        deadline:            _plannedEnd != null ? parseOdooDt(_plannedEnd) : '',
        priority:            _priority,
        description:         _descriptionCtrl.text.trim(),
        allocatedHours:      hours,
        underWarranty:       _showWarrantySection ? _underWarranty : widget.task.underWarranty,
        worksheetTemplateId: _showWorksheetSection
            ? (_selectedWorksheet != null ? (_selectedWorksheet!['id'] as num).toInt() : null)
            : widget.task.worksheetTemplateId,
        worksheetTemplateName: _showWorksheetSection
            ? (_selectedWorksheet?['name']?.toString() ?? '')
            : widget.task.worksheetTemplateName,
        projectId:           _selectedProject != null ? (_selectedProject!['id'] as num).toInt() : widget.task.projectId,
        stageId:             _selectedStage != null ? (_selectedStage!['id'] as num).toInt() : widget.task.stageId,
        partnerId:           _selectedCustomer != null ? (_selectedCustomer!['id'] as num).toInt() : widget.task.partnerId,
        assigneeIds:         _assigneeIds.toList(),
        tagIds:              _tagIds.toList(),
        tagNames:            currentTagNames.isNotEmpty ? currentTagNames.join(', ') : widget.task.tagNames,
        plannedDateBegin:    _plannedStart,
        plannedDateEnd:      _plannedEnd,
      );

      Navigator.pop(context, updatedTask);
    } else {
      CustomSnackbar.showError(context, errorMsg);
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
          title: Text('Edit Task',
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
                      _labeled(isDark, 'Customer',
                          _customerField(isDark)),
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
                          : '${selected.length} assignee(s) selected',
                      style: TextStyle(
                          fontSize: 14,
                          color: selected.isEmpty
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87)),
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

  // Dynamic Customer Search Field
  Widget _customerField(bool isDark) {
    return CompositedTransformTarget(
      link: _customerLink,
      child: Container(
        decoration: _fieldDeco(isDark),
        child: TextField(
          controller: _customerCtrl,
          focusNode: _customerFocus,
          readOnly: _selectedCustomer != null,
          style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: _selectedCustomer != null
                  ? FontWeight.w500
                  : FontWeight.w400),
          decoration: InputDecoration(
            hintText: 'Search customer...',
            hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: InputBorder.none,
            prefixIcon: _selectedCustomer == null
                ? Icon(Icons.person_outline_rounded,
                    size: 17,
                    color: isDark ? Colors.white38 : Colors.black38)
                : null,
            suffixIcon: _selectedCustomer != null
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCustomer = null;
                        _customerCtrl.clear();
                        _phoneCtrl.clear();
                      });
                    },
                    child: Icon(Icons.close_rounded,
                        size: 17,
                        color: isDark ? Colors.white38 : Colors.black45))
                : _searchingCustomers
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
                          : '${selected.length} tag(s) selected',
                      style: TextStyle(
                          fontSize: 14,
                          color: selected.isEmpty
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87)),
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
            borderSide: const BorderSide(color: Colors.red, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.4)),
      ),
      validator: validator,
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

  Widget _dateField(bool isDark, DateTime? val, String placeholder,
      VoidCallback onTap, VoidCallback onClear) {
    return Container(
      decoration: _fieldDeco(isDark),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(
          val != null
              ? '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}  ${val.hour.toString().padLeft(2, '0')}:${val.minute.toString().padLeft(2, '0')}'
              : placeholder,
          style: TextStyle(
              fontSize: 14,
              fontWeight: val != null ? FontWeight.w500 : FontWeight.w400,
              color: val != null
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white38 : Colors.black38)),
        ),
        trailing: val != null
            ? GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 17, color: isDark ? Colors.white38 : Colors.black45),
              )
            : Icon(Icons.calendar_today_rounded,
                size: 16, color: isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }

  Widget _card(
      {required bool isDark,
      required String title,
      required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _labeled(bool isDark, String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black45)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  Widget _chip(bool isDark, String label, Color fill, Color text,
      VoidCallback onDelete) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
          color: fill, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(width: 4),
          GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.close_rounded, size: 14, color: text)),
        ],
      ),
    );
  }

  Widget _createButton(bool isDark) {
    final enabled = _canSubmit;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor:
              isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? Colors.white
                      : (isDark ? Colors.white24 : Colors.black26),
                ),
              ),
        ),
    );
  }

  // ── Overlay implementation ──────────────────────────────────────────────────

  void _showSimpleOverlay({
    required LayerLink link,
    required void Function(OverlayEntry) overlayRef,
    required List<Map<String, dynamic>> items,
    required void Function(Map<String, dynamic>) onSelect,
    Color Function(String)? colorFn,
  }) {
    _removeAllOverlays();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: link.leaderSize?.width ?? 200,
        child: CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: isDark ? const Color(0xFF252836) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No options found',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final name = item['name']?.toString() ?? '';
                        Color? tColor;
                        if (colorFn != null) tColor = colorFn(name);

                        return InkWell(
                          onTap: () => onSelect(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: tColor ??
                                      (isDark ? Colors.white : Colors.black87)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    overlayRef(entry);
  }

  // Multi-select assignee checkbox overlay
  void _openAssigneeOverlay() {
    if (_assigneeOverlay != null) {
      _assigneeOverlay?.remove();
      _assigneeOverlay = null;
      return;
    }
    _removeAllOverlays();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: _assigneeLink.leaderSize?.width ?? 200,
        child: CompositedTransformFollower(
          link: _assigneeLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: isDark ? const Color(0xFF252836) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: StatefulBuilder(
              builder: (context, setOverlayState) => Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: _users.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No users loaded',
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _users.length,
                        itemBuilder: (context, i) {
                          final u    = _users[i];
                          final id   = (u['id'] as num).toInt();
                          final name = u['name']?.toString() ?? '';
                          final isSel = _assigneeIds.contains(id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSel) {
                                  _assigneeIds.remove(id);
                                } else {
                                  _assigneeIds.add(id);
                                }
                              });
                              setOverlayState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: isSel,
                                      activeColor: primaryColor,
                                      onChanged: (v) {
                                        setState(() {
                                          if (isSel) {
                                            _assigneeIds.remove(id);
                                          } else {
                                            _assigneeIds.add(id);
                                          }
                                        });
                                        setOverlayState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSel
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87),
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

    overlay.insert(entry);
    _assigneeOverlay = entry;
  }

  // Multi-select tags checkbox overlay
  void _openTagOverlay() {
    if (_tagOverlay != null) {
      _tagOverlay?.remove();
      _tagOverlay = null;
      return;
    }
    _removeAllOverlays();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: _tagLink.leaderSize?.width ?? 200,
        child: CompositedTransformFollower(
          link: _tagLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: isDark ? const Color(0xFF252836) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: StatefulBuilder(
              builder: (context, setOverlayState) => Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: _tags.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No tags loaded',
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _tags.length,
                        itemBuilder: (context, i) {
                          final t    = _tags[i];
                          final id   = (t['id'] as num).toInt();
                          final name = t['name']?.toString() ?? '';
                          final isSel = _tagIds.contains(id);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSel) {
                                  _tagIds.remove(id);
                                } else {
                                  _tagIds.add(id);
                                }
                              });
                              setOverlayState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: isSel,
                                      activeColor: primaryColor,
                                      onChanged: (v) {
                                        setState(() {
                                          if (isSel) {
                                            _tagIds.remove(id);
                                          } else {
                                            _tagIds.add(id);
                                          }
                                        });
                                        setOverlayState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSel
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87),
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

    overlay.insert(entry);
    _tagOverlay = entry;
  }

  // ── DateTime Picker ────────────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_plannedStart ?? now)
        : (_plannedEnd ?? _plannedStart ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    if (!mounted) return;

    final result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isStart) {
      if (_plannedEnd != null && result.isAfter(_plannedEnd!)) {
        CustomSnackbar.showWarning(context, 'Planned start date must be before planned end date.');
        return;
      }
      setState(() => _plannedStart = result);
    } else {
      if (_plannedStart != null && result.isBefore(_plannedStart!)) {
        CustomSnackbar.showWarning(context, 'Planned end date must be after planned start date.');
        return;
      }
      setState(() => _plannedEnd = result);
    }
  }

  // ── Customer search debounce ────────────────────────────────────────────────

  void _onCustomerChanged(String val) {
    _customerDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _customerResults = [];
        _searchingCustomers = false;
      });
      _customerOverlay?.remove();
      _customerOverlay = null;
      return;
    }
    _customerDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searchingCustomers = true);
      final list = await _service.fetchCustomers(search: val);
      if (!mounted) return;
      setState(() {
        _customerResults = list;
        _searchingCustomers = false;
      });
      _showCustomerSearchOverlay();
    });
  }

  void _showCustomerSearchOverlay() {
    _removeAllOverlays();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: _customerLink.leaderSize?.width ?? 200,
        child: CompositedTransformFollower(
          link: _customerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            color: isDark ? const Color(0xFF252836) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: _customerResults.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No customers found',
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _customerResults.length,
                      itemBuilder: (context, i) {
                        final item = _customerResults[i];
                        final name = item['name']?.toString() ?? '';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCustomer = item;
                              _customerCtrl.text = name;
                              _phoneCtrl.text = item['phone']?.toString() ?? '';
                            });
                            _customerOverlay?.remove();
                            _customerOverlay = null;
                            _customerFocus.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _customerOverlay = entry;
  }

  BoxDecoration _fieldDeco(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(10),
    );
  }
}

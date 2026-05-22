import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

import '../model/worksheet_field_model.dart';
import '../model/worksheet_form_controller.dart';
import '../services/worksheet_service.dart';


class WorksheetScreen extends StatefulWidget {
  final int taskId;
  final String taskName;

  const WorksheetScreen({
    super.key,
    required this.taskId,
    required this.taskName,
  });

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  final _service = WorksheetService();

  bool _loadingAction = true;
  bool _loadingFields = false;
  bool _loadingRecord = false;
  bool _saving = false;
  String? _errorMessage;

  String? _worksheetModel;
  String _taskLinkField = 'x_project_task_id';
  List<WorksheetFieldMeta> _fields = [];
  int? _recordId;

  late WorksheetFormController _formCtrl;
  bool _formInitialised = false;

  final Map<String, List<RelationOption>> _relationCache = {};
  final Map<String, bool> _relationLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_formInitialised) _formCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loadingAction = true;
      _loadingFields = false;
      _loadingRecord = false;
      _errorMessage = null;
    });

    final action = await _service.fetchWorksheetAction(widget.taskId);
    if (!mounted) return;
    if (action == null) {
      setState(() {
        _loadingAction = false;
        _errorMessage = 'Could not load worksheet action. Please try again.';
      });
      return;
    }
    _worksheetModel = action.resModel;
    _taskLinkField = action.taskLinkField;
    setState(() { _loadingAction = false; _loadingFields = true; });

    final fields = await _service.fetchFieldsMeta(_worksheetModel!);
    if (!mounted) return;
    if (fields.isEmpty) {
      setState(() {
        _loadingFields = false;
        _errorMessage = 'No fields found for worksheet model.';
      });
      return;
    }
    _fields = fields;
    setState(() { _loadingFields = false; _loadingRecord = true; });

    final record = await _service.fetchRecord(
        _worksheetModel!, widget.taskId, _fields, _taskLinkField);
    if (!mounted) return;

    _formCtrl = WorksheetFormController(fields: _fields);
    if (record != null) {
      _recordId = (record['id'] as num?)?.toInt();
      _formCtrl.loadFromRecord(record);
    } else {
      _formCtrl.loadDefaults();
    }
    // Always set name field to task name (auto-fill, not user-editable)
    _formCtrl.set('name', widget.taskName);
    _formInitialised = true;

    for (final f in _fields) {
      if ((f.type == 'many2one' || f.type == 'many2many') &&
          f.relation != null) {
        _loadRelationOptions(f);
      }
    }

    setState(() => _loadingRecord = false);
  }

  Future<void> _loadRelationOptions(WorksheetFieldMeta f) async {
    if (f.relation == null) return;
    setState(() => _relationLoading[f.name] = true);
    final opts = await _service.fetchRelationOptions(f.relation!);
    if (!mounted) return;
    setState(() {
      _relationCache[f.name] = opts;
      _relationLoading[f.name] = false;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final errors = _formCtrl.validate();
    if (errors.isNotEmpty) {
      CustomSnackbar.showError(context, 'Required: ${errors.join(', ')}');
      return;
    }
    setState(() => _saving = true);

    final vals = {
      ..._formCtrl.buildWriteVals(),
      ..._formCtrl.buildBinaryVals(),
    };

    String? errorMsg;
    if (_recordId != null) {
      errorMsg =
          await _service.writeRecord(_worksheetModel!, _recordId!, vals);
    } else {
      vals[_taskLinkField] = widget.taskId;
      final res = await _service.createRecord(_worksheetModel!, vals);
      errorMsg = res.error;
      if (res.id != null) _recordId = res.id;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (errorMsg == null) {
      CustomSnackbar.showSuccess(context, 'Worksheet saved successfully.');
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.showError(context, errorMsg);
    }
  }

  void _rebuild() => setState(() {});

  bool _shouldShowField(WorksheetFieldMeta f) {
    final n = f.name.toLowerCase();
    if (n.startsWith('x_studio_binary_')) return false;
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14161E) : const Color(0xFFF2F3F7);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bg,
        appBar: _buildAppBar(isDark, bg),
        body: _buildBody(isDark),
        bottomNavigationBar: (!_loadingAction &&
                !_loadingFields &&
                !_loadingRecord &&
                _errorMessage == null &&
                _formInitialised)
            ? _buildSaveButton(isDark)
            : null,
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, Color bg) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: bg,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.black),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Worksheet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (widget.taskName.isNotEmpty)
            Text(
              widget.taskName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loadingAction || _loadingFields || _loadingRecord) {
      return _LoadingPhase(
        isDark: isDark,
        message: _loadingAction
            ? 'Loading worksheet...'
            : _loadingFields
                ? 'Loading fields...'
                : 'Loading data...',
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(
          isDark: isDark, message: _errorMessage!, onRetry: _load);
    }
    if (!_formInitialised || _fields.isEmpty) {
      return _ErrorState(
        isDark: isDark,
        message: 'No worksheet fields to display.',
        onRetry: _load,
      );
    }

    return Stack(
      children: [
        _buildForm(isDark),
        if (_saving)
          Container(
            color: Colors.black26,
            child: const Center(
              child:
                  CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
            ),
          ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    );
    final visibleFields = _fields.where(_shouldShowField).toList();

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16, 8, 16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [shadow],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Worksheet Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...visibleFields.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildFieldRow(isDark, f),
                        )),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            disabledBackgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  _recordId != null ? 'Update Worksheet' : 'Save Worksheet',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }

  // ── Per-field row ─────────────────────────────────────────────────────────

  Widget _buildFieldRow(bool isDark, WorksheetFieldMeta f) {
    // Boolean renders its own label inline — skip the label row
    if (f.type == 'boolean' && !f.readonly) {
      return _buildFieldWidget(isDark, f);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          f.required ? '${f.label} *' : f.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
        const SizedBox(height: 6),
        _buildFieldWidget(isDark, f),
      ],
    );
  }

  Widget _buildFieldWidget(bool isDark, WorksheetFieldMeta f) {
    if (f.readonly || f.name == 'name') {
      return _ReadonlyValue(isDark: isDark, field: f, formCtrl: _formCtrl);
    }
    switch (f.type) {
      case 'char':
        return _CharField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'text':
        return _TextAreaField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'html':
        return _HtmlField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'integer':
        return _IntegerField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'float':
        return _FloatField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'boolean':
        return _BooleanField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'selection':
        return _SelectionField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'date':
        return _DateField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'datetime':
        return _DateTimeField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      case 'many2one':
        return _Many2oneField(
          isDark: isDark,
          field: f,
          formCtrl: _formCtrl,
          options: _relationCache[f.name] ?? [],
          loading: _relationLoading[f.name] ?? false,
          onChanged: _rebuild,
        );
      case 'many2many':
        return _Many2manyField(
          isDark: isDark,
          field: f,
          formCtrl: _formCtrl,
          options: _relationCache[f.name] ?? [],
          loading: _relationLoading[f.name] ?? false,
          onChanged: _rebuild,
        );
      case 'binary':
        final isSign = f.name.toLowerCase().contains('sign') ||
            f.label.toLowerCase().contains('sign');
        if (isSign) {
          return _SignatureField(
              isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
        }
        return _BinaryField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
      default:
        return _CharField(
            isDark: isDark, field: f, formCtrl: _formCtrl, onChanged: _rebuild);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared decoration helpers
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _fieldDeco(bool isDark) => BoxDecoration(
      color: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(10),
    );

InputDecoration _inputDeco(bool isDark, String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
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
    );

// ─────────────────────────────────────────────────────────────────────────────
// Readonly display
// ─────────────────────────────────────────────────────────────────────────────

class _ReadonlyValue extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;

  const _ReadonlyValue(
      {required this.isDark, required this.field, required this.formCtrl});

  @override
  Widget build(BuildContext context) {
    final v = formCtrl.values[field.name];
    String display;
    if (field.type == 'many2one' && v is List && v.length >= 2) {
      display = v[1].toString();
    } else if (field.type == 'many2many' && v is List) {
      display = v
          .map((e) =>
              e is List && e.length >= 2 ? e[1].toString() : e.toString())
          .join(', ');
    } else if (field.type == 'selection') {
      final match = field.selection.firstWhere(
          (s) => s.isNotEmpty && s[0].toString() == v?.toString(),
          orElse: () => []);
      display = match.length >= 2 ? match[1].toString() : v?.toString() ?? '';
    } else if (field.type == 'boolean') {
      display = v == true ? 'Yes' : 'No';
    } else {
      display = v?.toString() ?? '';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _fieldDeco(isDark),
      child: Text(
        display.isEmpty ? '—' : display,
        style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// char
// ─────────────────────────────────────────────────────────────────────────────

class _CharField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _CharField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: formCtrl.textControllers[field.name],
      maxLength: field.size,
      style:
          TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDeco(isDark, field.label).copyWith(counterText: ''),
      onChanged: (v) {
        formCtrl.set(field.name, v);
        onChanged();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// text (multi-line)
// ─────────────────────────────────────────────────────────────────────────────

class _TextAreaField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _TextAreaField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: formCtrl.textControllers[field.name],
      maxLines: null,
      minLines: 3,
      style:
          TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDeco(isDark, field.label),
      onChanged: (v) {
        formCtrl.set(field.name, v);
        onChanged();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// html
// ─────────────────────────────────────────────────────────────────────────────

class _HtmlField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _HtmlField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF1F3F5),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(
            children: [
              Icon(Icons.code_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(width: 6),
              Text('HTML',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
        ),
        TextField(
          controller: formCtrl.textControllers[field.name],
          maxLines: null,
          minLines: 4,
          style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: isDark ? Colors.white : Colors.black87),
          decoration: _inputDeco(isDark, '<p>...</p>').copyWith(
            border: const OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide.none),
            enabledBorder: const OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide.none),
            focusedBorder: const OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: primaryColor, width: 1.4)),
          ),
          onChanged: (v) {
            formCtrl.set(field.name, v);
            onChanged();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// integer
// ─────────────────────────────────────────────────────────────────────────────

class _IntegerField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _IntegerField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: formCtrl.textControllers[field.name],
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style:
          TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDeco(isDark, '0'),
      onChanged: (v) {
        formCtrl.set(field.name, int.tryParse(v) ?? 0);
        onChanged();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// float
// ─────────────────────────────────────────────────────────────────────────────

class _FloatField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _FloatField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: formCtrl.textControllers[field.name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      style:
          TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDeco(isDark, '0.00'),
      onChanged: (v) {
        formCtrl.set(field.name, double.tryParse(v) ?? 0.0);
        onChanged();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// boolean
// ─────────────────────────────────────────────────────────────────────────────

class _BooleanField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _BooleanField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final val = formCtrl.values[field.name] == true;
    final label = field.required ? '${field.label} *' : field.label;
    return InkWell(
      onTap: () {
        formCtrl.set(field.name, !val);
        onChanged();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: val ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: val
                      ? primaryColor
                      : (isDark ? Colors.white38 : Colors.black38),
                  width: 1.8,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: val
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// selection
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _SelectionField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rawCurrent = formCtrl.values[field.name]?.toString();
    final current = (rawCurrent == null || rawCurrent.isEmpty) ? null : rawCurrent;
    final seen = <String?>{};
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('— Select —')),
      ...field.selection.expand((s) {
        final value = s.isNotEmpty ? s[0].toString() : '';
        if (value.isEmpty || seen.contains(value)) return <DropdownMenuItem<String?>>[];
        seen.add(value);
        final label = s.length >= 2 ? s[1].toString() : value;
        return [DropdownMenuItem<String?>(value: value, child: Text(label))];
      }),
    ];

    return Container(
      decoration: _fieldDeco(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: current,
          isExpanded: true,
          menuMaxHeight: 280,
          dropdownColor: isDark ? const Color(0xFF252836) : Colors.white,
          style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white38 : Colors.black38),
          items: items,
          onChanged: (v) {
            formCtrl.set(field.name, v);
            onChanged();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// date
// ─────────────────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _DateField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final raw = formCtrl.values[field.name]?.toString() ?? '';
    final initial = DateTime.tryParse(raw) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _wsPicker,
    );
    if (picked == null) return;
    formCtrl.set(
      field.name,
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final val = formCtrl.values[field.name]?.toString() ?? '';
    return _DateTimeContainer(
      isDark: isDark,
      value: val,
      placeholder: 'Select date',
      icon: Icons.calendar_today_rounded,
      onTap: () => _pick(context),
      onClear: () {
        formCtrl.set(field.name, '');
        onChanged();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// datetime
// ─────────────────────────────────────────────────────────────────────────────

class _DateTimeField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _DateTimeField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final raw = formCtrl.values[field.name]?.toString() ?? '';
    final initial =
        DateTime.tryParse(raw.replaceFirst(' ', 'T')) ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _wsPicker,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: _wsPicker,
    );
    if (time == null) return;

    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    formCtrl.set(
      field.name,
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00',
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final val = formCtrl.values[field.name]?.toString() ?? '';
    return _DateTimeContainer(
      isDark: isDark,
      value: val,
      placeholder: 'Select date & time',
      icon: Icons.access_time_rounded,
      onTap: () => _pick(context),
      onClear: () {
        formCtrl.set(field.name, '');
        onChanged();
      },
    );
  }
}

// Shared tappable container for date / datetime
class _DateTimeContainer extends StatelessWidget {
  final bool isDark;
  final String value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTimeContainer({
    required this.isDark,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasVal = value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: _fieldDeco(isDark),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasVal ? value : placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: hasVal
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
            if (hasVal)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 17,
                    color: isDark ? Colors.white38 : Colors.black45),
              )
            else
              Icon(icon,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}

// Shared date/time picker theme
Widget _wsPicker(BuildContext context, Widget? child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: primaryColor,
            onPrimary: Colors.white,
            onSurface: isDark ? Colors.white : Colors.black87,
            surface: isDark ? const Color(0xFF1E2028) : Colors.white,
          ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1E2028) : Colors.white,
        headerBackgroundColor: primaryColor,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        todayForegroundColor: WidgetStateProperty.all(Colors.blue),
        todayBorder: const BorderSide(color: primaryColor, width: 1),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor:
            isDark ? const Color(0xFF1E2028) : Colors.white,
        hourMinuteColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primaryColor
                : (isDark
                    ? const Color(0xFF2A2D3E)
                    : const Color(0xFFF1F3F5))),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87)),
        dialHandColor: primaryColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        entryModeIconColor: primaryColor,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
    ),
    child: child!,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// many2one
// ─────────────────────────────────────────────────────────────────────────────

class _Many2oneField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final List<RelationOption> options;
  final bool loading;
  final VoidCallback onChanged;

  const _Many2oneField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.options,
      required this.loading,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (loading) return _RelationLoader(isDark: isDark);

    final val = formCtrl.values[field.name];
    int? currentId;
    if (val is List && val.isNotEmpty) {
      currentId = (val[0] as num).toInt();
    }

    return Container(
      decoration: _fieldDeco(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentId,
          isExpanded: true,
          menuMaxHeight: 280,
          dropdownColor: isDark ? const Color(0xFF252836) : Colors.white,
          style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white38 : Colors.black38),
          items: [
            const DropdownMenuItem<int>(
                value: null, child: Text('— Select —')),
            ...options.map((o) =>
                DropdownMenuItem<int>(value: o.id, child: Text(o.name))),
          ],
          onChanged: (id) {
            if (id == null) {
              formCtrl.set(field.name, null);
            } else {
              final opt = options.firstWhere((o) => o.id == id);
              formCtrl.set(field.name, [opt.id, opt.name]);
            }
            onChanged();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// many2many
// ─────────────────────────────────────────────────────────────────────────────

class _Many2manyField extends StatefulWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final List<RelationOption> options;
  final bool loading;
  final VoidCallback onChanged;

  const _Many2manyField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.options,
      required this.loading,
      required this.onChanged});

  @override
  State<_Many2manyField> createState() => _Many2manyFieldState();
}

class _Many2manyFieldState extends State<_Many2manyField> {
  Set<int> get _selected {
    final v = widget.formCtrl.values[widget.field.name];
    if (v is! List) return {};
    return v
        .map((e) => e is List && e.isNotEmpty ? (e[0] as num).toInt() : -1)
        .where((id) => id >= 0)
        .toSet();
  }

  void _toggle(RelationOption opt) {
    final sel = Set<int>.from(_selected);
    sel.contains(opt.id) ? sel.remove(opt.id) : sel.add(opt.id);
    final newVal = widget.options
        .where((o) => sel.contains(o.id))
        .map((o) => [o.id, o.name])
        .toList();
    widget.formCtrl.set(widget.field.name, newVal);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return _RelationLoader(isDark: widget.isDark);

    final sel = _selected;
    final selectedOpts =
        widget.options.where((o) => sel.contains(o.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedOpts.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedOpts.map((o) => _chip(o)).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: _fieldDeco(widget.isDark),
          constraints: const BoxConstraints(maxHeight: 180),
          child: widget.options.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No options available',
                      style: TextStyle(
                          fontSize: 14,
                          color: widget.isDark
                              ? Colors.white38
                              : Colors.black38)),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: widget.options
                      .map((o) => _optionTile(o, sel.contains(o.id)))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _chip(RelationOption o) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(o.name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _toggle(o),
            child: const Icon(Icons.close_rounded,
                size: 14, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(RelationOption o, bool isSel) {
    return InkWell(
      onTap: () => _toggle(o),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isSel,
                activeColor: primaryColor,
                onChanged: (_) => _toggle(o),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(o.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSel ? FontWeight.w600 : FontWeight.w400,
                      color: widget.isDark
                          ? Colors.white
                          : Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// signature (draw or upload)
// ─────────────────────────────────────────────────────────────────────────────

class _SignatureField extends StatefulWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _SignatureField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  @override
  State<_SignatureField> createState() => _SignatureFieldState();
}

class _SignatureFieldState extends State<_SignatureField> {
  final List<List<Offset>> _strokes = [];
  final _canvasKey = GlobalKey();

  Size get _canvasSize {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? const Size(300, 160);
  }

  Future<void> _saveDrawing() async {
    final sz = _canvasSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, sz.width, sz.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sz.width, sz.height),
      Paint()
        ..color = widget.isDark
            ? const Color(0xFF2A2D3E)
            : Colors.white,
    );
    final paint = Paint()
      ..color = widget.isDark ? Colors.white : Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        // Use quadratic bezier for smooth curves
        if (i < stroke.length - 1) {
          final mid = Offset(
            (stroke[i].dx + stroke[i + 1].dx) / 2,
            (stroke[i].dy + stroke[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(
              stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(sz.width.toInt(), sz.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    widget.formCtrl.set(
        widget.field.name, base64Encode(bytes.buffer.asUint8List()));
    widget.onChanged();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    widget.formCtrl.set(widget.field.name, base64Encode(bytes));
    widget.onChanged();
  }

  void _clearDrawing() {
    setState(() => _strokes.clear());
    widget.formCtrl.set(widget.field.name, null);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final canvasBg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final val = widget.formCtrl.values[widget.field.name];
    final hasSaved = val != null && val.toString().isNotEmpty;
    // Show saved preview when no new strokes have been drawn yet
    final showPreview = hasSaved && _strokes.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Saved signature preview ───────────────────────────────────
        if (showPreview) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(val.toString()),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: canvasBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
              ),
              // "Re-sign" badge overlay
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _strokes.clear());
                    widget.formCtrl.set(widget.field.name, null);
                    widget.onChanged();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Re-sign',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // ── Drawing canvas ──────────────────────────────────────────
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _EagerPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _EagerPanGestureRecognizer>(
                () => _EagerPanGestureRecognizer(),
                (_EagerPanGestureRecognizer r) {
                  r.onStart = (d) =>
                      setState(() => _strokes.add([d.localPosition]));
                  r.onUpdate = (d) =>
                      setState(() => _strokes.last.add(d.localPosition));
                  r.onEnd = (_) => _saveDrawing();
                },
              ),
            },
            child: Container(
              key: _canvasKey,
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: canvasBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CustomPaint(
                  painter:
                      _SignaturePainter(strokes: _strokes, isDark: isDark),
                  child: _strokes.isEmpty
                      ? Center(
                          child: Text(
                            'Sign here',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black26,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),

        // ── Action buttons row ────────────────────────────────────────
        Row(
          children: [
            // Upload
            Expanded(
              child: _SigButton(
                icon: Icons.upload_file_outlined,
                label: 'Upload',
                color: isDark ? Colors.white70 : Colors.black54,
                bgColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                onTap: _pickImage,
              ),
            ),
            const SizedBox(width: 8),

            // Clear — clears drawing strokes or saved data
            Expanded(
              child: _SigButton(
                icon: Icons.close_rounded,
                label: 'Clear',
                color: primaryColor,
                bgColor: primaryColor.withValues(alpha: 0.08),
                onTap: (hasSaved || _strokes.isNotEmpty) ? _clearDrawing : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _SigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final effectiveColor = disabled ? color.withValues(alpha: 0.35) : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: disabled ? bgColor.withValues(alpha: 0.4) : bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool isDark;

  const _SignaturePainter({required this.strokes, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white : Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        if (i < stroke.length - 1) {
          final mid = Offset(
            (stroke[i].dx + stroke[i + 1].dx) / 2,
            (stroke[i].dy + stroke[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(
              stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// Wins the gesture arena immediately so the parent scroll never steals the drag.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// binary (image upload)
// ─────────────────────────────────────────────────────────────────────────────

class _BinaryField extends StatelessWidget {
  final bool isDark;
  final WorksheetFieldMeta field;
  final WorksheetFormController formCtrl;
  final VoidCallback onChanged;

  const _BinaryField(
      {required this.isDark,
      required this.field,
      required this.formCtrl,
      required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    formCtrl.set(field.name, base64Encode(bytes));
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final val = formCtrl.values[field.name];
    final hasImage = val != null && val.toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              base64Decode(val.toString()),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 180,
                decoration: _fieldDeco(isDark),
                child: Center(
                    child: Icon(Icons.broken_image_rounded,
                        color:
                            isDark ? Colors.white38 : Colors.black38)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pick(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: _fieldDeco(isDark),
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 10),
                      Text(
                        hasImage ? 'Change image' : 'Upload image',
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white54
                                : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  formCtrl.set(field.name, null);
                  onChanged();
                },
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared loading indicator for relation fields
// ─────────────────────────────────────────────────────────────────────────────

class _RelationLoader extends StatelessWidget {
  final bool isDark;
  const _RelationLoader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _fieldDeco(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: primaryColor, strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Loading...',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading phase
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingPhase extends StatelessWidget {
  final bool isDark;
  final String message;

  const _LoadingPhase({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: primaryColor, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState(
      {required this.isDark,
      required this.message,
      required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48,
                color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

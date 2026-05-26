import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/const/app_colors.dart';
import '../../model/task_model.dart';
import '../../model/task_product_model.dart';
import '../../services/task_product_service.dart';
import 'shimmer_bone.dart';
import 'package:mobo_feild_service/shared/widgets/snackbars/custom_snackbar.dart';

class ProductsContent extends StatefulWidget {
  final TaskModel task;
  final bool isDark;

  const ProductsContent({
    super.key,
    required this.task,
    required this.isDark,
  });

  @override
  State<ProductsContent> createState() => _ProductsContentState();
}

class _ProductsContentState extends State<ProductsContent> {
  final _service = TaskProductService();
  List<TaskProductLine>? _lines;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lines = await _service.fetchLines(widget.task.id);
    if (mounted) setState(() { _lines = lines; _loading = false; });
  }

  Future<void> _showAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductBottomSheet(
        isDark: widget.isDark,
        service: _service,
        taskId: widget.task.id,
      ),
    );
    if (added == true) _load();
  }

  Future<void> _deleteLine(TaskProductLine line) async {

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2028) : Colors.white,
        title: const Text('Remove Product'),
        content: Text('Remove "${line.productName}" from this task?'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await _service.deleteLine(line.id);
    if (!mounted) return;
    if (ok) {
      _load();
      CustomSnackbar.showSuccess(context, 'Product removed');
    } else {
      CustomSnackbar.showError(context, 'Failed to remove product');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (_loading) return _ProductsShimmer(isDark: isDark);

    final lines = _lines ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// ── Header row ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Product'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        /// ── Empty state ─────────────────────────────────────────────
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/lotties/empty ghost.json',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No products added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap Add to add a product',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          /// ── Table ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _ProductTable(
              lines: lines,
              isDark: isDark,
              onDelete: _deleteLine,
              onQtyChanged: (lineId, qty) => _service.updateLine(
                lineId: lineId,
                qty: qty,
                priceUnit: lines.firstWhere((l) => l.id == lineId).priceUnit,
              ),
            ),
          ),
          SizedBox(height: 20,)


        ],
      ],
    );
  }

  String _fmtPrice(double v) => v.toStringAsFixed(2);
}

/// ── Table ──────────────────────────────────────────────────────────────────────

class _ProductTable extends StatelessWidget {
  final List<TaskProductLine> lines;
  final bool isDark;
  final ValueChanged<TaskProductLine> onDelete;
  final Future<bool> Function(int lineId, double qty) onQtyChanged;

  const _ProductTable({
    required this.lines,
    required this.isDark,
    required this.onDelete,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final headerBg = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF8F9FA);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white70 : Colors.grey[700],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            /// Header
            Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text('Product', style: headerStyle)),
                  Expanded(flex: 4, child: Text('Qty', style: headerStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('Subtotal', style: headerStyle, textAlign: TextAlign.center)),
                  const SizedBox(width: 32),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            ...lines.asMap().entries.map((e) {
              final i = e.key;
              final line = e.value;
              final isLast = i == lines.length - 1;
              return Column(
                children: [
                  _ProductRow(
                    line: line,
                    isDark: isDark,
                    onDelete: () => onDelete(line),
                    onQtyChanged: (qty) => onQtyChanged(line.id, qty),
                  ),
                  if (!isLast) Divider(height: 1, color: borderColor),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatefulWidget {
  final TaskProductLine line;
  final bool isDark;
  final VoidCallback onDelete;
  final Future<bool> Function(double qty) onQtyChanged;

  const _ProductRow({
    required this.line,
    required this.isDark,
    required this.onDelete,
    required this.onQtyChanged,
  });

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  late double _qty;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _qty = widget.line.qty;
  }

  Future<void> _changeQty(double delta) async {
    final newQty = _qty + delta;
    if (newQty < 1) return; /// minimum qty is 1
    setState(() { _qty = newQty; _updating = true; });
    final ok = await widget.onQtyChanged(newQty);
    if (mounted) setState(() => _updating = false);
    if (!ok && mounted) {
      setState(() => _qty = widget.line.qty); /// revert on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final line = widget.line;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final subtotal = _qty * line.priceUnit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          /// Product name + uom
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.uomName.isNotEmpty)
                  Text(
                    line.uomName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
          // Qty stepper
          Expanded(
            flex: 4,
            child: _updating
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StepBtn(
                        icon: Icons.remove,
                        enabled: _qty > 1,
                        isDark: isDark,
                        borderColor: borderColor,
                        onTap: () => _changeQty(-1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _fmtNum(_qty),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      _StepBtn(
                        icon: Icons.add,
                        enabled: true,
                        isDark: isDark,
                        borderColor: borderColor,
                        onTap: () => _changeQty(1),
                      ),
                    ],
                  ),
          ),
          /// Subtotal
          Expanded(
            flex: 3,
            child: Text(
              subtotal.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          /// Delete
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? const Color(0xFF2A2D36) : primaryColor)
              : (isDark ? const Color(0xFF1E2028) : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled
              ? (isDark ? Colors.white70 : Colors.white)
              : (isDark ? Colors.white24 : Colors.black12),
        ),
      ),
    );
  }
}

/// ── Add / Edit bottom sheet ────────────────────────────────────────────────────

class _ProductBottomSheet extends StatefulWidget {
  final bool isDark;
  final TaskProductService service;
  final int taskId;

  const _ProductBottomSheet({
    required this.isDark,
    required this.service,
    required this.taskId,
  });

  @override
  State<_ProductBottomSheet> createState() => _ProductBottomSheetState();
}

class _ProductBottomSheetState extends State<_ProductBottomSheet> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  ProductSuggestion? _selectedProduct;
  List<ProductSuggestion> _suggestions = [];
  bool _searching = false;
  bool _saving = false;
  Timer? _debounce;
  double _price = 0.0;

  @override
  void initState() {
    super.initState();
    _qtyCtrl.text = '1';
    _fetchSuggestions('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    setState(() { _selectedProduct = null; _suggestions = []; _price = 0.0; });
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _searching = true);
    final results = await widget.service.searchProducts(q);
    if (mounted) setState(() { _suggestions = results; _searching = false; });
  }

  void _selectProduct(ProductSuggestion p) {
    setState(() {
      _selectedProduct = p;
      _searchCtrl.text = p.name;
      _suggestions = [];
      _price = p.listPrice;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final product = _selectedProduct;
    if (product == null) {
      CustomSnackbar.showError(context, 'Please select a product');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      CustomSnackbar.showError(context, 'Quantity must be greater than 0');
      return;
    }

    setState(() => _saving = true);

    final id = await widget.service.addLine(
      taskId: widget.taskId,
      productId: product.id,
      qty: qty,
      priceUnit: _price,
    );
    final ok = id != null;

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      CustomSnackbar.showError(context, 'Failed to save product');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF1E2028) : Colors.white;
    final inputBg = isDark ? const Color(0xFF2A2D36) : const Color(0xFFF5F5F5);
    final labelColor = isDark ? Colors.white54 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? const Color(0xFF3A3D46) : const Color(0xFFE0E0E0);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Add Product',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 18),

            /// Product search (disabled when editing)
            _FieldLabel('Product', labelColor),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchCtrl,
                enabled: true,
                onChanged: _onSearchChanged,
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search product...',
                  hintStyle: TextStyle(color: labelColor, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            /// Suggestions dropdown
            if (_suggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, i) => Divider(
                    height: 1,
                    color: borderColor,
                    indent: 14,
                  ),
                  itemBuilder: (_, i) {
                    final p = _suggestions[i];
                    return InkWell(
                      onTap: () => _selectProduct(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textColor)),
                                  if (p.uomName.isNotEmpty)
                                    Text(p.uomName,
                                        style: TextStyle(
                                            fontSize: 11, color: labelColor)),
                                ],
                              ),
                            ),
                            Text(
                              p.listPrice.toStringAsFixed(2),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 14),

            /// Qty + Price row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Quantity', labelColor),
                      const SizedBox(height: 6),
                      _NumField(
                        controller: _qtyCtrl,
                        hint: '1',
                        inputBg: inputBg,
                        borderColor: borderColor,
                        textColor: textColor,
                        labelColor: labelColor,
                        decimal: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            /// Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add Product',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Small helpers ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color));
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color inputBg;
  final Color borderColor;
  final Color textColor;
  final Color labelColor;
  final bool decimal;

  const _NumField({
    required this.controller,
    required this.hint,
    required this.inputBg,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType:
            TextInputType.numberWithOptions(decimal: decimal, signed: false),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(decimal ? r'[\d.]' : r'\d')),
        ],
        style: TextStyle(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: labelColor, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

/// ── Shimmer ────────────────────────────────────────────────────────────────────

class _ProductsShimmer extends StatelessWidget {
  final bool isDark;
  const _ProductsShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF252830) : const Color(0xFFE8E8EC);
    final highlight = isDark ? const Color(0xFF32353F) : const Color(0xFFF4F4F8);
    final divColor = isDark ? const Color(0xFF2A2D36) : const Color(0xFFEEEEEE);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                ShimmerBone(width: 70, height: 14, base: base),
                const Spacer(),
                ShimmerBone(width: 70, height: 32, base: base, radius: 10),
              ],
            ),
          ),
          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: base,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 4, child: ShimmerBone(width: 60, height: 12, base: base)),
                  Expanded(flex: 2, child: ShimmerBone(width: 30, height: 12, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 40, height: 12, base: base)),
                  Expanded(flex: 3, child: ShimmerBone(width: 50, height: 12, base: base)),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: divColor, indent: 16, endIndent: 16),
          for (int i = 0; i < 3; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBone(width: 100, height: 13, base: base),
                          const SizedBox(height: 4),
                          ShimmerBone(width: 50, height: 10, base: base),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: ShimmerBone(width: 24, height: 13, base: base)),
                    Expanded(flex: 3, child: ShimmerBone(width: 40, height: 13, base: base)),
                    Expanded(flex: 3, child: ShimmerBone(width: 48, height: 13, base: base)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShimmerBone(width: 26, height: 26, base: base, radius: 7),
                        const SizedBox(width: 6),
                        ShimmerBone(width: 26, height: 26, base: base, radius: 7),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (i < 2) Divider(height: 1, color: divColor, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

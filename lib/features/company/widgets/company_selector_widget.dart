import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../shared/widgets/toggles/mobo_checkbox.dart';
import '../providers/company_provider.dart';

/// A comprehensive company selector widget with two modes:
/// 1. Compact mode: Dropdown showing active company (for AppBar)
/// 2. Expanded mode: Bottom sheet with multi-select for allowed companies
class CompanySelectorWidget extends StatelessWidget {
  final bool showMultiSelect;
  final VoidCallback? onCompanyChanged;

  const CompanySelectorWidget({
    super.key,
    this.showMultiSelect = false,
    this.onCompanyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.companies.isEmpty) {
          return _buildLoadingState(context);
        }

        if (provider.companies.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildCompactDropdown(context, provider);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),
          Text(
            'No companies',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCompactDropdown(BuildContext context, CompanyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final rawName = provider.selectedCompany?['name']?.toString() ?? 'Select Company';

    final displayName = formatCompanyName(rawName);


    return InkWell(
      onTap: () => _showDropdownMenu(context, provider),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, size: 16, color: textColor),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // Show subtle loading spinner while provider is fetching from server
            if (provider.isLoading || provider.isSwitching) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 18),
          ],
        ),
      ),
    );
  }

  

  void _showDropdownMenu(BuildContext context, CompanyProvider provider) async {
    // Always refetch on open to ensure we display up-to-date companies
    // Fire-and-forget so the UI opens immediately but shows a spinner while loading
    // This will set provider.isLoading = true and the compact button shows spinner
    // The dropdown content will rebuild via Provider/Consumer if used inside
    // broader widgets; here we keep it simple and rely on provider state
    // management to refresh the entries.
    // ignore: unawaited_futures
    provider.initialize();
    final screenSize = MediaQuery.of(context).size;
    // Use bottom sheet on very narrow screens
    if (screenSize.width < 1000) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: _CompanyDropdownContent(
              provider: provider,
              onCompanyChanged: onCompanyChanged,
              width: screenSize.width, // take full width inside sheet
            ),
          );
        },
      );
      return;
    }

    // Popover for wider screens; clamp within viewport and set responsive width
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    final double popoverWidth = math.min(360, screenSize.width - 24);
    final double left = math.max(
      12,
      math.min(buttonPosition.dx, screenSize.width - popoverWidth - 12),
    );
    final double top = math.min(
      buttonPosition.dy + buttonSize.height + 4,
      screenSize.height - 16 - 300, // leave room at bottom
    );

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: popoverWidth,
                  ),
                  child: _CompanyDropdownContent(
                    provider: provider,
                    onCompanyChanged: onCompanyChanged,
                    width: popoverWidth,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
  String formatCompanyName(String name) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    return match != null ? match.group(1)! : name;
  }
}

class _CompanyDropdownContent extends StatefulWidget {
  final CompanyProvider provider;
  final VoidCallback? onCompanyChanged;
  final double? width;

  const _CompanyDropdownContent({
    required this.provider,
    this.onCompanyChanged,
    this.width,
  });

  @override
  State<_CompanyDropdownContent> createState() =>
      _CompanyDropdownContentState();
}

class _CompanyDropdownContentState extends State<_CompanyDropdownContent> {
  late int _tempSelectedCompanyId;
  late Set<int> _tempAllowedCompanyIds;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _tempSelectedCompanyId = widget.provider.selectedCompanyId ?? -1;
    _tempAllowedCompanyIds = widget.provider.selectedAllowedCompanyIds.toSet();
  }

  void _onConfirm() async {
    // If nothing changed, just close
    final noActiveChange = _tempSelectedCompanyId == widget.provider.selectedCompanyId;
    final noAllowedChange = _setEquals(
      _tempAllowedCompanyIds,
      widget.provider.selectedAllowedCompanyIds.toSet(),
    );
    if (noActiveChange && noAllowedChange) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _applying = true);
    bool changed = false;

    try {
      // 1. Switch active company if changed
      if (!noActiveChange) {
        await widget.provider.switchCompany(_tempSelectedCompanyId);
        changed = true;
      }

      // 2. Update allowed companies if changed (do AFTER switching)
      if (!noAllowedChange) {
        await widget.provider.setAllowedCompanies(
          _tempAllowedCompanyIds.toList(),
        );



        changed = true;
      }

      if (changed) {
        widget.onCompanyChanged?.call();
      }

    } finally {
      final companyId = context.read<CompanyProvider>().selectedCompanyId;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final companyProvider = context.read<CompanyProvider>();
        final companyId = companyProvider.selectedCompanyId ?? 1;

             });
      if (mounted) {
        setState(() => _applying = false);
        Navigator.pop(context);
      }
    }
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: widget.width ?? 280,
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner (if any)
          if (widget.provider.error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.provider.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // Company list
          Flexible(
            child: ListView.builder(
              key: Key("listview"),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.provider.companies.length,
              itemBuilder: (context, index) {
                final company = widget.provider.companies[index];
                final companyId = company['id'] as int;
                final companyName = company['name']?.toString() ?? '-';
                final isActive = companyId == _tempSelectedCompanyId;
                final isAllowed = _tempAllowedCompanyIds.contains(companyId);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: isActive
                        ? (primaryColor.withOpacity(0.1))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _applying ? null : () {
                        setState(() {
                          _tempSelectedCompanyId = companyId;
                          // Odoo behavior: When you switch active company, it must be in allowed list
                          _tempAllowedCompanyIds.add(companyId);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            // Checkbox


                            // Company Name
                            Expanded(
                              child: Text(
                                companyName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: MoboCheckbox(
                                value: isAllowed,
                                onChanged: _applying
                                    ? null
                                    : (companyId == _tempSelectedCompanyId)
                                    ? null // active company cannot be unchecked
                                    : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _tempAllowedCompanyIds.add(companyId);
                                    } else {
                                      _tempAllowedCompanyIds.remove(
                                        companyId,
                                      );
                                    }
                                  });
                                },
                                size: 18,
                                // semanticsLabel: 'Allowed company: $companyName',
                              ),
                            ),
                            const SizedBox(width: 8),
                            // if (isActive)
                            //   Container(
                            //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            //     decoration: BoxDecoration(
                            //       color: primaryColor.withOpacity(0.12),
                            //       borderRadius: BorderRadius.circular(999),
                            //       border: Border.all(color: primaryColor.withOpacity(0.3)),
                            //     ),
                            //     child: Row(
                            //       mainAxisSize: MainAxisSize.min,
                            //       children: [
                            //         Icon(Icons.check_circle, size: 14, color: primaryColor),
                            //         const SizedBox(width: 4),
                            //         Text(
                            //           'Active',
                            //           style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _applying
                        ? null
                        : () {
                      setState(() {
                        _tempSelectedCompanyId =
                            widget.provider.selectedCompanyId ?? -1;
                        _tempAllowedCompanyIds = widget
                            .provider
                            .selectedAllowedCompanyIds
                            .toSet();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : primaryColor,
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : primaryColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final noActiveChange = _tempSelectedCompanyId == widget.provider.selectedCompanyId;
                      final noAllowedChange = _setEquals(
                        _tempAllowedCompanyIds,
                        widget.provider.selectedAllowedCompanyIds.toSet(),
                      );
                      final disabled = _applying || widget.provider.isSwitching || (noActiveChange && noAllowedChange);
                      if (!disabled) {
                        _onConfirm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _applying
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Applying...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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

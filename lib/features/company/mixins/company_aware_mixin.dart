import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/company_provider.dart';

/// Mixin to make screens aware of company changes
/// Use this in StatefulWidget states that need to reload data when company changes
mixin CompanyAwareMixin<T extends StatefulWidget> on State<T> {
  int? _lastCompanyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkCompanyChange();
  }

  void _checkCompanyChange() {
    try {
      final companyProvider = context.read<CompanyProvider>();
      final currentCompanyId = companyProvider.selectedCompanyId;

      if (_lastCompanyId != null && _lastCompanyId != currentCompanyId) {
        onCompanyChanged(currentCompanyId);
      }

      _lastCompanyId = currentCompanyId;
    } catch (e) {
    }
  }

  /// Override this method to handle company changes
  /// This will be called when the selected company changes
  void onCompanyChanged(int? newCompanyId) {
    /// Override in your widget to reload data
  }

  /// Helper to get current company ID
  int? getCurrentCompanyId() {
    try {
      return context.read<CompanyProvider>().selectedCompanyId;
    } catch (e) {
      return null;
    }
  }

  /// Helper to check if a specific company is selected
  bool isCompanySelected(int companyId) {
    return getCurrentCompanyId() == companyId;
  }
}

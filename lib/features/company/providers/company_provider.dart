import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/odoo_session_manager.dart';

// Using raw maps for companies to avoid model dependency and ensure UI compatibility

class CompanyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  // Multi-company selection for request context (allowed_company_ids)
  List<int> _selectedAllowedCompanyIds = [];
  bool _loading = false;
  bool _switching = false;
  String? _error;

  List<Map<String, dynamic>> get companies => _companies;
  int? get selectedCompanyId => _selectedCompanyId;
  List<int> get selectedAllowedCompanyIds => _selectedAllowedCompanyIds;
  bool get isLoading => _loading;
  bool get isSwitching => _switching;
  String? get error => _error;

  Map<String, dynamic>? get selectedCompany {
    if (_selectedCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c['id'] == _selectedCompanyId);
    } catch (e) {
      return null;
    }
  }

  /// Update the selected allowed companies for RPC context injection.
  /// This does not change the active company; it controls allowed_company_ids.
  /// Update the selected allowed companies for RPC context injection.
  /// This does not change the active company; it controls allowed_company_ids.
  Future<void> setAllowedCompanies(List<int> allowedIds) async {
    // Filter to companies available to the user
    final availableIds = _companies.map((c) => c['id'] as int).toSet();
    final filtered = allowedIds
        .where((id) => availableIds.contains(id))
        .toList();
    // Ensure active company is present
    if (_selectedCompanyId != null && !filtered.contains(_selectedCompanyId)) {
      filtered.add(_selectedCompanyId!);
    }
    _selectedAllowedCompanyIds = filtered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    // Update session context
    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        // No session -> show local cache if available
        _companies = [];
        _selectedCompanyId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      // 1) Load companies from backend (network-first)
      final userRes = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      List<int> companyIds = [];
      int? currentCompanyId;
      if (userRes is List && userRes.isNotEmpty) {
        final row = userRes.first as Map<String, dynamic>;
        if (row['company_ids'] is List) {
          final raw = row['company_ids'] as List;
          companyIds = raw.whereType<int>().toList();
        }
        if (row['company_id'] is List && (row['company_id'] as List).isNotEmpty) {
          currentCompanyId = (row['company_id'] as List).first as int?;
        }
      }

      if (companyIds.isEmpty) {
        _companies = [];
        _selectedCompanyId = currentCompanyId;
        // Clear local cache because server says none
        _loading = false;
        notifyListeners();
        return;
      }

      final companiesRes = await OdooSessionManager.safeCallKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', companyIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      final serverCompanies = (companiesRes is List)
          ? companiesRes.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      if (serverCompanies.isNotEmpty) {
        _companies = serverCompanies;
        // Save to local DB on success
      } else {
        // If server returned empty (unexpected), fallback to local cache
        _companies = [];
      }

      // Restore selection from SharedPreferences and ensure invariants
      final prefs = await SharedPreferences.getInstance();
      final restoredId = prefs.getInt('selected_company_id');
      final pendingId = prefs.getInt('pending_company_id');
      final restoredAllowed =
          prefs
              .getStringList('selected_allowed_company_ids')
              ?.map((e) => int.tryParse(e) ?? -1)
              .where((e) => e > 0)
              .toList() ??
          [];

      // Selected company precedence: pending -> restored -> server current -> first
      int? desiredId =
          pendingId ?? restoredId ?? currentCompanyId ?? (companyIds.isNotEmpty ? companyIds.first : null);
      _selectedCompanyId = desiredId;

      // Allowed companies: restored subset or all
      List<int> defaultAllowed = companyIds;
      final restoredValid = restoredAllowed.where((id) => companyIds.contains(id)).toList();
      _selectedAllowedCompanyIds = restoredValid.isNotEmpty ? restoredValid : defaultAllowed;
      if (_selectedCompanyId != null && !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, _selectedCompanyId!];
      }

      // Enforce invariants: ensure we always have a valid selected company.
      if (_selectedCompanyId == null || !companyIds.contains(_selectedCompanyId)) {
        if (companyIds.isNotEmpty) {
          _selectedCompanyId = companyIds.first;
        }
      }

      // Ensure allowed list includes the active company and persist immediately
      if (_selectedCompanyId != null && !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, _selectedCompanyId!];
      }

      // Persist selection and allowed ids for stability across app launches
      final prefs2 = await SharedPreferences.getInstance();
      if (_selectedCompanyId != null) {
        await prefs2.setInt('selected_company_id', _selectedCompanyId!);
      }
      await prefs2.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      // Update session company context immediately (best-effort)
      if (_selectedCompanyId != null) {
        await OdooSessionManager.updateCompanySelection(
          companyId: _selectedCompanyId!,
          allowedCompanyIds: _selectedAllowedCompanyIds,
        );
      }

      // Try to apply pending switch online (best effort)
      if (pendingId != null && companyIds.contains(pendingId)) {
        try {
          await _applyCompanyOnServer(session.userId!, pendingId);
          await OdooSessionManager.refreshSession();
          await OdooSessionManager.restoreSession(companyId: pendingId);
          await prefs.remove('pending_company_id');
        } catch (_) {}
      } else if (desiredId != null && currentCompanyId != desiredId && companyIds.contains(desiredId)) {
        try {
          await _applyCompanyOnServer(session.userId!, desiredId);
          await OdooSessionManager.refreshSession();
          await OdooSessionManager.restoreSession(companyId: desiredId);
        } catch (_) {}
      }
    } catch (e) {
      // Network/API failed -> fallback to local DB
      try {
        if (_companies.isEmpty) {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh only the companies list from the server/cache without altering
  /// current selection or allowed companies. Use after switching company to
  /// avoid race conditions that reset selection.
  Future<void> refreshCompaniesList() async {
    _loading = true;
    notifyListeners();

    try {
      // Try server first
      final list = await OdooSessionManager.getAllowedCompaniesList();
      if (list.isNotEmpty) {
        _companies = list;

      } else {
        // Fallback to local cache

      }
    } catch (_) {
      // Fallback to local cache on any error
      try {
      } catch (_) {}
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> switchCompany(int companyId) async {
    log("switching company");
    if (_selectedCompanyId == companyId) return true;
    bool appliedImmediately = false;
    try {
      _switching = true;
      _error = null;
      notifyListeners();
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        // Persist as pending and as selected for local context injection
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('selected_company_id', companyId);
        await prefs.setInt('pending_company_id', companyId);
        _selectedCompanyId = companyId;
        // Ensure active company is part of allowed selection
        if (!_selectedAllowedCompanyIds.contains(companyId)) {
          _selectedAllowedCompanyIds = [
            ..._selectedAllowedCompanyIds,
            companyId,
          ];
          await prefs.setStringList(
            'selected_allowed_company_ids',
            _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
          );
        }
        notifyListeners();
        return false;
      }

      try {
        await _applyCompanyOnServer(session.userId!, companyId);
        // After server write, refresh and restore the session to bind company context
        await OdooSessionManager.refreshSession();
        await OdooSessionManager.restoreSession(companyId: companyId);
        appliedImmediately = true;
        // Clear any previous pending
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_company_id');
      } catch (_) {
        // Queue as pending if failed (likely offline)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pending_company_id', companyId);
        appliedImmediately = false;
        // Update local session selection for offline context injection
        // Ensure active company is part of allowed selection
        List<int> allowed = _selectedAllowedCompanyIds;
        if (!allowed.contains(companyId)) {
          allowed = [...allowed, companyId];
        }
        await OdooSessionManager.updateCompanySelection(
          companyId: companyId,
          allowedCompanyIds: allowed,
        );
      }

      // Persist selection for context injection regardless of server status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_company_id', companyId);
      // Ensure active company is included in allowed selection
      if (!_selectedAllowedCompanyIds.contains(companyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
      }
      await prefs.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      // Update local selection and notify
      _selectedCompanyId = companyId;
      notifyListeners();

      // Refresh companies list without touching current selection
      await refreshCompaniesList();
      return appliedImmediately;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  Future<void> _applyCompanyOnServer(int userId, int companyId) async {
    await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {'company_id': companyId},
      ],
      'kwargs': {},
    });
  }

  /// Toggle a company in the allowed companies list
  /// The active company cannot be removed from allowed companies
  Future<void> toggleAllowedCompany(int companyId) async {
    if (_selectedAllowedCompanyIds.contains(companyId)) {
      // Cannot remove active company from allowed companies
      if (companyId == _selectedCompanyId) {
        return;
      }
      _selectedAllowedCompanyIds = _selectedAllowedCompanyIds
          .where((id) => id != companyId)
          .toList();
    } else {
      _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );
    // Update session context
    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
    notifyListeners();
  }

  /// Select all available companies as allowed companies
  Future<void> selectAllCompanies() async {
    final allIds = _companies.map((c) => c['id'] as int).toList();
    await setAllowedCompanies(allIds);
  }

  /// Deselect all companies except the active company
  Future<void> deselectAllCompanies() async {
    if (_selectedCompanyId != null) {
      await setAllowedCompanies([_selectedCompanyId!]);
    }
  }

  /// Check if a company is in the allowed companies list
  bool isCompanyAllowed(int companyId) {
    return _selectedAllowedCompanyIds.contains(companyId);
  }
}

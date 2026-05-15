import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/odoo_session_manager.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  String? _error;
  bool _hasInternet = true;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;


  String getGreeting() {
    final currentTime = DateTime.now();
    final hour = currentTime.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  static const String _cacheKeyUser = 'user_profile';
  static const String _cacheKeyUserWriteDate = 'user_profile_write_date';
  static const String _cacheKeyPendingUserUpdates =
      'user_profile_pending_users';
  static const String _cacheKeyPendingPartnerUpdates =
      'user_profile_pending_partner';

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  Uint8List? get userAvatar => _userAvatar;
  String? get error => _error;
  bool get hasInternet => _hasInternet;
  List<Map<String, dynamic>> get countries => _countries;
  List<Map<String, dynamic>> get states => _states;
  bool get isLoadingCountries => _isLoadingCountries;
  bool get isLoadingStates => _isLoadingStates;

  void setUserData(Map<String, dynamic> data) {
    _userData = data;
    notifyListeners();
  }

  String normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    return (s.toLowerCase() == 'false' || s.isEmpty) ? '' : s;
  }

  // Pending offline updates (merged per model)
  Map<String, dynamic> _pendingUserUpdates = {};
  Map<String, dynamic> _pendingPartnerUpdates = {};

  // Normalize partner update keys to match server schema
  // e.g., map legacy/mobile_phone to standard 'mobile'
  Map<String, dynamic> _normalizePartnerUpdates(Map<String, dynamic> updates) {
    final out = <String, dynamic>{};
    updates.forEach((key, value) {
      String k = key;
      if (k == 'mobile_phone') k = 'mobile';
      out[k] = value;
    });
    return out;
  }


  String? _partnerMobileFieldNameCache;
  Future<String?> _getPartnerMobileFieldName() async {
    if (_partnerMobileFieldNameCache != null)
      return _partnerMobileFieldNameCache;
    try {
      // Prefer custom 'mobile_phone' if present
      final hasMobilePhone = await OdooSessionManager.callKwWithCompany({
        'model': 'ir.model.fields',
        'method': 'search_count',
        'args': [
          [
            ['model', '=', 'res.partner'],
            ['name', '=', 'mobile_phone'],
          ],
        ],
        'kwargs': {},
      });
      final hasMp = (hasMobilePhone is int)
          ? hasMobilePhone > 0
          : (hasMobilePhone as num) > 0;
      if (hasMp) {
        _partnerMobileFieldNameCache = 'mobile_phone';
        return _partnerMobileFieldNameCache;
      }

      // Odoo Studio commonly uses x_studio_mobile_phone
      // Odoo Studio commonly uses x_studio_mobile_phone
      final hasStudioMobilePhone = await OdooSessionManager.callKwWithCompany({
        'model': 'ir.model.fields',
        'method': 'search_count',
        'args': [
          [
            ['model', '=', 'res.partner'],
            ['name', '=', 'x_studio_mobile_phone'],
          ],
        ],
        'kwargs': {},
      });
      final hasXs = (hasStudioMobilePhone is int)
          ? hasStudioMobilePhone > 0
          : (hasStudioMobilePhone as num) > 0;
      if (hasXs) {
        _partnerMobileFieldNameCache = 'x_studio_mobile_phone';
        return _partnerMobileFieldNameCache;
      }

      // Otherwise check standard 'mobile'
      // Otherwise check standard 'mobile'
      final hasMobile = await OdooSessionManager.callKwWithCompany({
        'model': 'ir.model.fields',
        'method': 'search_count',
        'args': [
          [
            ['model', '=', 'res.partner'],
            ['name', '=', 'mobile'],
          ],
        ],
        'kwargs': {},
      });
      final hasM = (hasMobile is int) ? hasMobile > 0 : (hasMobile as num) > 0;
      _partnerMobileFieldNameCache = hasM ? 'mobile' : null;
      return _partnerMobileFieldNameCache;
    } catch (_) {
      // On failure, don't assume a field; we'll fallback to using phone for UI
      _partnerMobileFieldNameCache = null;
      return _partnerMobileFieldNameCache;
    }
  }

  Future<Map<String, dynamic>> _preparePartnerUpdatesForServer(
    Map<String, dynamic> normalized,
  ) async {
    // Map our internal 'mobile' to whichever field server supports
    if (!normalized.containsKey('mobile')) return normalized;
    final fieldName = await _getPartnerMobileFieldName();
    if (fieldName == null) {
      // Server doesn't support a distinct mobile field; do NOT overwrite phone.
      // Drop 'mobile' from the payload to avoid merging numbers.
      final copy = Map<String, dynamic>.from(normalized);
      copy.remove('mobile');
      return copy;
    }
    if (fieldName == 'mobile') return normalized;
    final copy = Map<String, dynamic>.from(normalized);
    final value = copy.remove('mobile');
    copy[fieldName] = value;
    return copy;
  }

  /// Update multiple contact fields at once (on res.partner)
  Future<void> updatePartnerFields(Map<String, dynamic> updates) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      // Ensure keys are normalized before any processing
      final normalized = _normalizePartnerUpdates(updates);

      // Offline-first: if no internet, queue changes and apply locally
      if (!_hasInternet) {
        _mergeInto(_pendingPartnerUpdates, normalized);
        await _savePendingUpdates();
        await _applyLocalUserUpdates(normalized);
        return;
      }

      final toSend = await _preparePartnerUpdatesForServer(normalized);
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          toSend,
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      // Queue on error and update local cache for smooth UX
      final normalized = _normalizePartnerUpdates(updates);
      _mergeInto(_pendingPartnerUpdates, normalized);
      await _savePendingUpdates();
      await _applyLocalUserUpdates(normalized);
      debugPrint('[ProfileProvider] Offline queue (partner) due to: $e');
    }
  }

  Future<void> initialize() async {
    _startConnectivityListener();
    await loadCachedUser();
    await _loadPendingUpdates();
    await fetchUserProfile();
    await loadCountries();
  }

  void _startConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasNet = await _checkInternet();
      _hasInternet = hasNet;
      notifyListeners();
      if (hasNet) {
        await _processPendingUpdates();
      }
    });

    // Initial check
    _checkInternet().then((hasNet) {
      _hasInternet = hasNet;
      notifyListeners();
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyUser);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        _userData = data;
        final img = data['image_1920'];
        if (img != null && img is String && img.isNotEmpty && img != 'false') {
          try {
          } catch (_) {}
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ProfileProvider] Error loading cached user: $e');
    }
  }

  Future<void> fetchUserProfile({bool forceRefresh = false}) async {
    // Only show loading state if we have no cached data
    // This allows silent background refresh when data exists
    if (_userData == null) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }


      // Read basic user fields from res.users (exclude unsupported fields like 'mobile')
      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          [
            'name',
            'login',
            'email',
            // phone/mobile live on res.partner; we will fetch them from partner below
            'website',
            'function',
            'image_1920',
            'company_id',
            'partner_id',
          ],
        ],
        'kwargs': {},
      });

      if (res is List && res.isNotEmpty) {
        final data = res.first as Map<String, dynamic>;

        // If partner is linked, fetch phone/mobile from res.partner and merge for UI compatibility
        final partner = data['partner_id'];
        if (partner != null && partner is List && partner.isNotEmpty) {
          try {
            // Determine which mobile field exists to avoid invalid field errors
            final mobileFieldName = await _getPartnerMobileFieldName();
            final fields = <String>[
              'phone',
              'street',
              'city',
              'zip',
              'state_id',
              'country_id',
            ];
            if (mobileFieldName != null) fields.add(mobileFieldName);

            final partnerRes = await OdooSessionManager.callKwWithCompany({
              'model': 'res.partner',
              'method': 'read',
              'args': [
                [partner[0]],
                fields,
              ],
              'kwargs': {},
            });

            if (partnerRes is List && partnerRes.isNotEmpty) {
              final partnerData = partnerRes.first as Map<String, dynamic>;
              // Merge phone/mobile (and a few address fields if needed by UI)
              data['phone'] = partnerData['phone'];
              // Derive unified 'mobile' for UI using whichever field exists
              String? mobileValue;
              if (mobileFieldName != null) {
                final mv = partnerData[mobileFieldName];
                if (mv != null && mv.toString().isNotEmpty && mv != 'false') {
                  mobileValue = mv.toString();
                }
              }
              // If server has no mobile field, keep empty so UI treats it as separate and editable
              data['mobile'] = mobileValue ?? '';
              data['street'] = partnerData['street'];
              data['city'] = partnerData['city'];
              data['zip'] = partnerData['zip'];
              data['state_id'] = partnerData['state_id'];
              data['country_id'] = partnerData['country_id'];
            }
          } catch (e) {
            debugPrint(
              '[ProfileProvider] Failed to read partner for phone/mobile: $e',
            );
          }
        }

        _userData = data;
        final img = data['image_1920'];
        if (img != null && img is String && img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = base64Decode(img);
          } catch (_) {}
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKeyUser, jsonEncode(data));
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
      debugPrint('[ProfileProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCountries() async {
    _isLoadingCountries = true;
    notifyListeners();

    try {
      _countries = await fetchCountries();
    } catch (e) {
      debugPrint('[ProfileProvider] Error loading countries: $e');
    } finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchCountries() async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (e) {
      debugPrint('[ProfileProvider] Error fetching countries: $e');
      rethrow;
    }
  }

  Future<void> loadStates(int countryId) async {
    _isLoadingStates = true;
    notifyListeners();

    try {
      _states = await fetchStates(countryId);
    } catch (e) {
      debugPrint('[ProfileProvider] Error loading states: $e');
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchStates(int countryId) async {
    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'res.country.state',
        'method': 'search_read',
        'args': [
          [
            ['country_id', '=', countryId],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'code'],
          'order': 'name ASC',
        },
      });
      return result is List ? result.cast<Map<String, dynamic>>() : [];
    } catch (e) {
      debugPrint('[ProfileProvider] Error fetching states: $e');
      rethrow;
    }
  }

  Future<void> updateProfileImage(String base64Image) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) return;

      // Offline-first: queue and apply locally
      if (!_hasInternet) {
        _pendingUserUpdates['image_1920'] = base64Image;
        await _savePendingUpdates();
        // Apply locally for instant UI
        try {
          _userAvatar = base64Decode(base64Image);
        } catch (_) {}
        _userData ??= {};
        _userData!['image_1920'] = base64Image;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
        notifyListeners();
        return;
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [session.userId],
          {'image_1920': base64Image},
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      // Queue on failure too
      _pendingUserUpdates['image_1920'] = base64Image;
      await _savePendingUpdates();
      try {
        _userAvatar = base64Decode(base64Image);
      } catch (_) {}
      _userData ??= {};
      _userData!['image_1920'] = base64Image;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
      notifyListeners();
      debugPrint('[ProfileProvider] Offline queue (image) due to: $e');
    }
  }

  Future<void> updateProfileField(String field, dynamic value) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {field: value},
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      _error = 'Failed to update $field: $e';
      debugPrint('[ProfileProvider] $_error');
      rethrow;
    }
  }

  Future<void> updateAddressFields(Map<String, dynamic> addressData) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      // Offline-first: queue and apply locally if no internet
      if (!_hasInternet) {
        _mergeInto(_pendingPartnerUpdates, addressData);
        await _savePendingUpdates();
        await _applyLocalUserUpdates(addressData);
        return;
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          addressData,
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      // Queue on failure and update local cache
      _mergeInto(_pendingPartnerUpdates, addressData);
      await _savePendingUpdates();
      await _applyLocalUserUpdates(addressData);
      debugPrint('[ProfileProvider] Offline queue (address) due to: $e');
    }
  }

  /// Update multiple profile fields at once (on res.users)
  Future<void> updateProfileFields(Map<String, dynamic> updates) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        throw Exception('No active session');
      }

      if (!_hasInternet) {
        _mergeInto(_pendingUserUpdates, updates);
        await _savePendingUpdates();
        await _applyLocalUserUpdates(updates);
        return;
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [session.userId],
          updates,
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      // Queue on error and update local cache for smooth UX
      _mergeInto(_pendingUserUpdates, updates);
      await _savePendingUpdates();
      await _applyLocalUserUpdates(updates);
      debugPrint('[ProfileProvider] Offline queue (users) due to: $e');
    }
  }

  /// Load the related company (parent_id) for the user's partner
  Future<Map<String, dynamic>?> loadRelatedCompany() async {
    try {
      if (_userData == null) return null;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        return null;
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'read',
        'args': [
          [partnerId[0]],
        ],
        'kwargs': {
          'fields': ['parent_id'],
        },
      });

      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        if (row['parent_id'] is List &&
            (row['parent_id'] as List).length >= 2 &&
            row['parent_id'][0] != null) {
          return {
            'id': row['parent_id'][0],
            'name': row['parent_id'][1]?.toString(),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ProfileProvider] Failed to load related company: $e');
      return null;
    }
  }

  /// Update the related company (parent_id) for the user's partner
  Future<void> updateRelatedCompany(int? companyId) async {
    try {
      if (_userData == null) return;

      final partnerId = _userData!['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        throw Exception('Partner ID not found');
      }

      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {'parent_id': companyId ?? false},
        ],
        'kwargs': {},
      });

      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      _error = 'Failed to update related company: $e';
      debugPrint('[ProfileProvider] $_error');
      rethrow;
    }
  }

  /// Format address fields into a single display string
  String formatAddress(Map<String, dynamic> data) {
    final parts = [
      if (data['street'] != null &&
          data['street'].toString().isNotEmpty &&
          data['street'].toString().toLowerCase() != 'false')
        data['street'],
      if (data['street2'] != null &&
          data['street2'].toString().isNotEmpty &&
          data['street2'].toString().toLowerCase() != 'false')
        data['street2'],
      if (data['city'] != null &&
          data['city'].toString().isNotEmpty &&
          data['city'].toString().toLowerCase() != 'false')
        data['city'],
      if (data['state_id'] is List &&
          data['state_id'].length > 1 &&
          data['state_id'][1] != null &&
          data['state_id'][1].toString().isNotEmpty &&
          data['state_id'][1].toString().toLowerCase() != 'false')
        data['state_id'][1],
      if (data['zip'] != null &&
          data['zip'].toString().isNotEmpty &&
          data['zip'].toString().toLowerCase() != 'false')
        data['zip'],
      if (data['country_id'] is List &&
          data['country_id'].length > 1 &&
          data['country_id'][1] != null &&
          data['country_id'][1].toString().isNotEmpty &&
          data['country_id'][1].toString().toLowerCase() != 'false')
        data['country_id'][1],
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address set';
  }

  void clearStates() {
    _states = [];
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _error = 'Logout failed: $e';
      debugPrint('[ProfileProvider] $_error');
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  /// Reset provider state to initial values (called when cache is cleared)
  void resetState() {
    _isLoading = true;
    _userData = null;
    _userAvatar = null;
    _error = null;
    _hasInternet = true;
    _countries = [];
    _states = [];
    _isLoadingCountries = false;
    _isLoadingStates = false;
    notifyListeners();
    debugPrint('ProfileProvider: State reset');
  }

  // Expose sync status and manual trigger for UI
  bool get hasPendingUpdates =>
      _pendingUserUpdates.isNotEmpty || _pendingPartnerUpdates.isNotEmpty;

  Future<void> processPendingUpdates() => _processPendingUpdates();

  // ---------- Offline helpers ----------
  void _mergeInto(Map<String, dynamic> target, Map<String, dynamic> src) {
    for (final e in src.entries) {
      target[e.key] = e.value;
    }
  }

  Future<void> _loadPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString(_cacheKeyPendingUserUpdates);
      final p = prefs.getString(_cacheKeyPendingPartnerUpdates);
      if (u != null && u.isNotEmpty) {
        _pendingUserUpdates = Map<String, dynamic>.from(jsonDecode(u));
      }
      if (p != null && p.isNotEmpty) {
        _pendingPartnerUpdates = Map<String, dynamic>.from(jsonDecode(p));
      }
    } catch (e) {
      debugPrint('[ProfileProvider] Failed to load pending updates: $e');
    }
  }

  Future<void> _savePendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKeyPendingUserUpdates,
        jsonEncode(_pendingUserUpdates),
      );
      await prefs.setString(
        _cacheKeyPendingPartnerUpdates,
        jsonEncode(_pendingPartnerUpdates),
      );
    } catch (e) {
      debugPrint('[ProfileProvider] Failed to save pending updates: $e');
    }
  }

  Future<void> _processPendingUpdates() async {
    if (_pendingUserUpdates.isEmpty && _pendingPartnerUpdates.isEmpty) return;
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) return;

      if (_pendingUserUpdates.isNotEmpty) {
        await OdooSessionManager.callKwWithCompany({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [session.userId],
            _pendingUserUpdates,
          ],
          'kwargs': {},
        });
        _pendingUserUpdates.clear();
      }

      // Apply partner pending
      if (_userData != null && _pendingPartnerUpdates.isNotEmpty) {
        final partnerId = _userData!['partner_id'];
        if (partnerId is List && partnerId.isNotEmpty) {
          // Normalize any legacy keys before sending
          final normalized = _normalizePartnerUpdates(_pendingPartnerUpdates);
          final toSend = await _preparePartnerUpdatesForServer(normalized);
          await OdooSessionManager.callKwWithCompany({
            'model': 'res.partner',
            'method': 'write',
            'args': [
              [partnerId[0]],
              toSend,
            ],
            'kwargs': {},
          });
          _pendingPartnerUpdates.clear();
        }
      }

      await _savePendingUpdates();
      await fetchUserProfile(forceRefresh: true);
    } catch (e) {
      debugPrint('[ProfileProvider] Failed processing pending updates: $e');
    }
  }

  Future<void> _applyLocalUserUpdates(Map<String, dynamic> updates) async {
    try {
      if (_userData == null) return;
      updates.forEach((key, value) {
        _userData![key] = value;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUser, jsonEncode(_userData));
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileProvider] Failed to apply local user updates: $e');
    }
  }
}

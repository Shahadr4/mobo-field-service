import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/odoo_session_manager.dart';
import '../model/dashboard_task_model.dart';

class DashboardTaskService {
  static const double _nearbyRadiusKm = 10.0;

  Future<List<DashboardTask>> fetchByTab(String tab) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];

    final userId = session.userId;

    final base = <dynamic>[
      ['is_fsm', '=', true],
      ['project_id', '!=', false],
      if (session.version?.contains('19') == true)
        ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true],
    ];

    List<dynamic> domain;
    if (tab == 'New') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
        ['stage_id.name', 'in', ['New', 'new']],
      ];
    } else if (tab == 'In Progress') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
        ['stage_id.name', 'in', ['In Progress', 'In progress', 'in progress', 'Ongoing', 'ongoing']],
      ];
    } else if (tab == 'Planned') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
        ['stage_id.name', 'in', ['Planned', 'planned', 'Plan', 'plan', 'Scheduled', 'scheduled']],
      ];
    } else if (tab == 'Done') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
        ['stage_id.name', 'in', ['Done', 'done', 'Completed', 'completed', 'Complete', 'complete']],
      ];
    } else if (tab == 'Nearby') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
        ['partner_id', '!=', false],
      ];
    } else if (tab == 'Assigned') {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
      ];
    } else {
      domain = [
        ...base,
        ['user_ids', 'in', [userId]],
      ];
    }

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [domain],
        'kwargs': {
          'fields': [

          ],
          'order': 'name asc',
        },
      });

      if (result is! List) return [];

      final tasks = result.whereType<Map<String, dynamic>>().toList();

      /// Collect unique partner IDs
      final partnerIds = tasks
          .map((t) => t['partner_id'])
          .where((v) => v is List && v.isNotEmpty)
          .map((v) => (v as List)[0] as int)
          .toSet()
          .toList();

      /// Fetch partner address + lat/lon fields
      final Map<int, Map<String, dynamic>> partnerMap = {};
      if (partnerIds.isNotEmpty) {
        final partners = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', 'in', partnerIds]]
          ],
          'kwargs': {
            'fields': ['id', 'street', 'city', 'country_id', 'partner_latitude', 'partner_longitude'],
          },
        });

        if (partners is List) {
          for (final p in partners.whereType<Map<String, dynamic>>()) {
            final id = (p['id'] as num).toInt();
            final countryRaw = p['country_id'];
            partnerMap[id] = {
              'street': p['street'] is String ? p['street'] : '',
              'city': p['city'] is String ? p['city'] : '',
              'country': countryRaw is List && countryRaw.length >= 2
                  ? countryRaw[1].toString()
                  : '',
              'lat': (p['partner_latitude'] as num?)?.toDouble() ?? 0.0,
              'lng': (p['partner_longitude'] as num?)?.toDouble() ?? 0.0,
            };
          }
        }
      }

      /// Inject address fields
      var parsed = tasks.map((t) {
        final partnerRaw = t['partner_id'];
        if (partnerRaw is List && partnerRaw.isNotEmpty) {
          final pid = (partnerRaw[0] as num).toInt();
          final addr = partnerMap[pid];
          if (addr != null) {
            t['partner_street']  = addr['street'];
            t['partner_city']    = addr['city'];
            t['partner_country'] = addr['country'];
            t['partner_lat']     = addr['lat'];
            t['partner_lng']     = addr['lng'];
          }
        }
        return DashboardTask.fromMap(t);
      }).toList();

      /// For Nearby tab: get device location and filter within radius
      if (tab == 'Nearby') {
        parsed = await _filterNearby(parsed);
      }

      return parsed;
    } catch (e) {
      return [];
    }
  }

  /// Same as fetchByTab('Nearby') but accepts an already-fetched [pos]
  /// so GPS is not requested a second time.
  Future<List<DashboardTask>> fetchNearbyWithPosition(Position pos) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];

    final base = <dynamic>[
      ['is_fsm', '=', true],
      ['project_id', '!=', false],
      if (session.version?.contains('19') == true)
        ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true],
      ['partner_id', '!=', false],
    ];

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [base],
        'kwargs': {
          'fields': [
            'id', 'name', 'project_id', 'stage_id', 'user_ids',
            'partner_id', 'date_deadline', 'planned_date_begin', 'priority',
          ],
          'order': 'name asc',
        },
      });

      if (result is! List) return [];
      final tasks = result.whereType<Map<String, dynamic>>().toList();

      final partnerIds = tasks
          .map((t) => t['partner_id'])
          .where((v) => v is List && v.isNotEmpty)
          .map((v) => (v as List)[0] as int)
          .toSet()
          .toList();

      final Map<int, Map<String, dynamic>> partnerMap = {};
      if (partnerIds.isNotEmpty) {
        final partners = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', 'in', partnerIds]]
          ],
          'kwargs': {
            'fields': ['id', 'street', 'city', 'country_id', 'partner_latitude', 'partner_longitude'],
          },
        });
        if (partners is List) {
          for (final p in partners.whereType<Map<String, dynamic>>()) {
            final id = (p['id'] as num).toInt();
            final countryRaw = p['country_id'];
            partnerMap[id] = {
              'street': p['street'] is String ? p['street'] : '',
              'city': p['city'] is String ? p['city'] : '',
              'country': countryRaw is List && countryRaw.length >= 2
                  ? countryRaw[1].toString()
                  : '',
              'lat': (p['partner_latitude'] as num?)?.toDouble() ?? 0.0,
              'lng': (p['partner_longitude'] as num?)?.toDouble() ?? 0.0,
            };
          }
        }
      }

      var parsed = tasks.map((t) {
        final partnerRaw = t['partner_id'];
        if (partnerRaw is List && partnerRaw.isNotEmpty) {
          final pid = (partnerRaw[0] as num).toInt();
          final addr = partnerMap[pid];
          if (addr != null) {
            t['partner_street']  = addr['street'];
            t['partner_city']    = addr['city'];
            t['partner_country'] = addr['country'];
            t['partner_lat']     = addr['lat'];
            t['partner_lng']     = addr['lng'];
          }
        }
        return DashboardTask.fromMap(t);
      }).toList();

      /// Filter using the provided position — no extra GPS call
      parsed = await _filterNearbyWithPos(parsed, pos);
      return parsed;
    } catch (e) {
      return [];
    }
  }


  /// Same as fetchByTab('Assigned') but accepts an already-fetched [pos]
  Future<List<DashboardTask>> fetchMyTasksWithPosition(Position pos) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return [];
    final userId = session.userId;

    final base = <dynamic>[
      ['is_fsm', '=', true],
      ['project_id', '!=', false],
      if (session.version?.contains('19') == true)
        ['has_template_ancestor', '=', false],
      ['display_in_project', '=', true],
      ['partner_id', '!=', false],
      ['user_ids', 'in', [userId]],
    ];

    try {
      final result = await OdooSessionManager.callKwWithCompany({
        'model': 'project.task',
        'method': 'search_read',
        'args': [base],
        'kwargs': {
          'fields': [
            'id', 'name', 'project_id', 'stage_id', 'user_ids',
            'partner_id', 'date_deadline', 'planned_date_begin', 'priority',
          ],
          'order': 'name asc',
        },
      });

      if (result is! List) return [];
      final tasks = result.whereType<Map<String, dynamic>>().toList();

      final partnerIds = tasks
          .map((t) => t['partner_id'])
          .where((v) => v is List && v.isNotEmpty)
          .map((v) => (v as List)[0] as int)
          .toSet()
          .toList();

      final Map<int, Map<String, dynamic>> partnerMap = {};
      if (partnerIds.isNotEmpty) {
        final partners = await OdooSessionManager.callKwWithCompany({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', 'in', partnerIds]]
          ],
          'kwargs': {
            'fields': ['id', 'street', 'city', 'country_id', 'partner_latitude', 'partner_longitude'],
          },
        });
        if (partners is List) {
          for (final p in partners.whereType<Map<String, dynamic>>()) {
            final id = (p['id'] as num).toInt();
            final countryRaw = p['country_id'];
            partnerMap[id] = {
              'street': p['street'] is String ? p['street'] : '',
              'city': p['city'] is String ? p['city'] : '',
              'country': countryRaw is List && countryRaw.length >= 2
                  ? countryRaw[1].toString()
                  : '',
              'lat': (p['partner_latitude'] as num?)?.toDouble() ?? 0.0,
              'lng': (p['partner_longitude'] as num?)?.toDouble() ?? 0.0,
            };
          }
        }
      }

      var parsed = tasks.map((t) {
        final partnerRaw = t['partner_id'];
        if (partnerRaw is List && partnerRaw.isNotEmpty) {
          final pid = (partnerRaw[0] as num).toInt();
          final addr = partnerMap[pid];
          if (addr != null) {
            t['partner_street']  = addr['street'];
            t['partner_city']    = addr['city'];
            t['partner_country'] = addr['country'];
            t['partner_lat']     = addr['lat'];
            t['partner_lng']     = addr['lng'];
          }
        }
        return DashboardTask.fromMap(t);
      }).toList();

      final resolvedTasks = <DashboardTask>[];
      for (final task in parsed) {
        double lat = task.partnerLat;
        double lng = task.partnerLng;

        if (lat == 0.0 && lng == 0.0) {
          if (task.partnerAddress.trim().isEmpty) {
            continue;
          }
          final geo = await _geocodeAddress(task.partnerAddress);
          if (geo == null) {
            continue;
          }
          lat = geo.$1;
          lng = geo.$2;
        }
        resolvedTasks.add(task.withCoords(lat, lng));
      }

      return resolvedTasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<DashboardTask>> _filterNearbyWithPos(
      List<DashboardTask> tasks, Position pos) async {

    final nearby = <DashboardTask>[];

    for (final task in tasks) {
      double lat = task.partnerLat;
      double lng = task.partnerLng;

      if (lat == 0.0 && lng == 0.0) {
        if (task.partnerAddress.trim().isEmpty) {
          continue;
        }
        final geo = await _geocodeAddress(task.partnerAddress);
        if (geo == null) {
          continue;
        }
        lat = geo.$1;
        lng = geo.$2;
      }

      final distKm = _haversineKm(pos.latitude, pos.longitude, lat, lng);
      final within = distKm <= _nearbyRadiusKm;
      /// Always store resolved coords so the map can pin the task
      if (within) nearby.add(task.withCoords(lat, lng));
    }

    return nearby;
  }


  Future<List<DashboardTask>> _filterNearby(List<DashboardTask> tasks) async {
    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return [];

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return [];
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      /// Reverse geocode to get human-readable location name
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json',
        );
        final resp = await http.get(uri, headers: {'User-Agent': 'MoboFieldService/1.0'})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final address = data['address'] as Map<String, dynamic>?;
          final name = [
            address?['road'],
            address?['suburb'] ?? address?['neighbourhood'],
            address?['city'] ?? address?['town'] ?? address?['village'],
            address?['state'],
            address?['country'],
          ].whereType<String>().join(', ');
        }
      } catch (_) {}

      final nearby = <DashboardTask>[];

      for (final task in tasks) {
        double lat = task.partnerLat;
        double lng = task.partnerLng;

        /// No stored coords — geocode the address string
        if (lat == 0.0 && lng == 0.0) {
          if (task.partnerAddress.trim().isEmpty) {
            continue;
          }
          final geo = await _geocodeAddress(task.partnerAddress);
          if (geo == null) {
            continue;
          }
          lat = geo.$1;
          lng = geo.$2;
        }

        final distKm = _haversineKm(pos.latitude, pos.longitude, lat, lng);
        final within = distKm <= _nearbyRadiusKm;
        if (within) nearby.add(task);
      }

      return nearby;
    } catch (e) {
      return [];
    }
  }

  /// Geocode an address via Nominatim with progressive fallback.
  Future<(double, double)?> _geocodeAddress(String address) async {
    /// Build fallback attempts: full → city+country → country only
    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final attempts = <String>{};
    attempts.add(address.trim());
    if (parts.length >= 2) attempts.add(parts.skip(parts.length - 2).join(', '));
    if (parts.isNotEmpty) attempts.add(parts.last);

    for (final query in attempts) {
      final result = await _nominatimSearch(query);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  Future<(double, double)?> _nominatimSearch(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': 'MoboFieldService/1.0'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      if (data is! List || data.isEmpty) return null;
      final lat = double.tryParse(data[0]['lat']?.toString() ?? '');
      final lon = double.tryParse(data[0]['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (e) {
      return null;
    }
  }

  /// Haversine formula — returns distance in kilometres.
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;
}

import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class LocationMapService {
  static final Map<String, _GeoResult?> _geocodeCache = {};

  static Future<_GeoResult?> _geocode(String address) async {
    if (address.trim().isEmpty) return null;
    if (_geocodeCache.containsKey(address)) return _geocodeCache[address];

    // Progressive fallback: full → last 2 parts → last part
    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final attempts = <String>[
      address.trim(),
      if (parts.length >= 2) parts.skip(parts.length - 2).join(', '),
      if (parts.isNotEmpty) parts.last,
    ];

    for (final query in attempts) {
      final r = await _nominatimSearch(query);
      if (r != null) {
        _geocodeCache[address] = r;
        log('[LocationMapService] geocoded "$query" → ${r.lat},${r.lon}');
        return r;
      }
    }
    _geocodeCache[address] = null;
    return null;
  }

  static Future<_GeoResult?> _nominatimSearch(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=1',
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
      return _GeoResult(lat, lon);
    } catch (_) {
      return null;
    }
  }

  /// Returns map tile info for rendering, or null if geocoding fails.
  static Future<MapTileInfo?> getTileInfo(String address) async {
    final geo = await _geocode(address);
    if (geo == null) return null;
    return MapTileInfo.fromLatLon(geo.lat, geo.lon, zoom: 15);
  }
}

class MapTileInfo {
  final int zoom;
  final int centerX;
  final int centerY;
  final double pixelOffsetX; // pixel offset of pin within center tile
  final double pixelOffsetY;

  const MapTileInfo({
    required this.zoom,
    required this.centerX,
    required this.centerY,
    required this.pixelOffsetX,
    required this.pixelOffsetY,
  });

  factory MapTileInfo.fromLatLon(double lat, double lon, {int zoom = 15}) {
    final n = math.pow(2, zoom).toDouble();
    final xExact = (lon + 180) / 360 * n;
    final latRad = lat * math.pi / 180;
    final yExact = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;

    final tileX = xExact.floor();
    final tileY = yExact.floor();
    final offX = (xExact - tileX) * 256;
    final offY = (yExact - tileY) * 256;

    return MapTileInfo(
      zoom: zoom,
      centerX: tileX,
      centerY: tileY,
      pixelOffsetX: offX,
      pixelOffsetY: offY,
    );
  }

  /// Returns tile URL for relative tile position (dx, dy) from center.
  String tileUrl(int dx, int dy) {
    final maxTile = math.pow(2, zoom).toInt();
    final x = (centerX + dx) % maxTile;
    final y = centerY + dy;
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }
}

class _GeoResult {
  final double lat;
  final double lon;
  const _GeoResult(this.lat, this.lon);
}

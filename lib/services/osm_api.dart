import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../engine/meeting_engine.dart';
import '../models.dart';

class Weather {
  const Weather(this.rainChance, this.celsius);
  final int rainChance;
  final double celsius;

  /// Dışarıda oturmak için kötü hava: yağmur ihtimali yüksek ya da soğuk.
  bool get stayInside => rainChance >= 50 || celsius < 8;

  String get summary => '${celsius.round()}°C · yağış ihtimali %$rainChance';
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// OSRM'in bir noktayı yola "yapıştırdığı" mesafe bundan büyükse (deniz, park,
/// kapalı alan) o noktaya ulaşılamaz sayılır.
const maxSnapMeters = 250.0;

/// Tüm dış istekler buradan geçer: yalnızca HTTPS, kimlik belirten User-Agent,
/// zaman aşımı, yanıt boyutu sınırı, sunucu başına ≥1 sn aralık (OSM politikası)
/// ve şema doğrulaması.
class OsmApi {
  OsmApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _hostQueue = <String, Future<void>>{};
  final _searchCache = <String, List<Place>>{};
  final _reverseCache = <String, String?>{};
  final _nearbyCache = <String, List<Venue>>{};
  static const _gap = Duration(milliseconds: 1100);

  Future<T> _get<T>(Uri uri, T Function(dynamic json) parse) async {
    if (uri.scheme != 'https') throw const ApiException('Güvensiz bağlantı engellendi.');
    final prev = _hostQueue[uri.host] ?? Future.value();
    _hostQueue[uri.host] = prev.then((_) => Future.delayed(_gap));
    await prev;
    final http.Response res;
    try {
      res = await _client
          // Tarayıcı User-Agent'ı kendisi koyar; elle eklemek CORS ön isteğini tetikler.
          .get(uri, headers: {if (!kIsWeb) 'User-Agent': appUserAgent, 'Accept-Language': 'tr'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.');
    }
    if (res.statusCode == 429) throw const ApiException('Çok fazla istek. Biraz sonra tekrar dene.');
    if (res.statusCode != 200) throw ApiException('Sunucu hatası (${res.statusCode}).');
    if (res.bodyBytes.length > 2000000) throw const ApiException('Beklenmeyen sunucu yanıtı.');
    try {
      return parse(jsonDecode(utf8.decode(res.bodyBytes)));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Beklenmeyen sunucu yanıtı.');
    }
  }

  static String _coords(Iterable<LatLng> ps) => ps
      .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
      .join(';');

  static LatLng _point(dynamic lat, dynamic lon) {
    final la = lat is num ? lat.toDouble() : double.parse(lat as String);
    final lo = lon is num ? lon.toDouble() : double.parse(lon as String);
    if (la.abs() > 90 || lo.abs() > 180) throw const FormatException();
    return LatLng(la, lo);
  }

  static void _checkOsrm(dynamic j) {
    if (j['code'] != 'Ok') throw const ApiException('Rota hesaplanamadı.');
  }

  /// Her kaynak için her hedefe süre/mesafe. Yola uzak (yapışmayan) hedefler null.
  /// `snapped`: hedeflerin yol üzerindeki gerçek konumu. `walkLastMeters` verilirse
  /// (araç) yola o kadar uzak hedefler de tutulur: yoldan hedefe yürüme süresi eklenir.
  Future<({List<List<Leg?>> rows, List<LatLng?> snapped})> table(
      String baseUrl, List<LatLng> sources, List<LatLng> destinations, {double? walkLastMeters}) {
    final s = [for (var i = 0; i < sources.length; i++) i].join(';');
    final d = [for (var i = 0; i < destinations.length; i++) sources.length + i].join(';');
    final uri = Uri.parse('$baseUrl/table/v1/driving/${_coords([...sources, ...destinations])}')
        .replace(queryParameters: {'sources': s, 'destinations': d, 'annotations': 'duration,distance'});
    return _get(uri, (j) {
      _checkOsrm(j);
      final dests = j['destinations'] as List;
      final snapM = [for (final x in dests) (x['distance'] as num).toDouble()];
      final reach = walkLastMeters ?? maxSnapMeters;
      final snapped = [
        for (final x in dests)
          (x['distance'] as num) > maxSnapMeters
              ? null
              : _point((x['location'] as List)[1], (x['location'] as List)[0]),
      ];
      final durs = j['durations'] as List, dists = j['distances'] as List;
      final rows = [
        for (var i = 0; i < sources.length; i++)
          [
            for (var c = 0; c < destinations.length; c++)
              snapM[c] > reach || durs[i][c] == null || dists[i][c] == null
                  ? null
                  : Leg((durs[i][c] as num).toDouble() + (walkLastMeters == null ? 0 : snapM[c] / walkSpeed),
                      (dists[i][c] as num).toDouble() + (walkLastMeters == null ? 0 : snapM[c])),
          ],
      ];
      if (rows.length != sources.length || snapped.length != destinations.length) {
        throw const FormatException();
      }
      return (rows: rows, snapped: snapped);
    });
  }

  Future<List<LatLng>> route(String baseUrl, LatLng from, LatLng to) {
    final uri = Uri.parse('$baseUrl/route/v1/driving/${_coords([from, to])}')
        .replace(queryParameters: {'overview': 'full', 'geometries': 'geojson'});
    return _get(uri, (j) {
      _checkOsrm(j);
      final coords = (j['routes'] as List).first['geometry']['coordinates'] as List;
      return [for (final c in coords) _point((c as List)[1], c[0])];
    });
  }

  /// Nominatim politikası otomatik tamamlamayı yasaklar: yalnızca kullanıcı
  /// "ara" dediğinde çağır.
  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 3 || q.length > 100) return const [];
    final cached = _searchCache[q.toLowerCase()];
    if (cached != null) return cached;
    final uri = Uri.parse('$nominatimUrl/search')
        .replace(queryParameters: {'q': q, 'format': 'jsonv2', 'limit': '6'});
    final places = await _get(uri, (j) => [
          for (final x in j as List)
            Place(_label(x), _point(x['lat'], x['lon'])),
        ]);
    return _searchCache[q.toLowerCase()] = places;
  }

  Future<String?> reverse(LatLng p) async {
    final key = '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    if (_reverseCache.containsKey(key)) return _reverseCache[key];
    final uri = Uri.parse('$nominatimUrl/reverse').replace(queryParameters: {
      'lat': '${p.latitude}',
      'lon': '${p.longitude}',
      'format': 'jsonv2',
      'zoom': '18',
    });
    return _reverseCache[key] = await _get(uri, (j) => j['error'] == null ? _label(j) : null);
  }

  /// Noktanın çevresindeki isimli kafe, restoran, bar ve parklar; yakından uzağa.
  Future<List<Venue>> nearby(LatLng p, {int radius = 450}) async {
    final key = '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    final cached = _nearbyCache[key];
    if (cached != null) return cached;
    final at = 'around:$radius,${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
    final q = '[out:json][timeout:15];('
        'nwr($at)[amenity~"^(cafe|restaurant|fast_food|pub|bar|ice_cream)\$"][name];'
        'nwr($at)[leisure=park][name];'
        ');out center 80;';
    const dist = Distance();
    List<Venue> parse(dynamic j) {
      final out = <Venue>[];
      for (final e in j['elements'] as List) {
        final tags = e['tags'];
        if (tags is! Map || tags['name'] is! String) continue;
        final kind = VenueKind.fromTags(tags);
        final c = e['center'] ?? e;
        if (kind == null || c['lat'] == null) continue;
        final point = _point(c['lat'], c['lon']);
        final name = (tags['name'] as String).trim();
        final hours = tags['opening_hours'] is String ? (tags['opening_hours'] as String).trim() : null;
        out.add(Venue(name.length > 60 ? name.substring(0, 60) : name, kind, point, dist(p, point),
            features: VenueFeature.fromTags(tags),
            hours: hours == null || hours.isEmpty ? null : (hours.length > 80 ? hours.substring(0, 80) : hours)));
      }
      out.sort((a, b) => a.meters.compareTo(b.meters));
      return out.take(15).toList();
    }

    List<Venue> venues;
    try {
      venues = await _get(Uri.parse(overpassUrl).replace(queryParameters: {'data': q}), parse);
    } on ApiException {
      venues = await _get(Uri.parse(overpassFallbackUrl).replace(queryParameters: {'data': q}), parse);
    }
    return _nearbyCache[key] = venues;
  }

  /// Buluşma saatindeki yağış olasılığı (%) ve sıcaklık (°C). Tahmin yoksa null.
  Future<Weather?> weather(LatLng p, DateTime at) async {
    final uri = Uri.parse(weatherUrl).replace(queryParameters: {
      'latitude': p.latitude.toStringAsFixed(3),
      'longitude': p.longitude.toStringAsFixed(3),
      'hourly': 'precipitation_probability,temperature_2m',
      'timezone': 'auto',
      'forecast_days': '3',
    });
    final hour = '${at.year}-${_two(at.month)}-${_two(at.day)}T${_two(at.hour)}:00';
    return _get(uri, (j) {
      final h = j['hourly'];
      final i = (h['time'] as List).indexOf(hour);
      if (i < 0) return null;
      final rain = h['precipitation_probability'][i], temp = h['temperature_2m'][i];
      if (rain is! num || temp is! num) return null;
      return Weather(rain.round().clamp(0, 100), temp.toDouble());
    });
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _label(dynamic x) {
    final name = x['name'] is String ? (x['name'] as String).trim() : '';
    final parts = (x['display_name'] as String).split(',').map((s) => s.trim()).toList();
    final label = name.isNotEmpty && parts.length > 1
        ? '$name, ${parts.skip(1).take(2).join(', ')}'
        : parts.take(3).join(', ');
    return label.length > 120 ? label.substring(0, 120) : label;
  }
}

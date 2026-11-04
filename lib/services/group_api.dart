import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models.dart';
import 'osm_api.dart';

class GroupMember {
  const GroupMember(this.id, this.name, this.mode, this.place);
  final String id;
  final String name;
  final TravelMode mode;
  final Place place;
}

final _uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', caseSensitive: false);

/// Davet grupları. Supabase'in tablolarına doğrudan erişilmez; yalnızca
/// supabase/schema.sql'deki fonksiyonlar çağrılır. Grup kimliği (UUID) tahmin
/// edilemez olduğundan linke sahip olan gruba erişir; gruplar 24 saatte silinir.
class GroupApi {
  GroupApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static bool get configured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String? parseId(String text) => _uuid.firstMatch(text)?.group(0)?.toLowerCase();

  /// Paylaşılacak link; site adresi yoksa null (yalnızca kod paylaşılır).
  static String? link(String id) => siteUrl.isEmpty ? null : '$siteUrl/g/$id';


  Future<dynamic> _rpc(String fn, Map<String, Object?> args) async {
    if (!configured) throw const ApiException('Davet özelliği henüz yapılandırılmadı.');
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$fn');
    if (uri.scheme != 'https') throw const ApiException('Güvensiz bağlantı engellendi.');
    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {
                'apikey': supabaseAnonKey,
                'Authorization': 'Bearer $supabaseAnonKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(args))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final msg = body is Map ? body['message'] : null;
      throw ApiException(switch (msg) {
        'group_not_found' => 'Bu davet bulunamadı veya süresi doldu (davetler 24 saat geçerli).',
        'group_full' => 'Grup dolu (en fazla 5 kişi).',
        'invalid_member' => 'Bilgiler geçersiz. İsmi ve konumu kontrol et.',
        _ => 'Sunucu hatası (${res.statusCode}).',
      });
    }
    return body;
  }

  Future<String> create() async {
    final id = await _rpc('create_group', {});
    if (id is! String || parseId(id) == null) throw const ApiException('Beklenmeyen sunucu yanıtı.');
    return id;
  }

  Future<void> join(String groupId, String name, TravelMode mode, Place place) => _rpc('join_group', {
        'gid': groupId,
        'p_name': name,
        'p_mode': mode.name,
        'p_lat': place.point.latitude,
        'p_lon': place.point.longitude,
        'p_label': place.label.length > 120 ? place.label.substring(0, 120) : place.label,
      });

  Future<List<GroupMember>> members(String groupId) async {
    final rows = await _rpc('group_members', {'gid': groupId});
    try {
      return [
        for (final r in rows as List)
          GroupMember(
            r['id'] as String,
            r['name'] as String,
            TravelMode.values.firstWhere((m) => m.name == r['mode'] && m.available),
            Place(r['label'] as String, _point(r['lat'], r['lon'])),
          ),
      ];
    } catch (_) {
      throw const ApiException('Beklenmeyen sunucu yanıtı.');
    }
  }

  static LatLng _point(Object? lat, Object? lon) {
    final la = (lat as num).toDouble(), lo = (lon as num).toDouble();
    if (la.abs() > 90 || lo.abs() > 180) throw const FormatException();
    return LatLng(la, lo);
  }
}

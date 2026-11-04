import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../engine/gathering.dart';
import '../models.dart';
import 'osm_api.dart';

class GroupMember {
  const GroupMember(this.id, this.name, this.mode, this.place, {this.userId = '', this.tag, this.isMe = false});
  final String id;
  final String name;
  final TravelMode mode;
  final Place place;
  final String userId;

  /// Grupta aynı isimde başka biri varsa ayırt etmek için e-posta; yoksa null.
  final String? tag;
  final bool isMe;

  /// Ekranda ve defterde kullanılan, grup içinde benzersiz ad.
  String get label => tag == null ? name : '$name ($tag)';
}

class Profile {
  const Profile(this.name, this.email);
  final String? name;
  final String email;
}

/// Giriş yapmış kişinin profili (isim + e-posta). null: giriş yok ya da henüz isim seçilmedi.
final me = ValueNotifier<Profile?>(null);

final _uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', caseSensitive: false);

/// Hesaplar, davet grupları ve ortak defter. Supabase'in tablolarına doğrudan erişilmez;
/// yalnızca supabase/schema.sql'deki fonksiyonlar, giriş yapmış kişinin oturumuyla çağrılır.
class GroupApi {
  GroupApi({http.Client? client, String? Function()? token, String? url, String? key})
      : _client = client ?? http.Client(),
        _token = token ?? _sessionToken,
        _url = url ?? supabaseUrl,
        _key = key ?? supabaseAnonKey;
  final http.Client _client;
  final String? Function() _token;
  final String _url, _key;

  static bool get configured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String? _sessionToken() => configured ? Supabase.instance.client.auth.currentSession?.accessToken : null;

  static String? parseId(String text) => _uuid.firstMatch(text)?.group(0)?.toLowerCase();

  /// Paylaşılacak link; site adresi yoksa null (yalnızca kod paylaşılır).
  static String? link(String id) => siteUrl.isEmpty ? null : '$siteUrl/g/$id';

  Future<dynamic> _rpc(String fn, Map<String, Object?> args) async {
    if (_url.isEmpty || _key.isEmpty) throw const ApiException('Davet özelliği henüz yapılandırılmadı.');
    final token = _token();
    if (token == null) throw const ApiException('Önce Google ile giriş yapmalısın.');
    final uri = Uri.parse('$_url/rest/v1/rpc/$fn');
    if (uri.scheme != 'https') throw const ApiException('Güvensiz bağlantı engellendi.');
    final http.Response res;
    try {
      res = await _client
          .post(uri,
              headers: {
                'apikey': _key,
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(args))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ApiException('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.');
    }
    final Object? body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw const ApiException('Beklenmeyen sunucu yanıtı.');
    }
    if (res.statusCode >= 400) {
      final msg = body is Map ? body['message'] : null;
      throw ApiException(switch (msg) {
        'group_not_found' => 'Bu davet bulunamadı veya süresi doldu (davetler 7 gün geçerli).',
        'group_full' => 'Grup dolu (en fazla 5 kişi).',
        'invalid_member' => 'Bilgiler geçersiz. Konumu kontrol et.',
        'auth_required' => 'Oturumun kapanmış. Tekrar giriş yap.',
        'profile_required' => 'Önce bir isim seçmelisin.',
        'invalid_name' => 'İsim 1-30 karakter olmalı.',
        'not_member' => 'Bu defteri görmek için önce gruba katılmalısın.',
        'too_many' => 'Bu grupta çok fazla kayıt var.',
        'invalid_item' || 'invalid_expense' => 'Kayıt geçersiz; kişiler gruptan olmalı.',
        'rate_limited' => 'Bugün çok fazla grup kurdun. Yarın tekrar dene.',
        _ => res.statusCode == 401 ? 'Oturumun kapanmış. Tekrar giriş yap.' : 'Sunucu hatası (${res.statusCode}).',
      });
    }
    return body;
  }

  Never _bad() => throw const ApiException('Beklenmeyen sunucu yanıtı.');

  // ---------- Profil ----------

  Future<Profile?> myProfile() async {
    final rows = await _rpc('my_profile', {});
    if (rows is! List || rows.isEmpty) return null;
    final r = rows.first;
    if (r is! Map || r['email'] is! String) _bad();
    return Profile(r['name'] as String?, r['email'] as String);
  }

  Future<void> setProfile(String name) => _rpc('set_profile', {'p_name': name.trim()});

  Future<void> deleteAccount() => _rpc('delete_account', {});

  // ---------- Gruplar ----------

  Future<String> create() async {
    final id = await _rpc('create_group', {});
    if (id is! String || parseId(id) == null) _bad();
    return id;
  }

  /// İsim profilden alınır. Aynı kişi tekrar katılırsa konumu güncellenir.
  Future<void> join(String groupId, TravelMode mode, Place place) => _rpc('join_group', {
        'gid': groupId,
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
            userId: r['user_id'] as String? ?? '',
            tag: r['tag'] as String?,
            isMe: r['is_me'] == true,
          ),
      ];
    } catch (_) {
      _bad();
    }
  }

  // ---------- Ortak defter ----------
  // Sunucu kişileri kullanıcı kimliğiyle tutar; uygulama grup içinde benzersiz adlarla
  // (GroupMember.label) çalışır. Çeviri burada yapılır.

  Future<Gathering> gathering(String groupId, List<GroupMember> members) async {
    final j = await _rpc('gathering', {'gid': groupId});
    final label = {for (final m in members) m.userId: m.label};
    String name(Object? uid) => label[uid] ?? 'Gruptan ayrılan biri';
    try {
      final map = j as Map;
      return Gathering(
        'group:$groupId',
        [for (final m in members) m.label],
        spot: map['spot'] as String? ?? '',
        items: [
          for (final i in map['items'] as List)
            BringItem(i['name'] as String,
                id: i['id'] as String, who: i['who'] == null ? null : name(i['who']), done: i['done'] == true),
        ],
        expenses: [
          for (final e in map['expenses'] as List)
            Expense(e['what'] as String, name(e['payer']), (e['kurus'] as num).toInt(),
                [for (final u in e['for'] as List) name(u)],
                id: e['id'] as String),
        ],
      );
    } catch (_) {
      _bad();
    }
  }

  Future<void> setSpot(String groupId, String spot) => _rpc('set_spot', {'gid': groupId, 'p_spot': spot});

  Future<List<String>> addItems(String groupId, List<String> names) async {
    final ids = await _rpc('add_items', {'gid': groupId, 'p_names': names});
    if (ids is! List || ids.length != names.length) _bad();
    return [for (final x in ids) x as String];
  }

  Future<void> setItem(String itemId, String? whoUserId, bool done) =>
      _rpc('set_item', {'iid': itemId, 'p_who': whoUserId, 'p_done': done});

  Future<void> deleteItem(String itemId) => _rpc('delete_item', {'iid': itemId});

  Future<String> addExpense(String groupId, String what, String payerUserId, int kurus, List<String> forUserIds) async {
    final id = await _rpc('add_expense', {
      'gid': groupId,
      'p_what': what,
      'p_payer': payerUserId,
      'p_kurus': kurus,
      'p_for': forUserIds,
    });
    if (id is! String) _bad();
    return id;
  }

  Future<void> deleteExpense(String expenseId) => _rpc('delete_expense', {'eid': expenseId});

  static LatLng _point(Object? lat, Object? lon) {
    final la = (lat as num).toDouble(), lo = (lon as num).toDouble();
    if (la.abs() > 90 || lo.abs() > 180) throw const FormatException();
    return LatLng(la, lo);
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'group_api.dart';

/// Kullanıcının kapatabildiği bildirim türleri. Adlar supabase/schema.sql'deki category ile aynı.
enum NotifyKind {
  group('Grup hareketleri', 'Biri katılınca, nereden geleceğini değiştirince, buluşma yeri netleşince'),
  items('Kim ne getiriyor', 'Sana bir iş verilince, listeye bir şey eklenince'),
  money('Hesap', 'Seni ilgilendiren bir masraf eklenip silinince'),
  live('Yoldayım / vardım', 'Arkadaşın yola çıkınca, gecikeceğini söyleyince, varınca'),
  reminder('Hatırlatmalar', 'Defter silinmeden bir gün önce, hesapta masraf varsa');

  const NotifyKind(this.label, this.detail);
  final String label, detail;
}

/// Hesaba bağlı tercihler. Giriş varsa sunucuda tutulur (her cihazda aynı), yoksa yalnızca bu cihazda.
class Prefs {
  const Prefs({this.mode = TravelMode.walk, this.home, this.late = false, this.off = const {}});

  /// Yeni buluşmada seni hangi araçla başlatalım.
  final TravelMode mode;

  /// Ev / en sık çıktığın yer: "Nereden geleceksin?" hazır gelir.
  final Place? home;
  final bool late;

  /// Telefon bildirimi kapatılan türler (uygulama içi kutuya yine düşer).
  final Set<NotifyKind> off;

  Prefs copyWith({TravelMode? mode, Place? Function()? home, bool? late, Set<NotifyKind>? off}) => Prefs(
    mode: mode ?? this.mode,
    home: home == null ? this.home : home(),
    late: late ?? this.late,
    off: off ?? this.off,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (home case final h?) 'home': {'label': h.label, 'lat': h.point.latitude, 'lon': h.point.longitude},
    'late': late,
    'notify': {for (final k in NotifyKind.values) k.name: !off.contains(k)},
  };

  /// Bozuk ya da eski bir kayıt uygulamayı kilitlemesin: tanınmayan alan varsayılana döner.
  factory Prefs.fromJson(Object? j) {
    if (j is! Map) return const Prefs();
    Place? home;
    final h = j['home'];
    if (h is Map && h['label'] is String && h['lat'] is num && h['lon'] is num) {
      final lat = (h['lat'] as num).toDouble(), lon = (h['lon'] as num).toDouble();
      if (lat.abs() <= 90 && lon.abs() <= 180) home = Place(h['label'] as String, LatLng(lat, lon));
    }
    final n = j['notify'];
    return Prefs(
      mode: TravelMode.values.where((m) => m.name == j['mode'] && m.available).firstOrNull ?? TravelMode.walk,
      home: home,
      late: j['late'] == true,
      off: {if (n is Map) ...NotifyKind.values.where((k) => n[k.name] == false)},
    );
  }
}

final prefs = ValueNotifier<Prefs>(const Prefs());

/// Görünüm cihaza özeldir (telefon koyu, tablet açık olabilir).
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

const _prefsKey = 'prefs_v1', _themeKey = 'theme';

Future<void> loadLocalPrefs() async {
  final p = await SharedPreferences.getInstance();
  try {
    prefs.value = Prefs.fromJson(jsonDecode(p.getString(_prefsKey) ?? '{}'));
  } catch (_) {
    prefs.value = const Prefs();
  }
  themeMode.value = ThemeMode.values.where((m) => m.name == p.getString(_themeKey)).firstOrNull ?? ThemeMode.system;
}

/// Giriş sonrası: sunucuda kayıt varsa o geçerli; yoksa bu cihazdakiler hesaba taşınır.
Future<void> adoptServerPrefs(Map<String, Object?> server, GroupApi api) async {
  if (server.isEmpty) return savePrefs(prefs.value, api: api);
  prefs.value = Prefs.fromJson(server);
  await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(prefs.value.toJson()));
}

/// Ekran hemen güncellenir; sunucuya yazılamazsa hata fırlatır (ekran bildirir).
Future<void> savePrefs(Prefs p, {GroupApi? api}) async {
  prefs.value = p;
  await (await SharedPreferences.getInstance()).setString(_prefsKey, jsonEncode(p.toJson()));
  if (GroupApi.configured && me.value?.name != null) await (api ?? GroupApi()).setPrefs(p.toJson());
}

Future<void> saveTheme(ThemeMode m) async {
  themeMode.value = m;
  await (await SharedPreferences.getInstance()).setString(_themeKey, m.name);
}

/// Yeni buluşmada "sen": isim profilden; araç, çıkış yeri ve geç kalma tercihlerden.
Participant meAsParticipant(Color color) => Participant(me.value?.name ?? 'Sen', color)
  ..mode = prefs.value.mode
  ..place = prefs.value.home
  ..lateBuffer = prefs.value.late ? lateBufferMinutes : 0;

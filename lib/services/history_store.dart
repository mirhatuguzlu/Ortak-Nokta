import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/meeting_engine.dart';

/// Onaylanan buluşmalar ve tercihler yalnızca bu cihazda tutulur.
class HistoryStore {
  static const _meetings = 'meetings_v1', _mode = 'fairness_mode', _rotate = 'rotate';
  static const maxRecords = 50;

  Future<List<MeetingRecord>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_meetings);
    if (raw == null) return [];
    try {
      return [for (final x in jsonDecode(raw) as List) MeetingRecord.fromJson(x as Map<String, dynamic>)];
    } catch (_) {
      return []; // bozuk kayıt uygulamayı kilitlemesin
    }
  }

  Future<void> add(MeetingRecord r) async {
    final all = [r, ...await load()].take(maxRecords).toList();
    await (await SharedPreferences.getInstance())
        .setString(_meetings, jsonEncode([for (final x in all) x.toJson()]));
  }

  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_meetings);

  Future<(FairnessMode, bool)> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final mode = FairnessMode.values.where((m) => m.name == p.getString(_mode)).firstOrNull;
    return (mode ?? FairnessMode.fair, p.getBool(_rotate) ?? true);
  }

  Future<void> savePrefs(FairnessMode mode, bool rotate) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_mode, mode.name);
    await p.setBool(_rotate, rotate);
  }
}

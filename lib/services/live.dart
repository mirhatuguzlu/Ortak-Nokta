import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_api.dart';

/// Sunucunun "değişti" sinyallerini dinler (supabase/schema.sql > Canlı yayın): `group:<id>`
/// kanalı liste, hesap ve üyeler için, `user:<id>` bildirim kutusu için. Veri sinyalle gelmez;
/// [onChange] her zamanki fonksiyonlarla çeker. Kanal kurulamazsa (üye değilsin, ağ koptu,
/// Realtime kapalı) ya da bir sinyal kaçarsa [fallback] aralıkla yine bakılır.
class LiveRefresh {
  LiveRefresh(String topic, String event, this._onChange, {Duration fallback = const Duration(seconds: 30)}) {
    _timer = Timer.periodic(fallback, (_) => _onChange());
    if (GroupApi.configured && Supabase.instance.client.auth.currentSession != null) {
      _channel = Supabase.instance.client
          .channel(topic, opts: const RealtimeChannelConfig(private: true))
          .onBroadcast(event: event, callback: (_) => _soon())
          .subscribe();
    }
  }

  final VoidCallback _onChange;
  Timer? _timer, _debounce;
  RealtimeChannel? _channel;

  /// Listeye 10 şey birden eklenince 10 sinyal gelir; tek yenileme yeter.
  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _onChange);
  }

  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    if (_channel case final c?) Supabase.instance.client.removeChannel(c);
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'group_api.dart';
import 'osm_api.dart';

/// Telefon bildirimleri (Firebase Cloud Messaging). Firebase değerleri verilmeden derlenen
/// uygulamada hiçbir şey yapmaz; bildirimler yine uygulama içi kutuya düşer.
/// Gönderen taraf: supabase/functions/push.
// shortcut: firebase_messaging 17 kayıt anahtarı (getToken) yerine FID (register/onRegistered) öneriyor;
// FCM v1 gönderimi anahtarla kanıtlanmış yol olduğu için eskisi kullanılıyor. FID ile gönderim belgelenince geçilir.
// ignore_for_file: deprecated_member_use
abstract final class Push {
  static String get _appId => defaultTargetPlatform == TargetPlatform.iOS ? firebaseIosAppId : firebaseAndroidAppId;

  static bool get configured =>
      GroupApi.configured &&
      !kIsWeb && // shortcut: web'de telefon bildirimi yok (yalnızca kutu); gerekirse service worker + VAPID eklenir
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      _appId.isNotEmpty;

  static bool _ready = false;
  static bool get ready => _ready;
  static final _api = GroupApi();

  /// Bildirime dokunarak açılışta [open] o grubun sayfasını açar.
  static Future<void> init(void Function(String groupId) open) async {
    if (!configured) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: defaultTargetPlatform == TargetPlatform.iOS && firebaseIosApiKey.isNotEmpty
              ? firebaseIosApiKey
              : firebaseApiKey,
          appId: _appId,
          messagingSenderId: firebaseSenderId,
          projectId: firebaseProjectId,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Firebase açılamadı: $e');
      return;
    }
    final m = FirebaseMessaging.instance;
    void handle(RemoteMessage? msg) {
      final g = GroupApi.parseId('${msg?.data['group_id'] ?? ''}');
      if (g != null) open(g);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(handle);
    m.onTokenRefresh.listen(_register);
    handle(await m.getInitialMessage());
  }

  static bool _granted(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
      s.authorizationStatus == AuthorizationStatus.provisional;

  /// null: bu sürümde telefon bildirimi yok.
  static Future<bool?> allowed() async =>
      _ready ? _granted(await FirebaseMessaging.instance.getNotificationSettings()) : null;

  /// Telefonun izin penceresini açar; izin verilirse bu telefonu hesaba bağlar.
  static Future<bool> enable() async {
    if (!_ready) return false;
    final ok = _granted(await FirebaseMessaging.instance.requestPermission());
    if (ok) await sync();
    return ok;
  }

  /// İzin zaten varsa sessizce kaydeder (her girişte; anahtar değişmiş olabilir).
  static Future<void> sync() async {
    if (await allowed() != true) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _register(t);
    } catch (e) {
      debugPrint('Bildirim anahtarı alınamadı: $e');
    }
  }

  static Future<void> _register(String token) async {
    try {
      await _api.registerDevice(token, defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    } on ApiException {
      // Giriş yoksa ya da ağ yoksa: bir sonraki girişte sync() tekrar dener.
    }
  }

  /// Çıkışta: bu telefona artık o hesabın bildirimleri gelmesin.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _api.unregisterDevice(t);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Ağ yoksa sunucu 404 alınca anahtarı kendisi siler (push Edge Function).
    }
  }
}

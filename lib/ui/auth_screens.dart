import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

import '../services/group_api.dart';
import '../services/osm_api.dart';
import '../services/prefs.dart';
import '../services/push.dart';
import 'theme.dart';

/// Telefonda Google'ın kendi hesap seçicisi uygulamanın içinde açılır (tarayıcıya gidilmez);
/// seçilen hesabın kimlik belirteci Supabase'e verilir. Web'de olağan Google sayfası kullanılır.
Future<void> signInWithGoogle() async {
  final auth = Supabase.instance.client.auth;
  if (kIsWeb) {
    await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: Uri.base.origin + Uri.base.path,
      queryParams: {'prompt': 'select_account'}, // ortak cihazda başka hesap seçilebilsin
    );
    return;
  }
  if (googleWebClientId.isEmpty) throw const AuthException('GOOGLE_WEB_CLIENT_ID verilmemiş (SETUP.md > 2).');
  await (_google ??= GoogleSignIn.instance.initialize(
    serverClientId: googleWebClientId,
    clientId: googleIosClientId.isEmpty ? null : googleIosClientId,
  ));
  final user = await GoogleSignIn.instance.authenticate();
  final idToken = user.authentication.idToken;
  if (idToken == null) throw const AuthException('Google kimlik belirteci vermedi.');
  const scopes = ['email', 'profile'];
  final grant = await user.authorizationClient.authorizationForScopes(scopes) ??
      await user.authorizationClient.authorizeScopes(scopes);
  await auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken, accessToken: grant.accessToken);
}

Future<void>? _google; // initialize yalnızca bir kez çağrılabilir

Future<void> signOut() async {
  await Push.unregister(); // oturum kapanmadan: bu telefona o hesabın bildirimleri gelmesin
  await Supabase.instance.client.auth.signOut();
  if (_google != null) await GoogleSignIn.instance.signOut(); // sonraki girişte hesap seçici yine sorsun
  me.value = null;
  inbox.value = const [];
}

/// Supabase yapılandırılmışsa uygulamanın tamamı giriş ister: önce Google, sonra isim.
/// Gezgin (Navigator) arkada canlı kalır; davet linkiyle açılan sayfa girişten sonra görünür.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _Stage { loading, signedOut, needsName, ready, error }

class _AuthGateState extends State<AuthGate> {
  final _api = GroupApi();
  var _stage = _Stage.loading;
  String? _error;
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (!GroupApi.configured) {
      _stage = _Stage.ready;
      return;
    }
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.initialSession ||
          s.event == AuthChangeEvent.signedOut) {
        _load();
      }
    });
    me.addListener(_onProfile);
  }

  @override
  void dispose() {
    _sub?.cancel();
    me.removeListener(_onProfile);
    super.dispose();
  }

  void _onProfile() {
    if (!mounted) return;
    final p = me.value;
    final session = Supabase.instance.client.auth.currentSession;
    setState(() => _stage = session == null
        ? _Stage.signedOut
        : p?.name == null
            ? _Stage.needsName
            : _Stage.ready);
  }

  Future<void> _load() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      me.value = null;
      if (mounted) setState(() => _stage = _Stage.signedOut);
      return;
    }
    setState(() => _stage = _Stage.loading);
    try {
      final p = await _api.myProfile();
      if (p == null) {
        // Oturum var ama kullanıcı sunucuda yok (hesap silinmiş): temiz başlangıç.
        await signOut();
        return;
      }
      me.value = p;
      if (p.name != null) {
        try {
          await adoptServerPrefs(p.prefs, _api);
        } on ApiException {
          // tercihler yüklenemedi: bu cihazdakilerle devam
        }
        Push.sync();
      }
      _onProfile();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _stage == _Stage.ready;
    return Stack(children: [
      Offstage(offstage: !ready, child: TickerMode(enabled: ready, child: widget.child)),
      // Kendi Navigator'ı: metin alanları ve diyaloglar için Overlay gerekir; aşama değişince yenilenir.
      // HeroControllerScope.none: yoksa uygulamanın ana gezgininin HeroController'ını ödünç alır,
      // ana gezgin bozulur ve sonraki her sayfa siyah açılıp donar.
      if (!ready)
        HeroControllerScope.none(
          child: Navigator(
            key: ValueKey(_stage),
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => switch (_stage) {
                _Stage.signedOut => const _SignIn(),
                _Stage.needsName => NameScreen(api: _api, email: me.value?.email ?? ''),
                _Stage.error => _Problem(message: _error ?? '', onRetry: _load),
                _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
              },
            ),
          ),
        ),
    ]);
  }
}

class _SignIn extends StatefulWidget {
  const _SignIn();

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _error = 'Google girişi açılamadı (${e.code.name}). İnternetini kontrol edip tekrar dene.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = 'Giriş tamamlanamadı: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Google girişi açılamadı. İnternetini kontrol edip tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(28), children: [
              const Icon(Icons.join_inner, size: 56, color: Palette.green),
              const SizedBox(height: 16),
              Text('Ortak Nokta', textAlign: TextAlign.center, style: text.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Davet linki, ortak liste ve hesap herkesin aynı şeyi görmesi için bir hesap ister. '
                'Google hesabınla tek dokunuşta giriş yap; arkadaşlarına yalnızca seçtiğin isim görünür.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : _go,
                icon: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Google ile giriş yap'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                ),
              const SizedBox(height: 16),
              Text(
                'E-postan yalnızca bir grupta seninle aynı isimde biri varsa, sizi ayırt etmek için o grubun '
                'üyelerine gösterilir.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// İlk girişte (ve sonra hesap menüsünden) isim seçimi.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key, required this.api, required this.email, this.initial = '', this.onDone});
  final GroupApi api;
  final String email;
  final String initial;
  final VoidCallback? onDone;

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final _name = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Bir isim yaz.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.setProfile(name);
      me.value = Profile(name, widget.email);
      widget.onDone?.call();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşların seni nasıl görsün?')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'İsmin', hintText: 'ör. Zeynep'),
                onSubmitted: (_) => _save(),
              ),
              Text('Giriş: ${widget.email}', style: TextStyle(color: scheme.onSurfaceVariant)),
              if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : _save,
                child: const Text('Devam'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
              TextButton(onPressed: signOut, child: const Text('Çıkış yap')),
            ]),
          ),
        ),
      );
}

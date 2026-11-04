import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/group_api.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import '../services/prefs.dart';
import '../services/push.dart';
import 'auth_screens.dart';
import 'map_parts.dart';

/// Telefon izni yoksa, ilk kez bir grup kurulunca ya da gruba katılınca bir kez sorulur.
/// İzin penceresi tek seferlik olduğundan önce neden istendiği anlatılır.
Future<void> askForPushOnce(BuildContext context) async {
  if (await Push.allowed() != false) return; // telefon bildirimi yok ya da zaten açık
  final store = await SharedPreferences.getInstance();
  if (store.getBool('push_asked') == true || !context.mounted) return;
  await store.setBool('push_asked', true);
  if (!context.mounted) return;
  final yes = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.notifications_active_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'Biri katılınca haber vereyim mi?',
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Gruba biri katılınca, sana bir iş verilince ya da arkadaşın yola çıkınca kısa bir bildirim gelir. '
              'Hangi türlerin geleceğini Ayarlar\'dan seçersin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Evet, haber ver')),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Şimdi değil')),
          ],
        ),
      ),
    ),
  );
  if (yes == true) await Push.enable();
}

/// Tek iş: uygulamanın nasıl davrandığı (bildirimler, görünüm, veri) ve hesap.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Telefonun ayarlarından izin değiştirilip geri dönülünce.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final a = await Push.allowed();
    if (mounted) setState(() => _allowed = a);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _enable() async {
    final ok = await Push.enable();
    await _check();
    if (!ok) {
      _snack('İzin verilmedi. Telefonun Ayarlar > Uygulamalar > Ortak Nokta > Bildirimler bölümünden açabilirsin.');
    }
  }

  Future<void> _toggle(NotifyKind k, bool on) async {
    final off = {...prefs.value.off};
    on ? off.remove(k) : off.add(k);
    try {
      await savePrefs(prefs.value.copyWith(off: off));
    } on ApiException catch (e) {
      _snack('Kaydedilemedi: ${e.message}');
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  Future<void> _clearHistory() async {
    if (!await _confirm(
      'Geçmiş silinsin mi?',
      'Bu telefondaki adalet defteri sıfırlanır; sıra yeniden başlar.',
      'Sil',
    )) {
      return;
    }
    await HistoryStore().clear();
    _snack('Bu telefondaki geçmiş silindi.');
  }

  Future<void> _deleteAccount() async {
    if (!await _confirm(
      'Hesap silinsin mi?',
      'Bu geri alınamaz. İsmin, gruplardaki konumların ve bildirimlerin silinir; başkalarının hesap '
          'kayıtlarındaki tutarlar kalır.',
      'Hesabımı sil',
    )) {
      return;
    }
    try {
      await Push.unregister();
      await GroupApi().deleteAccount();
      await signOut();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget section(String t) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(t, style: text.titleMedium?.copyWith(color: scheme.primary)),
    );
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([prefs, themeMode, me]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('Ayarlar', style: text.headlineSmall),
              if (GroupApi.configured) ...[
                section('Bildirimler'),
                if (!Push.ready)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline),
                    title: Text('Bu sürümde telefon bildirimi yok'),
                    subtitle: Text('Olanlar yine Bildirimler sekmesinde, anında görünür.'),
                  )
                else if (_allowed == true)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_active_outlined),
                    title: Text('Telefon bildirimleri açık'),
                    subtitle: Text('Tamamen kapatmak için telefonun Ayarlar > Ortak Nokta > Bildirimler bölümü'),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: const Text('Telefon bildirimleri kapalı'),
                    subtitle: const Text('Biri katılınca, sana iş verilince haberin olsun'),
                    trailing: FilledButton(onPressed: _enable, child: const Text('Aç')),
                  ),
                for (final k in NotifyKind.values)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(k.label),
                    subtitle: Text(k.detail),
                    value: !prefs.value.off.contains(k),
                    onChanged: (on) => _toggle(k, on),
                  ),
                Text(
                  'Kendi yaptığın şey için bildirim gelmez. Tek bir grubu susturmak için o grubun sayfasını aç.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              section('Görünüm'),
              const SizedBox(height: 4),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {themeMode.value},
                onSelectionChanged: (s) => saveTheme(s.first),
              ),
              section('Veri ve gizlilik'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: const Text('Bu telefondaki buluşma geçmişini sil'),
                onTap: _clearHistory,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Hakkında ve gizlilik'),
                onTap: () => showAbout(context),
              ),
              if (GroupApi.configured && me.value != null) ...[
                section('Hesap'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: const Text('Çıkış yap'),
                  subtitle: Text(me.value!.email),
                  onTap: signOut,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                  title: Text('Hesabımı sil', style: TextStyle(color: scheme.error)),
                  subtitle: const Text('İsmin, grup üyeliklerin ve bildirimlerin kalıcı olarak silinir'),
                  onTap: _deleteAccount,
                ),
              ],
              const SizedBox(height: 24),
              Text('Ortak Nokta 0.1.0', textAlign: TextAlign.center, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

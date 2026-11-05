import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/group_api.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import '../services/prefs.dart';
import 'auth_screens.dart';
import 'history_screen.dart';
import 'location_sheet.dart';
import 'theme.dart';

/// Tek iş: sen. Arkadaşların seni nasıl görür ve yeni bir buluşmada seni nasıl başlatalım.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _save(BuildContext context, Prefs p) async {
    try {
      await savePrefs(p);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hesaba kaydedilemedi: ${e.message}')));
      }
    }
  }

  Future<void> _pickHome(BuildContext context) async {
    final p = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocationSheet(api: OsmApi(), name: 'Ev', allowMapPick: false),
    );
    if (p != null && context.mounted) await _save(context, prefs.value.copyWith(home: () => p));
  }

  void _editName(BuildContext context, Profile p) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (route) =>
          NameScreen(api: GroupApi(), email: p.email, initial: p.name ?? '', onDone: () => Navigator.pop(route)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([me, prefs]),
          builder: (context, _) {
            final p = me.value;
            final pr = prefs.value;
            final name = p?.name ?? 'Sen';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('Profil', style: text.headlineSmall),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Palette.green,
                          child: Text(
                            name.characters.first.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: text.titleLarge),
                              Text(
                                p?.email ?? 'Hesapsız: tercihlerin yalnızca bu telefonda',
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (p != null)
                          IconButton(
                            tooltip: 'İsmimi değiştir',
                            onPressed: () => _editName(context, p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                      ],
                    ),
                  ),
                ),
                // Geliştirici derlemesinde Supabase değerleri verilmemişse giriş ekranı hiç açılmaz; nedenini söyle.
                if (kDebugMode && !GroupApi.configured)
                  Card(
                    elevation: 0,
                    color: scheme.errorContainer,
                    child: const ListTile(
                      leading: Icon(Icons.build_outlined),
                      title: Text('Bu derlemede hesap kapalı'),
                      subtitle: Text(
                        'defines.json içine SUPABASE_URL ve SUPABASE_ANON_KEY yaz, uygulamayı '
                        '--dart-define-from-file=defines.json ile yeniden başlat (hot reload yetmez).',
                      ),
                    ),
                  ),
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      'Arkadaşların seni yalnızca bu isimle görür. E-postan, bir grupta seninle aynı isimde biri '
                      'varsa sizi ayırt etmek için yalnızca o grubun üyelerine gösterilir.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Yeni buluşmada seni nasıl başlatalım?', style: text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Her seferinde baştan seçmemen için. Buluşmada yine değiştirebilirsin.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in TravelMode.values.where((m) => m.available))
                      ChoiceChip(
                        avatar: Icon(m.icon, size: 18),
                        label: Text(m.label),
                        selected: pr.mode == m,
                        onSelected: (_) => _save(context, pr.copyWith(mode: m)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.home_outlined),
                  title: Text(
                    pr.home?.label ?? 'Ev ya da en sık çıktığın yer',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: pr.home == null ? TextStyle(color: scheme.primary) : null,
                  ),
                  subtitle: const Text('"Nereden geleceksin?" hazır gelir'),
                  trailing: pr.home == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: 'Kaldır',
                          onPressed: () => _save(context, pr.copyWith(home: () => null)),
                          icon: const Icon(Icons.close),
                        ),
                  onTap: () => _pickHome(context),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.schedule),
                  title: const Text('Genelde geç kalırım'),
                  subtitle: const Text('Çıkış saatin $lateBufferMinutes dk erken gösterilir, kimse seni beklemez'),
                  value: pr.late,
                  onChanged: (v) => _save(context, pr.copyWith(late: v)),
                ),
                const SizedBox(height: 16),
                Text('Geçmişin', style: text.titleMedium),
                FutureBuilder(
                  future: HistoryStore().load(),
                  builder: (context, snap) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Adalet defteri'),
                    subtitle: Text(
                      snap.hasData
                          ? '${snap.data!.length} buluşma · kim ne kadar yol yaptı (bu telefonda)'
                          : 'Kim ne kadar yol yaptı',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

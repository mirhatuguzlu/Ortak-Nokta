import 'package:flutter/material.dart';

import '../models.dart';
import '../services/group_api.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import 'group_screens.dart';
import 'history_screen.dart';
import 'map_parts.dart';
import 'people_screen.dart';
import 'result_screen.dart';
import 'theme.dart';

/// Tek iş: ne yapmak istediğini seçmek. Her yol kendi sayfasına gider.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));

  /// Önce kendi yerini seçersin, sonra link paylaşılır; herkes katılınca sonuç açılır.
  Future<void> _invite(BuildContext context) async {
    if (!GroupApi.configured) {
      return _snack(context, 'Davet linkleri yakında. (Geliştirici: SUPABASE_URL ve SUPABASE_ANON_KEY tanımlanmalı.)');
    }
    final me = Participant('Sen', personColors[0]);
    final nav = Navigator.of(context);
    final ok = await nav.push<PersonEdit>(MaterialPageRoute(
      builder: (_) => PersonScreen(api: OsmApi(), person: me, title: 'Önce sen', action: 'Davet linki oluştur'),
    ));
    if (ok != PersonEdit.saved) return;
    final members = await nav.push<List<GroupMember>>(MaterialPageRoute(builder: (_) => InviteScreen(owner: me)));
    if (members == null) return;
    final people = [
      for (var i = 0; i < members.length && i < maxPeople; i++)
        Participant(members[i].name, personColors[i])
          ..place = members[i].place
          ..mode = members[i].mode,
    ];
    final (mode, rotate) = await HistoryStore().loadPrefs();
    nav.push(MaterialPageRoute(builder: (_) => ResultScreen(people: people, mode: mode, rotate: rotate)));
  }

  Future<void> _joinWithCode(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Davet koduyla katıl'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Linki veya kodu yapıştır'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, GroupApi.parseId(controller.text) ?? ''), child: const Text('Devam')),
        ],
      ),
    );
    controller.dispose();
    if (id == null || !context.mounted) return;
    if (id.isEmpty) return _snack(context, 'Geçerli bir davet linki veya kodu bulunamadı.');
    Navigator.push(context, MaterialPageRoute(builder: (_) => JoinScreen(groupId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), children: [
          Row(children: [
            const _Mark(),
            const SizedBox(width: 10),
            Text('Ortak Nokta', style: text.titleLarge),
            const Spacer(),
            IconButton(
              tooltip: 'Adalet defteri',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(Icons.menu_book_outlined),
            ),
            IconButton(tooltip: 'Hakkında', onPressed: () => showAbout(context), icon: const Icon(Icons.info_outline)),
          ]),
          const SizedBox(height: 48),
          Text('Bugün kiminle buluşuyorsun?', style: text.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Herkesin nereden geldiğini söyle; kimseyi ötekinden fazla yormayan yeri birlikte bulalım.',
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 36),
          _BigChoice(
            color: scheme.primaryContainer,
            accent: scheme.primary,
            icon: Icons.groups_2_outlined,
            title: 'Buluşma planla',
            body: 'Herkesin nereden geleceğini sen gir.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeopleScreen())),
          ),
          const SizedBox(height: 14),
          _BigChoice(
            color: scheme.secondaryContainer,
            accent: scheme.secondary,
            icon: Icons.link,
            title: 'Arkadaşlarını linkle çağır',
            body: 'Linki gruba at, herkes kendi yerini eklesin.',
            onTap: () => _invite(context),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(onPressed: () => _joinWithCode(context), child: const Text('Bir davet kodum var')),
          ),
        ]),
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.color,
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final Color color;
  final Color accent;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: accent, child: Icon(icon, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: 2),
                Text(body, style: text.bodyMedium),
              ]),
            ),
            Icon(Icons.arrow_forward, color: accent),
          ]),
        ),
      ),
    );
  }
}

/// Sitedeki logonun aynısı: iki kişi, ortada buluşma noktası.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 30,
        child: Stack(children: [
          Positioned(left: 2, bottom: 5, child: _dot(9, Palette.clay)),
          Positioned(right: 2, top: 5, child: _dot(9, Palette.green)),
          Center(child: _dot(6.5, Theme.of(context).colorScheme.onSurface)),
        ]),
      );

  static Widget _dot(double r, Color c) => CircleAvatar(radius: r / 2 + 2, backgroundColor: c);
}

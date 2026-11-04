import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/group_api.dart';
import '../services/live.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Uygulamanın dört kapısı; her biri tek iş yapar:
/// Buluş (yeni buluşma) · Bildirimler (olanlar) · Profil (sen kimsin, nasıl gelirsin) · Ayarlar (uygulama nasıl davranır).
/// Alttaki menü ekrana yapışık değil, içeriğin üstünde havada durur.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _tab = 0;
  LiveRefresh? _live;
  String? _listeningFor;

  @override
  void initState() {
    super.initState();
    me.addListener(_listen);
    _listen();
  }

  @override
  void dispose() {
    me.removeListener(_listen);
    _live?.dispose();
    super.dispose();
  }

  /// Bildirim kutusu açık uygulamada canlı dolar; rozet anında güncellenir.
  void _listen() {
    final uid = GroupApi.configured && me.value?.name != null ? Supabase.instance.client.auth.currentUser?.id : null;
    if (uid == _listeningFor) return;
    _listeningFor = uid;
    _live?.dispose();
    _live = null;
    if (uid == null) return;
    refreshInbox();
    _live = LiveRefresh('user:$uid', 'notify', refreshInbox, fallback: const Duration(minutes: 2));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <(IconData, IconData, String, Widget)>[
      (Icons.explore_outlined, Icons.explore, 'Buluş', const HomeScreen()),
      if (GroupApi.configured) (Icons.notifications_none, Icons.notifications, 'Bildirimler', const InboxScreen()),
      (Icons.person_outline, Icons.person, 'Profil', const ProfileScreen()),
      (Icons.settings_outlined, Icons.settings, 'Ayarlar', const SettingsScreen()),
    ];
    return PopScope(
      // Geri tuşu önce Buluş'a döner, oradayken uygulamadan çıkar.
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(index: _tab, children: [for (final t in tabs) t.$4]),
        bottomNavigationBar: FloatingNav(
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
          items: [for (final t in tabs) NavItem(t.$1, t.$2, t.$3, badge: t.$3 == 'Bildirimler' ? inbox : null)],
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label, {this.badge});
  final IconData icon, selectedIcon;
  final String label;

  /// Okunmamış sayısı rozet olarak gösterilir.
  final ValueNotifier<List<AppNotification>>? badge;
}

class FloatingNav extends StatelessWidget {
  const FloatingNav({super.key, required this.items, required this.selected, required this.onSelect});
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: scheme.surfaceContainerLowest,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _NavButton(item: items[i], selected: i == selected, onTap: () => onSelect(i)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    Widget icon = Icon(selected ? item.selectedIcon : item.icon, color: selected ? scheme.onPrimary : color, size: 22);
    if (item.badge case final b?) {
      icon = ValueListenableBuilder(
        valueListenable: b,
        builder: (_, list, child) {
          final n = list.where((x) => !x.read).length;
          return Badge(isLabelVisible: n > 0, label: Text(n > 9 ? '9+' : '$n'), child: child);
        },
        child: icon,
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: selected ? 54 : 40,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11.5,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

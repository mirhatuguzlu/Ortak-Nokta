import 'package:flutter/material.dart';

import '../services/group_api.dart';
import '../services/osm_api.dart';
import 'group_screens.dart';

/// "3 dk önce" gibi kısa zaman.
String ago(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'şimdi';
  if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
  if (d.inHours < 24) return '${d.inHours} sa önce';
  if (d.inDays < 7) return '${d.inDays} gün önce';
  return '${t.day}.${t.month}.${t.year}';
}

IconData kindIcon(String kind) => switch (kind) {
  'joined' => Icons.person_add_alt,
  'moved' => Icons.edit_location_alt_outlined,
  'spot' => Icons.place_outlined,
  'items_added' => Icons.playlist_add,
  'assigned' => Icons.assignment_ind_outlined,
  'expense' || 'expense_removed' => Icons.receipt_long_outlined,
  'on_way' => Icons.directions_walk,
  'late' => Icons.schedule,
  'arrived' => Icons.flag_outlined,
  'expiring' => Icons.hourglass_bottom,
  _ => Icons.notifications_none,
};

/// Tek iş: gruplarında olanlar. Dokununca o grubun sayfası açılır.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _api = GroupApi();

  Future<void> _read(List<String>? ids) async {
    // Önce ekranda: rozet hemen düşsün.
    inbox.value = [
      for (final n in inbox.value)
        ids == null || ids.contains(n.id)
            ? AppNotification(n.id, n.groupId, n.kind, n.title, n.body, n.at, read: true)
            : n,
    ];
    try {
      await _api.markRead(ids);
    } on ApiException {
      await refreshInbox(_api);
    }
  }

  void _open(AppNotification n) {
    if (!n.read) _read([n.id]);
    if (n.groupId case final g?) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => JoinScreen(groupId: g)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: inbox,
          builder: (context, list, _) => RefreshIndicator(
            onRefresh: () => refreshInbox(_api),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Bildirimler', style: text.headlineSmall)),
                    if (list.any((n) => !n.read))
                      TextButton(onPressed: () => _read(null), child: const Text('Tümünü okundu say')),
                  ],
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 56, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text('Henüz bir şey yok', style: text.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Biri gruba katılınca, sana bir iş verilince, hesaba masraf eklenince ya da arkadaşın '
                          'yola çıkınca burada görürsün.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  for (final n in list)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: n.read ? scheme.surfaceContainerLow : scheme.primaryContainer,
                      child: ListTile(
                        leading: Icon(kindIcon(n.kind), color: n.read ? scheme.onSurfaceVariant : scheme.primary),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                        subtitle: Text('${n.body}\n${ago(n.at)}'),
                        isThreeLine: true,
                        onTap: () => _open(n),
                      ),
                    ),
                const SizedBox(height: 8),
                Text(
                  'Bildirimler 30 gün, gruplar 7 gün saklanır.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

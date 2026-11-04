import 'package:flutter/material.dart';

import '../engine/meeting_engine.dart';
import '../services/history_store.dart';

/// Kaydedilen buluşmalar ve kimin ne kadar fazla yol yaptığı (dönüşümlü adalet).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _store = HistoryStore();
  List<MeetingRecord>? _records;

  @override
  void initState() {
    super.initState();
    _store.load().then((r) => mounted ? setState(() => _records = r) : null);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geçmiş silinsin mi?'),
        content: const Text('Kaydedilen tüm buluşmalar bu cihazdan silinir. Dönüşümlü adalet sıfırdan başlar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.clear();
    if (mounted) setState(() => _records = []);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final records = _records;
    final bal = records == null ? const <String, double>{} : balances(records);
    // Ekranda ismin kullanıcıdaki yazımıyla görünmesi için son kayıttaki hali alınır.
    final display = <String, String>{};
    for (final r in records ?? const <MeetingRecord>[]) {
      for (final n in r.names) {
        display.putIfAbsent(n.trim().toLowerCase(), () => n);
      }
    }
    final people = bal.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final extreme = people.fold(60.0, (m, e) => e.value.abs() > m ? e.value.abs() : m);

    return Scaffold(
      appBar: AppBar(title: const Text('Adalet defteri'), actions: [
        if (records?.isNotEmpty ?? false)
          IconButton(tooltip: 'Geçmişi sil', onPressed: _clear, icon: const Icon(Icons.delete_outline)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Kaydettiğiniz her buluşmada kimin grup ortalamasından ne kadar fazla yol yaptığı birikir. '
            '"Dönüşümlü adalet" açıksa bir sonraki nokta, fazla yol yapanın lehine kayar.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (records == null) const LinearProgressIndicator(),
          if (records != null && records.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Icon(Icons.menu_book_outlined, size: 40, color: scheme.primary),
                  const SizedBox(height: 8),
                  const Text('Henüz kayıtlı buluşma yok.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Bir buluşma noktası bulduktan sonra "Adalet defterine yaz"a dokun.',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              ),
            ),
          if (people.isNotEmpty) ...[
            Text('Kim ne kadar fazla yol yaptı?', style: text.titleSmall),
            const SizedBox(height: 8),
            for (final e in people)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: Text(display[e.key] ?? e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(child: _BalanceBar(value: e.value / extreme)),
                  SizedBox(
                    width: 72,
                    child: Text(
                      e.value.abs() < 60 ? 'dengede' : '${e.value > 0 ? '+' : '−'}${formatDuration(e.value.abs())}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: e.value >= 60 ? scheme.error : (e.value <= -60 ? scheme.primary : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 16),
            Text('Buluşmalar', style: text.titleSmall),
          ],
          for (final r in records ?? const <MeetingRecord>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${r.date.day}.${r.date.month}.${r.date.year} · '
                '${[for (var i = 0; i < r.names.length; i++) '${r.names[i]} ${formatDuration(r.seconds[i])}'].join(', ')}',
              ),
            ),
        ],
      ),
    );
  }
}

/// Ortadan iki yana uzanan çubuk: sağ = fazla yol, sol = az yol.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value.clamp(-1.0, 1.0);
    return SizedBox(
      height: 10,
      child: LayoutBuilder(builder: (context, c) {
        final half = c.maxWidth / 2;
        return Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)),
            ),
          ),
          Positioned(
            left: v >= 0 ? half : half + v * half,
            width: v.abs() * half,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: v >= 0 ? scheme.error : scheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Positioned(left: half - 1, width: 2, top: 0, bottom: 0, child: ColoredBox(color: scheme.outline)),
        ]);
      }),
    );
  }
}

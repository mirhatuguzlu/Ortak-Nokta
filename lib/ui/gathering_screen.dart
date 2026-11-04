import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../engine/gathering.dart';
import '../services/gathering_sync.dart';
import '../services/osm_api.dart';

/// Tek iş: buluşmanın lojistiği. "Ben mangalı alırım, sen kömürü" ve "kim kime ne borçlu".
/// Her değişiklik anında kaydedilir: davet grubundaysa sunucuya (herkes görür), değilse cihaza.
class GatheringScreen extends StatefulWidget {
  const GatheringScreen({super.key, required this.sync});
  final GatheringSync sync;

  @override
  State<GatheringScreen> createState() => _GatheringScreenState();
}

class _GatheringScreenState extends State<GatheringScreen> {
  Gathering get _g => widget.sync.gathering;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.sync.shared) {
      _reload();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _reload());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      await widget.sync.reload();
      if (mounted) setState(() {});
    } on ApiException {
      // geçici ağ hatası: bir sonraki turda tekrar dener
    }
  }

  /// Değişikliği hemen gösterir, sonra kaydeder. Kayıt başarısızsa söyler ve sunucudaki
  /// son hale döner (ortak defterde), böylece ekranda olmayan bir şey "kaydedildi" sanılmaz.
  Future<void> _change(VoidCallback f, Future<void> Function() save) async {
    setState(f);
    try {
      await save();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Kaydedilemedi. Tekrar dene.')));
      await _reload();
    }
  }

  Future<String?> _ask(String title, {String hint = '', String initial = ''}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: hint, counterText: ''),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Tamam')),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final name = (await _ask('Ne lazım?', hint: 'ör. Kömür'))?.trim();
    if (name == null || name.isEmpty) return;
    final item = BringItem(name);
    _change(() => _g.items.add(item), () => widget.sync.addItems([item]));
  }

  Future<void> _template() async {
    final t = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final name in bringTemplates.keys)
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(name),
              subtitle: Text(bringTemplates[name]!.take(4).join(', ')),
              onTap: () => Navigator.pop(context, name),
            ),
        ]),
      ),
    );
    if (t == null) return;
    final have = {for (final i in _g.items) i.name.toLowerCase()};
    final added = [
      for (final n in bringTemplates[t]!)
        if (!have.contains(n.toLowerCase())) BringItem(n),
    ];
    if (added.isEmpty) return;
    _change(() => _g.items.addAll(added), () => widget.sync.addItems(added));
  }

  Future<void> _assign(BringItem item) async {
    final who = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(title: Text('${item.name} kimde?', style: Theme.of(context).textTheme.titleMedium)),
          for (final p in _g.people)
            ListTile(
              leading: Icon(item.who == p ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Text(p),
              onTap: () => Navigator.pop(context, p),
            ),
          ListTile(
            leading: const Icon(Icons.casino_outlined),
            title: const Text('Kura çek'),
            subtitle: const Text('En az şey üstlenmiş olanlardan biri'),
            onTap: () => Navigator.pop(context, _fairPick()),
          ),
          if (item.who != null)
            ListTile(leading: const Icon(Icons.clear), title: const Text('Kimse'), onTap: () => Navigator.pop(context, '')),
        ]),
      ),
    );
    if (who == null) return;
    _change(() => item.who = who.isEmpty ? null : who, () => widget.sync.updateItem(item));
  }

  /// Yük dengeli kura: en az iş üstlenenler arasından rastgele.
  String _fairPick() {
    final load = {for (final p in _g.people) p: _g.items.where((i) => i.who == p).length};
    final least = load.values.reduce((a, b) => a < b ? a : b);
    final pool = [for (final e in load.entries) if (e.value == least) e.key];
    return pool[DateTime.now().microsecond % pool.length];
  }

  Future<void> _addExpense() async {
    final e = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExpenseSheet(people: _g.people),
    );
    if (e != null) _change(() => _g.expenses.add(e), () => widget.sync.addExpense(e));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = _g.items.where((i) => i.who == null).length;
    final transfers = settle(_g.people, _g.expenses, minKurus: 100);
    final total = _g.expenses.fold(0, (a, e) => a + e.kurus);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sync.shared ? 'Ortak buluşma defteri' : 'Buluşma defteri'),
          actions: [
            IconButton(
              tooltip: 'Gruba gönder',
              icon: const Icon(Icons.ios_share),
              onPressed: _g.items.isEmpty && _g.expenses.isEmpty
                  ? null
                  : () => SharePlus.instance.share(ShareParams(text: _g.summary())),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: open == 0 ? 'Kim ne getiriyor' : 'Kim ne getiriyor · $open boşta'),
            const Tab(text: 'Hesap'),
          ]),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
            if (_g.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Liste boş. Bir şablonla başla ya da tek tek ekle; herkes neyi '
                    'üstlendiğini görsün, aynı şeyi iki kişi getirmesin.', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            for (final item in _g.items)
              Dismissible(
                key: ObjectKey(item),
                direction: DismissDirection.endToStart,
                background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: scheme.error)),
                onDismissed: (_) => _change(() => _g.items.remove(item), () => widget.sync.removeItem(item)),
                child: ListTile(
                  leading: Checkbox(value: item.done, onChanged: (v) => _change(() => item.done = v ?? false, () => widget.sync.updateItem(item))),
                  title: Text(item.name,
                      style: TextStyle(decoration: item.done ? TextDecoration.lineThrough : null)),
                  subtitle: Text(item.who ?? 'Kimse almadı',
                      style: TextStyle(color: item.who == null ? scheme.error : scheme.onSurfaceVariant)),
                  trailing: const Icon(Icons.person_add_alt),
                  onTap: () => _assign(item),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: _template, icon: const Icon(Icons.auto_awesome), label: const Text('Şablon')),
              OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Ekle')),
            ]),
          ]),
          ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
            if (_g.expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Kim neyi ödediyse yaz; uygulama en az havaleyle kimin kime ne '
                    'göndereceğini çıkarır. 1 ₺ altı kuruş hesabı yapılmaz.', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            for (final e in _g.expenses)
              Dismissible(
                key: ObjectKey(e),
                direction: DismissDirection.endToStart,
                background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: scheme.error)),
                onDismissed: (_) => _change(() => _g.expenses.remove(e), () => widget.sync.removeExpense(e)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(e.what),
                  subtitle: Text('${e.payer} ödedi · ${e.forWhom.length == _g.people.length ? 'herkes için' : e.forWhom.join(', ')}'),
                  trailing: Text(formatTl(e.kurus), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            if (_g.expenses.isNotEmpty) ...[
              const Divider(),
              ListTile(title: const Text('Toplam'), trailing: Text(formatTl(total))),
              ListTile(
                  title: const Text('Kişi başı (eşit bölünse)'),
                  trailing: Text(formatTl(total ~/ _g.people.length))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Ödeşme', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (transfers.isEmpty) const ListTile(leading: Icon(Icons.celebration_outlined), title: Text('Herkes ödeşti')),
              for (final t in transfers)
                ListTile(
                  leading: Icon(Icons.arrow_forward, color: scheme.primary),
                  title: Text('${t.from} → ${t.to}'),
                  trailing: Text(formatTl(t.kurus), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ]),
        ]),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => DefaultTabController.of(context).index == 0 ? _addItem() : _addExpense(),
            icon: const Icon(Icons.add),
            label: const Text('Ekle'),
          ),
        ),
      ),
    );
  }
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({required this.people});
  final List<String> people;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _what = TextEditingController(), _amount = TextEditingController();
  late String _payer = widget.people.first;
  late final _for = {...widget.people};

  @override
  void dispose() {
    _what.dispose();
    _amount.dispose();
    super.dispose();
  }

  int? get _kurus => parseTl(_amount.text);

  @override
  Widget build(BuildContext context) {
    final ok = _kurus != null && _for.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Masraf ekle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
              controller: _what,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Ne için? (ör. Market)', counterText: '')),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tutar (₺)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Kim ödedi?'),
          Wrap(spacing: 8, children: [
            for (final p in widget.people)
              ChoiceChip(label: Text(p), selected: _payer == p, onSelected: (_) => setState(() => _payer = p)),
          ]),
          const SizedBox(height: 12),
          const Text('Kimler için?'),
          Wrap(spacing: 8, children: [
            for (final p in widget.people)
              FilterChip(
                label: Text(p),
                selected: _for.contains(p),
                onSelected: (v) => setState(() => v ? _for.add(p) : _for.remove(p)),
              ),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ok
                ? () => Navigator.pop(
                    context,
                    Expense(_what.text.trim().isEmpty ? 'Masraf' : _what.text.trim(), _payer, _kurus!,
                        [for (final p in widget.people) if (_for.contains(p)) p]))
                : null,
            child: const Text('Ekle'),
          ),
        ]),
      ),
    );
  }
}

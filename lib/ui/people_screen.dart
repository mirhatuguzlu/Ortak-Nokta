import 'package:flutter/material.dart';

import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import 'location_sheet.dart';
import 'map_parts.dart';
import 'result_screen.dart';
import 'theme.dart';

const maxPeople = 5;

/// Tek iş: kimin nereden ve nasıl geleceğini toplamak.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _api = OsmApi();
  final _history = HistoryStore();
  final _people = [Participant('Sen', personColors[0]), Participant('Arkadaşın', personColors[1])];
  var _mode = FairnessMode.fair;
  var _rotate = true;

  @override
  void initState() {
    super.initState();
    _history.loadPrefs().then((p) {
      if (!mounted) return;
      setState(() {
        _mode = p.$1;
        _rotate = p.$2;
      });
    });
  }

  Future<void> _edit(int i) async {
    final result = await Navigator.push<PersonEdit>(
      context,
      MaterialPageRoute(builder: (_) => PersonScreen(api: _api, person: _people[i], canRemove: _people.length > 2)),
    );
    if (result == null || !mounted) return;
    setState(() => result == PersonEdit.removed ? _people.removeAt(i) : null);
  }

  Future<void> _add() async {
    final p = Participant('Kişi ${_people.length + 1}',
        personColors.firstWhere((c) => _people.every((p) => p.color != c)));
    final result = await Navigator.push<PersonEdit>(
        context, MaterialPageRoute(builder: (_) => PersonScreen(api: _api, person: p, isNew: true)));
    if (result == PersonEdit.saved && mounted) setState(() => _people.add(p));
  }

  Future<void> _fairness() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          void update(VoidCallback f) {
            set(f);
            setState(() {});
            _history.savePrefs(_mode, _rotate);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Sizin için adil ne demek?', style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 8),
                RadioGroup<FairnessMode>(
                  groupValue: _mode,
                  onChanged: (m) => update(() => _mode = m!),
                  child: Column(children: [
                    for (final m in FairnessMode.values)
                      RadioListTile<FairnessMode>(value: m, title: Text(m.label), subtitle: Text(m.hint)),
                  ]),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Dönüşümlü adalet'),
                  subtitle: const Text('Geçmiş buluşmalarda fazla yol yapanın lehine kaydır'),
                  value: _rotate,
                  onChanged: (v) => update(() => _rotate = v),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = _people.where((p) => p.place != null).length;
    final allReady = ready == _people.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Kim nereden geliyor?')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Text('Her kişiye dokun, nereden ve nasıl geleceğini seç.', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        for (var i = 0; i < _people.length; i++) ...[
          _PersonTile(person: _people[i], onTap: () => _edit(i)),
          const SizedBox(height: 10),
        ],
        if (_people.length < maxPeople)
          OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Bir kişi daha')),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.balance, color: scheme.secondary),
          title: const Text('Adalet ayarı'),
          subtitle: Text('${_mode.label} · dönüşümlü adalet ${_rotate ? 'açık' : 'kapalı'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _fairness,
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: allReady
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ResultScreen(people: List.of(_people), mode: _mode, rotate: _rotate)))
                : null,
            child: Text(allReady ? 'Ortak noktayı bul' : '$ready / ${_people.length} kişinin yeri seçildi'),
          ),
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.onTap});
  final Participant person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = person.place;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
                radius: 22, backgroundColor: person.color, child: Icon(person.mode.icon, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(person.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  place?.label ?? 'Nereden geliyor? Seçmek için dokun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: place == null ? scheme.secondary : scheme.onSurfaceVariant),
                ),
              ]),
            ),
            Icon(place == null ? Icons.chevron_right : Icons.check_circle,
                color: place == null ? scheme.onSurfaceVariant : scheme.primary),
          ]),
        ),
      ),
    );
  }
}

enum PersonEdit { saved, removed }

/// Tek iş: bir kişinin adı, başlangıç noktası ve aracı. Değişiklikler "Kaydet"e kadar uygulanmaz.
class PersonScreen extends StatefulWidget {
  const PersonScreen({
    super.key,
    required this.api,
    required this.person,
    this.isNew = false,
    this.canRemove = false,
    this.title,
    this.action,
  });
  final OsmApi api;
  final Participant person;
  final bool isNew;
  final bool canRemove;
  final String? title;
  final String? action;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  late final _name = TextEditingController(text: widget.person.name);
  late Place? _place = widget.person.place;
  late TravelMode _mode = widget.person.mode;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _displayName => _name.text.trim().isEmpty ? widget.person.name : _name.text.trim();

  Future<void> _pickPlace() async {
    var place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocationSheet(api: widget.api, name: _displayName),
    );
    if (!mounted || place == null) return;
    if (identical(place, pickOnMap)) {
      place = await Navigator.push<Place>(context,
          MaterialPageRoute(builder: (_) => MapPickScreen(api: widget.api, name: _displayName, start: _place?.point)));
    }
    if (place != null && mounted) setState(() => _place = place);
  }

  void _save() {
    widget.person
      ..name = _displayName
      ..place = _place
      ..mode = _mode;
    Navigator.pop(context, PersonEdit.saved);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? (widget.isNew ? 'Yeni kişi' : widget.person.name))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        TextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Adı', counterText: ''),
        ),
        const SizedBox(height: 28),
        Text('Nereden çıkacak?', style: text.titleMedium),
        const SizedBox(height: 10),
        Card(
          color: _place == null ? scheme.secondaryContainer : scheme.primaryContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            onTap: _pickPlace,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(_place == null ? Icons.add_location_alt_outlined : Icons.place,
                    color: _place == null ? scheme.secondary : scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_place?.label ?? 'Adres ara, konumunu kullan ya da haritadan seç',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text(_place == null ? 'Seç' : 'Değiştir',
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Nasıl gelecek?', style: text.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final m in TravelMode.values)
            ChoiceChip(
              avatar: Icon(m.icon, size: 18),
              label: Text(m.available ? m.label : '${m.label} · yakında'),
              selected: _mode == m,
              onSelected: m.available ? (_) => setState(() => _mode = m) : null,
            ),
        ]),
        if (widget.canRemove) ...[
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () => Navigator.pop(context, PersonEdit.removed),
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Bu kişiyi çıkar'),
            ),
          ),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _place == null ? null : _save,
            child: Text(_place == null ? 'Önce nereden çıkacağını seç' : (widget.action ?? 'Kaydet')),
          ),
        ),
      ),
    );
  }
}

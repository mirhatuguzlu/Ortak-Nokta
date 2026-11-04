import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/group_api.dart';
import '../services/osm_api.dart';
import 'location_sheet.dart';
import 'theme.dart';



/// Grup üyelerini ekran açıkken birkaç saniyede bir yeniler.
mixin _MemberPolling<T extends StatefulWidget> on State<T> {
  final api = GroupApi();
  List<GroupMember>? members;
  Timer? _timer;

  void startPolling(String id) {
    Future<void> tick() async {
      try {
        final m = await api.members(id);
        if (mounted) setState(() => members = m);
      } on ApiException {
        // Geçici ağ hatası: bir sonraki turda tekrar dener.
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile(this.index, this.member);
  final int index;
  final GroupMember member;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: personColors[index % personColors.length],
          child: Icon(member.mode.icon, color: Colors.white, size: 20),
        ),
        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(member.place.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      );
}

/// Grubu kuran kişinin ekranı: link paylaşılır, katılanlar canlı görünür.
/// "Ortak noktayı bul" ile üyeler ana ekrana döner.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.owner});
  final Participant owner;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> with _MemberPolling {
  String? _id;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final id = await api.create();
      final o = widget.owner;
      await api.join(id, o.name, o.mode, o.place!);
      if (!mounted) return;
      setState(() => _id = id);
      startPolling(id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _inviteText(String id) {
    final link = GroupApi.link(id);
    return link != null
        ? '${widget.owner.name} seni Ortak Nokta\'ya davet etti. Nereden geleceğini ekle, '
            'herkese adil buluşma noktasını bulalım: $link'
        : '${widget.owner.name} seni Ortak Nokta\'ya davet etti. Uygulamada "Davet koduyla katıl"a '
            'bu kodu yapıştır: $id';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final id = _id;
    final m = members ?? const <GroupMember>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşlarını davet et')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_error != null)
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(_error!),
                trailing: TextButton(onPressed: _start, child: const Text('Tekrar dene')),
              ),
            )
          else if (id == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else ...[
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.group_add, size: 40, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text('Linki gruba gönder', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Herkes kendi konumunu ve aracını ekler, sen burada canlı görürsün. '
                    'Kimsenin uygulamayı indirmesi ya da üye olması gerekmez.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(GroupApi.link(id) ?? id, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => SharePlus.instance.share(ShareParams(text: _inviteText(id))),
                        icon: const Icon(Icons.send),
                        label: const Text('Gönder'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: GroupApi.link(id) ?? id));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Kopyala'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('Katılanlar (${m.length}/5)', style: text.titleSmall),
              const Spacer(),
              const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('bekleniyor', style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
            for (var i = 0; i < m.length; i++) _MemberTile(i, m[i]),
            const SizedBox(height: 8),
            Text('Davet 24 saat geçerlidir; sonra konumlar sunucudan silinir.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: m.length >= 2 ? () => Navigator.pop(context, m) : null,
            icon: const Icon(Icons.join_inner),
            label: Text(m.length >= 2 ? '${m.length} kişiyle ortak noktayı bul' : 'En az bir kişinin katılması bekleniyor'),
          ),
        ),
      ),
    );
  }
}

/// Davet linkini açan kişinin ekranı (sitedeki karşılığı: site/src/Join.jsx).
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> with _MemberPolling {
  final _osm = OsmApi();
  final _name = TextEditingController();
  TravelMode _mode = TravelMode.walk;
  Place? _place;
  bool _busy = false;
  bool _joined = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    startPolling(widget.groupId);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    final p = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocationSheet(
          api: _osm, name: _name.text.trim().isEmpty ? 'Sen' : _name.text.trim(), allowMapPick: false),
    );
    if (p != null && mounted) setState(() => _place = p);
  }

  Future<void> _join() async {
    final name = _name.text.trim();
    if (name.isEmpty || _place == null) {
      setState(() => _error = name.isEmpty ? 'Adını yaz.' : 'Nereden geleceğini seç.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.join(widget.groupId, name, _mode, _place!);
      if (mounted) setState(() => _joined = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final m = members ?? const <GroupMember>[];
    final host = m.isEmpty ? null : m.first.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Ortak Nokta daveti')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              if (_joined)
                Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.check_circle, size: 56, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text('Gruba katıldın!', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        '${host ?? 'Grubu kuran kişi'} herkes katılınca ortak noktayı bulup grupla paylaşacak.',
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                )
              else ...[
                Text(host == null ? 'Bir buluşmaya davet edildin' : '$host seni bir buluşmaya davet etti',
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Nereden ve nasıl geleceğini ekle; Ortak Nokta herkesin yol süresine göre adil buluşma noktasını bulsun.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Adın', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 4),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(_place?.label ?? 'Nereden geleceksin?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _place == null ? TextStyle(color: scheme.primary) : null),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _pickPlace,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Nasıl geleceksin?', style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final mode in TravelMode.values.where((m) => m.available))
                    ChoiceChip(
                      avatar: Icon(mode.icon, size: 18),
                      label: Text(mode.label),
                      selected: _mode == mode,
                      onSelected: _busy ? null : (_) => setState(() => _mode = mode),
                    ),
                ]),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _join,
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.how_to_reg),
                  label: const Text('Gruba katıl'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Konumun yalnızca bu gruptakilerle ortak noktayı hesaplamak için kullanılır ve 24 saat içinde silinir.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (m.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Grupta (${m.length}/5)', style: text.titleSmall),
                for (var i = 0; i < m.length; i++) _MemberTile(i, m[i]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

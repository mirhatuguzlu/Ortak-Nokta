import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engine/gathering.dart';
import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/gathering_sync.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import '../services/planner.dart';
import 'gathering_screen.dart';
import 'map_parts.dart';
import 'share_card.dart';

/// Tek iş: buluşma yerini ve kimin kaçta çıkacağını göstermek.
/// Mekan seçimi ayrı sayfadadır (VenuesScreen); seçilen mekana göre süreler burada yenilenir.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.people, required this.mode, required this.rotate, this.shared});
  final List<Participant> people;
  final FairnessMode mode;
  final bool rotate;

  /// Davet grubunun ortak defteri; null ise defter yalnızca bu cihazda.
  final GatheringSync? shared;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _api = OsmApi();
  final _history = HistoryStore();
  Plan? _plan;

  /// Mekan seçilse de mekan listesi adil noktanın çevresine göre kalsın.
  LatLng? _fairPoint;
  String? _step = 'Hazırlanıyor…';
  String? _error;
  bool _saved = false;

  /// Kullanıcının seçtiği varış saati; null = otomatik (en uzaktaki şimdi çıkar).
  DateTime? _arrival;
  Weather? _weather;
  late GatheringSync _sync =
      widget.shared ?? LocalGathering(Gathering(_gatheringKey, [for (final p in _people) p.name]), _history);
  Gathering get _gathering => _sync.gathering;

  List<Participant> get _people => widget.people;

  /// Aynı kişilerle açılan buluşma aynı defteri (liste, hesap, tam yer) görür.
  String get _gatheringKey => ([for (final p in _people) p.name.trim().toLowerCase()]..sort()).join('|');

  @override
  void initState() {
    super.initState();
    _find();
    if (widget.shared != null) {
      _sync.reload().then((_) => mounted ? setState(() {}) : null, onError: (_) {});
      return;
    }
    _history.loadGathering(_gatheringKey).then((g) {
      if (g != null && mounted) setState(() => _sync = LocalGathering(g, _history));
    });
  }

  /// Hava kötüyse mekan listesi kapalı yerleri öne alır. Tahmin alınamazsa sessizce geçilir.
  Future<void> _loadWeather() async {
    final p = _fairPoint;
    if (p == null) return;
    try {
      final w = await _api.weather(p, _effectiveArrival);
      if (mounted) setState(() => _weather = w);
    } on ApiException {
      // hava bilgisi süs; ana akışı bozmasın
    }
  }

  Future<void> _editSpot() async {
    final c = TextEditingController(text: _gathering.spot);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tam olarak nerede?'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'ör. Metro çıkışı, saat kulesinin altı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Kaydet')),
        ],
      ),
    );
    if (v == null || !mounted) return;
    setState(() => _gathering.spot = v.trim());
    try {
      await _sync.setSpot(_gathering.spot);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openGathering() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GatheringScreen(sync: _sync)));
    if (mounted) setState(() {});
  }

  String _gatheringLabel() {
    final open = _gathering.items.where((i) => i.who == null).length;
    if (_gathering.items.isEmpty && _gathering.expenses.isEmpty) return 'Liste & hesap';
    return open > 0 ? '$open şey boşta' : 'Liste & hesap ✓';
  }

  /// "Neredesin?" sorusunu bitiren hazır mesajlar: kişinin kendi süresine göre varış saati.
  /// Davet grubunda "sen" bellidir ve mesaj gruptaki herkese bildirim olarak da gider.
  Future<void> _onMyWay() async {
    final plan = _plan!;
    final group = _sync is SharedGathering ? _sync as SharedGathering : null;
    final mine = group?.members.indexWhere((m) => m.isMe) ?? -1;
    final i = mine >= 0 ? mine : await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Kim için?')),
          for (var k = 0; k < _people.length; k++)
            ListTile(
              leading: CircleAvatar(backgroundColor: _people[k].color, child: Icon(_people[k].mode.icon, color: Colors.white)),
              title: Text(_people[k].name),
              onTap: () => Navigator.pop(context, k),
            ),
        ]),
      ),
    );
    if (i == null || !mounted) return;
    final eta = DateTime.now().add(Duration(seconds: plan.result.legs[i].seconds.ceil()));
    final late = eta.difference(_effectiveArrival).inMinutes;
    final where = plan.label.split(',').first;
    final spot = _gathering.spot;
    final messages = [
      ('🚶 Çıktım! ${formatClock(eta)} gibi oradayım ($where).', 'on_way', (plan.result.legs[i].seconds / 60).ceil()),
      if (late > 0) ('⏱️ Kusura bakmayın, ~$late dk gecikeceğim (${formatClock(eta)}).', 'late', late),
      ('📍 Geldim. ${spot.isEmpty ? where : spot}', 'arrived', 0),
      ('🔎 Neredesiniz? Ben ${spot.isEmpty ? 'buluşma noktasındayım' : spot}.', 'arrived', 0),
    ];
    final msg = await showModalBottomSheet<(String, String, int)>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final m in messages)
            ListTile(
                title: Text(m.$1),
                trailing: Icon(group == null ? Icons.send : Icons.notifications_active_outlined),
                onTap: () => Navigator.pop(context, m)),
        ]),
      ),
    );
    if (msg == null || !mounted) return;
    if (group != null) {
      try {
        await group.api.ping(group.groupId, msg.$2, msg.$3);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Gruba haber verildi'),
          action: SnackBarAction(
              label: 'Mesaj olarak da at', onPressed: () => SharePlus.instance.share(ShareParams(text: msg.$1))),
        ));
        return;
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    await SharePlus.instance.share(ShareParams(text: msg.$1));
  }

  DateTime get _effectiveArrival => _arrival ?? suggestedArrival(DateTime.now(), _plan?.result.maxSeconds ?? 0);

  /// `venue` null: adil noktayı ara; değilse süreleri o mekana göre yeniden hesapla.
  Future<void> _find({Venue? venue}) async {
    setState(() {
      _step = 'Hazırlanıyor…';
      _error = null;
    });
    try {
      final names = [for (final p in _people) p.name];
      final weights = widget.rotate ? fairnessWeights(names, balances(await _history.load())) : null;
      final plan = await planMeeting(_api, _people,
          mode: widget.mode,
          weights: weights,
          at: _arrival,
          venue: venue,
          onStep: (s) => mounted ? setState(() => _step = s) : null);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        if (venue == null) _fairPoint = plan.result.point;
        _saved = false;
      });
      if (venue == null) _loadWeather();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Beklenmeyen bir hata oluştu. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  Future<void> _pickArrival() async {
    final now = DateTime.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_effectiveArrival),
      helpText: 'Herkes kaçta orada olsun?',
      cancelText: 'Otomatik',
    );
    if (!mounted) return;
    if (t == null) return setState(() => _arrival = null);
    var at = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1)); // geçmiş saat = yarın
    setState(() => _arrival = at);
    // Araçla gelen varsa trafik tahmini saate bağlı: süreleri o saate göre yenile.
    if (_people.any((p) => p.mode == TravelMode.car)) {
      _find(venue: _plan?.venue);
    } else {
      _loadWeather();
    }
  }

  Future<void> _chooseVenue() async {
    final v = await Navigator.push<Venue>(
      context,
      MaterialPageRoute(builder: (_) => VenuesScreen(
              api: _api, center: _fairPoint!, selected: _plan!.venue, preferIndoor: _weather?.stayInside ?? false)),
    );
    if (v != null && mounted) _find(venue: identical(v, backToFairPoint) ? null : v);
  }

  Future<void> _save() async {
    final plan = _plan!;
    await _history.add(MeetingRecord(
        DateTime.now(), plan.label, [for (final p in _people) p.name], [for (final l in plan.result.legs) l.seconds]));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.rotate
          ? 'Deftere yazıldı. Bir dahaki sefere fazla yol yapanın lehine hesaplanacak.'
          : 'Deftere yazıldı.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) return _Waiting(step: _step, error: _error, onRetry: _find);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final busy = _step != null;
    final arrival = _effectiveArrival;
    final legs = plan.result.legs;
    final leave = departures(arrival, legs, buffersOf(_people));
    return Scaffold(
      body: Column(children: [
        SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.38,
          child: Stack(children: [
            _RouteMap(key: ObjectKey(plan), plan: plan, people: _people),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconButton.filledTonal(
                    tooltip: 'Geri',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  const Attribution(),
                ]),
              ),
            ),
          ]),
        ),
        if (busy) const LinearProgressIndicator(minHeight: 3) else const SizedBox(height: 3),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
              ),
            Text(plan.venue?.kind.label ?? 'Adil buluşma noktası',
                style: text.labelLarge?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(plan.label, style: text.headlineSmall),
            const SizedBox(height: 16),
            _ArrivalChip(arrival: arrival, isAuto: _arrival == null, onTap: busy ? null : _pickArrival),
            if (_weather case final w?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(w.stayInside ? Icons.umbrella : Icons.wb_sunny_outlined, size: 20, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${w.summary}${w.stayInside ? ' · kapalı mekan önerilir' : ''}',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                ]),
              ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.push_pin_outlined, color: scheme.secondary),
              title: Text(_gathering.spot.isEmpty ? 'Tam olarak nerede buluşuyorsunuz?' : _gathering.spot),
              subtitle: _gathering.spot.isEmpty ? const Text('"Neredesin?" mesajlarını bitirir') : null,
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editSpot,
            ),
            for (var i = 0; i < _people.length; i++)
              _PersonRow(
                person: _people[i],
                leg: legs[i],
                share: plan.result.maxSeconds == 0 ? 1 : legs[i].seconds / plan.result.maxSeconds,
                leaveAt: leave[i],
                buffer: _people[i].lateBuffer,
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : () => showShareSheet(context, plan, _people, arrival, spot: _gathering.spot),
              icon: const Icon(Icons.ios_share),
              label: const Text('Gruba gönder'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _chooseVenue,
                  icon: const Icon(Icons.local_cafe_outlined),
                  label: const Text('Mekan seç'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(mapsLink(plan)), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Yol tarifi'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openGathering,
                  icon: const Icon(Icons.checklist),
                  label: Text(_gatheringLabel()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _onMyWay,
                  icon: const Icon(Icons.near_me_outlined),
                  label: const Text('Yoldayım'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Icon(Icons.lightbulb_outline, color: scheme.tertiary),
                title: const Text('Neden burası?'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final r in plan.reasons)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 10),
                          child: CircleAvatar(radius: 3, backgroundColor: scheme.secondary),
                        ),
                        Expanded(child: Text(r)),
                      ]),
                    ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _saved || busy ? null : _save,
              icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(_saved ? 'Deftere yazıldı' : 'Adalet defterine yaz'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.step, required this.error, required this.onRetry});
  final String? step;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (error == null) ...[
              const SizedBox.square(dimension: 40, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: 24),
              Text(step ?? '', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Herkesin gerçek yol süresine bakıyoruz, birkaç saniye sürebilir.',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ] else ...[
              Icon(Icons.wrong_location_outlined, size: 48, color: scheme.secondary),
              const SizedBox(height: 16),
              Text(error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kişilere dön')),
            ],
          ]),
        ),
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({super.key, required this.plan, required this.people});
  final Plan plan;
  final List<Participant> people;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = widget.plan;
    final people = widget.people;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: plan.result.point,
        initialZoom: 13,
        onMapReady: () => _map.fitCamera(CameraFit.coordinates(
          coordinates: [plan.result.point, for (final p in people) p.place!.point],
          padding: const EdgeInsets.fromLTRB(40, 80, 40, 32),
          maxZoom: 16,
        )),
      ),
      children: [
        osmTiles,
        PolylineLayer(polylines: [
          for (var i = 0; i < people.length; i++)
            Polyline(
                points: plan.routes[i],
                color: people[i].color,
                strokeWidth: 5,
                borderColor: Colors.white,
                borderStrokeWidth: 2),
        ]),
        MarkerLayer(markers: [
          for (final p in people)
            Marker(
              point: p.place!.point,
              width: 36,
              height: 36,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: CircleAvatar(backgroundColor: p.color, child: Icon(p.mode.icon, color: Colors.white, size: 18)),
              ),
            ),
          Marker(
            point: plan.result.point,
            width: 52,
            height: 52,
            alignment: Alignment.topCenter,
            child: Icon(plan.venue == null ? Icons.location_on : Icons.local_cafe,
                size: 48, color: scheme.onSurface, shadows: const [Shadow(blurRadius: 8, color: Colors.black26)]),
          ),
        ]),
      ],
    );
  }
}

class _ArrivalChip extends StatelessWidget {
  const _ArrivalChip({required this.arrival, required this.isAuto, required this.onTap});
  final DateTime arrival;
  final bool isAuto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(Icons.schedule, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Buluşma '),
                TextSpan(text: formatClock(arrival), style: const TextStyle(fontWeight: FontWeight.w800)),
                if (isAuto) TextSpan(text: '\nen uzaktaki şimdi çıkarsa', style: TextStyle(color: scheme.onSurfaceVariant)),
              ])),
            ),
            const Text('Saati değiştir', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(
      {required this.person, required this.leg, required this.share, required this.leaveAt, this.buffer = 0});
  final Participant person;
  final Leg leg;
  final double share;
  final DateTime leaveAt;
  final int buffer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: person.color, child: Icon(person.mode.icon, size: 18, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(person.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(formatDuration(leg.seconds), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.04, 1),
                minHeight: 6,
                color: person.color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('${person.mode.label} · ${formatDistance(leg.meters)}',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              Text('çıkış ${formatClock(leaveAt)}${buffer > 0 ? ' (+$buffer dk pay)' : ''}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// VenuesScreen'den "adil noktaya dön" seçimi.
const backToFairPoint = Venue('', VenueKind.park, LatLng(0, 0), 0);

/// Tek iş: adil noktanın çevresinden oturulacak bir yer seçmek.
class VenuesScreen extends StatefulWidget {
  const VenuesScreen(
      {super.key, required this.api, required this.center, this.selected, this.preferIndoor = false});
  final OsmApi api;
  final LatLng center;
  final Venue? selected;

  /// Yağmur/soğuk bekleniyorsa kapalı mekanlar öne alınır.
  final bool preferIndoor;

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  List<Venue>? _venues;
  String? _error;
  final _need = <VenueFeature>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _venues = null;
      _error = null;
    });
    try {
      final v = await widget.api.nearby(widget.center);
      if (mounted) setState(() => _venues = v);
    } on ApiException {
      if (mounted) setState(() => _error = 'Yakındaki mekanlar şu an yüklenemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = _venues == null
        ? null
        : ([
            for (final x in _venues!)
              if (_need.every(x.features.contains)) x
          ]..sort((a, b) => widget.preferIndoor && a.kind.indoor != b.kind.indoor
              ? (a.kind.indoor ? -1 : 1)
              : a.meters.compareTo(b.meters)));
    final selected = widget.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Yakında nerede oturulur?')),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text('Birini seç, süreler o mekana göre yeniden hesaplansın.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        if (widget.preferIndoor)
          ListTile(
            leading: Icon(Icons.umbrella, color: scheme.secondary),
            title: const Text('Hava kötü görünüyor; kapalı mekanlar önde.'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final f in VenueFeature.values)
              FilterChip(
                avatar: Icon(f.icon, size: 16),
                label: Text(f.label),
                selected: _need.contains(f),
                onSelected: (on) => setState(() => on ? _need.add(f) : _need.remove(f)),
              ),
          ]),
        ),
        if (selected != null)
          ListTile(
            leading: Icon(Icons.undo, color: scheme.primary),
            title: const Text('Adil noktanın kendisine dön'),
            onTap: () => Navigator.pop(context, backToFairPoint),
          ),
        if (_error != null)
          ListTile(title: Text(_error!), trailing: TextButton(onPressed: _load, child: const Text('Tekrar dene'))),
        if (v == null && _error == null) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (v != null && v.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Bu noktanın yakınında bu özelliklere uyan kayıtlı mekan yok.'),
          ),
        for (final venue in v ?? const <Venue>[])
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            selected: selected?.point == venue.point,
            selectedTileColor: scheme.primaryContainer,
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(venue.kind.icon, color: scheme.secondary, size: 20),
            ),
            title: Text(venue.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              '${venue.kind.label} · adil noktaya ${formatDistance(venue.meters)}',
              if (venue.features.isNotEmpty) venue.features.map((f) => f.label).join(' · '),
              if (venue.hours != null) '🕒 ${venue.hours}',
            ].join('\n')),
            isThreeLine: venue.features.isNotEmpty || venue.hours != null,
            onTap: selected?.point == venue.point ? null : () => Navigator.pop(context, venue),
          ),
      ]),
    );
  }
}

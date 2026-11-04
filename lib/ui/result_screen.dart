import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import '../services/planner.dart';
import 'map_parts.dart';
import 'share_card.dart';

/// Tek iş: buluşma yerini ve kimin kaçta çıkacağını göstermek.
/// Mekan seçimi ayrı sayfadadır (VenuesScreen); seçilen mekana göre süreler burada yenilenir.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.people, required this.mode, required this.rotate});
  final List<Participant> people;
  final FairnessMode mode;
  final bool rotate;

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

  List<Participant> get _people => widget.people;

  @override
  void initState() {
    super.initState();
    _find();
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
    if (_people.any((p) => p.mode == TravelMode.car)) _find(venue: _plan?.venue);
  }

  Future<void> _chooseVenue() async {
    final v = await Navigator.push<Venue>(
      context,
      MaterialPageRoute(builder: (_) => VenuesScreen(api: _api, center: _fairPoint!, selected: _plan!.venue)),
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
    final leave = departures(arrival, legs);
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
            const SizedBox(height: 12),
            for (var i = 0; i < _people.length; i++)
              _PersonRow(
                person: _people[i],
                leg: legs[i],
                share: plan.result.maxSeconds == 0 ? 1 : legs[i].seconds / plan.result.maxSeconds,
                leaveAt: leave[i],
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : () => showShareSheet(context, plan, _people, arrival),
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
  const _PersonRow({required this.person, required this.leg, required this.share, required this.leaveAt});
  final Participant person;
  final Leg leg;
  final double share;
  final DateTime leaveAt;

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
              Text('çıkış ${formatClock(leaveAt)}', style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
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
  const VenuesScreen({super.key, required this.api, required this.center, this.selected});
  final OsmApi api;
  final LatLng center;
  final Venue? selected;

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  List<Venue>? _venues;
  String? _error;

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
    final v = _venues;
    final selected = widget.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Yakında nerede oturulur?')),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text('Birini seç, süreler o mekana göre yeniden hesaplansın.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
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
            child: Text('Bu noktanın yakınında kayıtlı kafe, restoran veya park yok.'),
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
            subtitle: Text('${venue.kind.label} · adil noktaya ${formatDistance(venue.meters)}'),
            onTap: selected?.point == venue.point ? null : () => Navigator.pop(context, venue),
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../engine/meeting_engine.dart';
import '../models.dart';
import '../services/group_api.dart';
import '../services/history_store.dart';
import '../services/osm_api.dart';
import '../services/planner.dart';
import 'group_screens.dart';
import 'history_sheet.dart';
import 'location_sheet.dart';
import 'result_view.dart';
import 'share_card.dart';

const _colors = [Colors.indigo, Colors.deepOrange, Colors.purple, Colors.teal, Colors.brown];
const _maxPeople = 5;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = OsmApi();
  final _history = HistoryStore();
  final _map = MapController();
  var _people = [Participant('Sen', _colors[0]), Participant('Arkadaşın', _colors[1])];
  Plan? _plan;
  String? _busy;
  int? _pickingFor;
  var _mode = FairnessMode.fair;
  var _rotate = true;

  /// Kullanıcının seçtiği varış saati; null = otomatik (en uzaktaki şimdi çıkar).
  DateTime? _arrival;
  bool _saved = false;

  /// Adil noktanın çevresindeki mekanlar (mekan seçilince değişmez).
  List<Venue>? _venues;
  String? _venuesError;
  Venue? _venueRequest;

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

  void _changed(VoidCallback f) => setState(() {
        f();
        _plan = null;
        _venues = null;
        _venuesError = null;
      });

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));

  DateTime get _effectiveArrival =>
      _arrival ?? suggestedArrival(DateTime.now(), _plan?.result.maxSeconds ?? 0);

  Future<void> _chooseLocation(int i) async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocationSheet(api: _api, name: _people[i].name),
    );
    if (place == null || !mounted) return;
    if (identical(place, pickOnMap)) {
      setState(() => _pickingFor = i);
      return;
    }
    _changed(() => _people[i].place = place);
    _map.move(place.point, 14);
  }

  Future<void> _onMapTap(LatLng p) async {
    final i = _pickingFor;
    if (i == null) return;
    _changed(() {
      _people[i].place = Place('Haritadan seçildi', p);
      _pickingFor = null;
    });
    final label = await _api.reverse(p).catchError((_) => null);
    if (label != null && mounted && _people[i].place?.point == p) {
      setState(() => _people[i].place = Place(label, p));
    }
  }

  /// `venue` null: adil noktayı ara; değilse süreleri o mekana göre yeniden hesapla.
  Future<void> _find({Venue? venue}) async {
    final missing = _people.where((p) => p.place == null).map((p) => p.name).toList();
    if (missing.isNotEmpty) return _snack('${missing.join(', ')} için başlangıç konumu seç.');
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = 'Hazırlanıyor…';
      _venueRequest = venue;
    });
    try {
      final names = [for (final p in _people) p.name];
      final weights = _rotate ? fairnessWeights(names, balances(await _history.load())) : null;
      final plan = await planMeeting(_api, _people,
          mode: _mode,
          weights: weights,
          at: _arrival,
          venue: venue,
          onStep: (s) => mounted ? setState(() => _busy = s) : null);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _saved = false;
      });
      _map.fitCamera(CameraFit.coordinates(
        coordinates: [plan.result.point, for (final p in _people) p.place!.point],
        padding: EdgeInsets.fromLTRB(48, 96, 48, MediaQuery.sizeOf(context).height * 0.5),
        maxZoom: 16,
      ));
      if (venue == null) _loadVenues(plan.result.point);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Beklenmeyen bir hata oluştu. Tekrar dene.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _venueRequest = null;
        });
      }
    }
  }

  Future<void> _loadVenues(LatLng p) async {
    setState(() {
      _venues = null;
      _venuesError = null;
    });
    try {
      final v = await _api.nearby(p);
      if (mounted && _plan?.result.point == p) setState(() => _venues = v);
    } on ApiException {
      if (mounted) setState(() => _venuesError = 'Yakındaki mekanlar şu an yüklenemedi.');
    }
  }

  Future<void> _pickArrival() async {
    final now = DateTime.now();
    final current = _effectiveArrival;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Herkes kaçta orada olsun?',
      cancelText: 'Otomatik',
    );
    if (!mounted) return;
    if (t == null) {
      setState(() => _arrival = null);
      return;
    }
    var at = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1)); // geçmiş saat = yarın
    setState(() => _arrival = at);
    // Araçla gelen varsa trafik tahmini saate bağlı: süreleri o saate göre yenile.
    if (_plan != null && _people.any((p) => p.mode == TravelMode.car)) _find(venue: _plan!.venue);
  }

  Future<void> _save() async {
    final plan = _plan!;
    await _history.add(MeetingRecord(DateTime.now(), plan.label, [for (final p in _people) p.name],
        [for (final l in plan.result.legs) l.seconds]));
    if (!mounted) return;
    setState(() => _saved = true);
    _snack(_rotate
        ? 'Kaydedildi. Bir sonraki buluşmada fazla yol yapanın lehine hesaplanacak.'
        : 'Kaydedildi.');
  }

  Future<void> _invite() async {
    if (!GroupApi.configured) {
      return _snack('Davet linkleri yakında. (Geliştirici: SUPABASE_URL ve SUPABASE_ANON_KEY tanımlanmalı.)');
    }
    final me = _people.first;
    if (me.place == null) {
      _snack('Önce kendi başlangıç konumunu seç; arkadaşların kendi konumlarını linkten ekleyecek.');
      return _chooseLocation(0);
    }
    final members = await Navigator.push<List<GroupMember>>(
        context, MaterialPageRoute(builder: (_) => InviteScreen(owner: me)));
    if (members == null || !mounted) return;
    _changed(() {
      _people = [
        for (var i = 0; i < members.length && i < _maxPeople; i++)
          Participant(members[i].name, _colors[i])
            ..place = members[i].place
            ..mode = members[i].mode,
      ];
    });
    _find();
  }

  Future<void> _joinWithCode() async {
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
              onPressed: () => Navigator.pop(context, GroupApi.parseId(controller.text) ?? ''),
              child: const Text('Devam')),
        ],
      ),
    );
    controller.dispose();
    if (id == null || !mounted) return;
    if (id.isEmpty) return _snack('Geçerli bir davet linki veya kodu bulunamadı.');
    Navigator.push(context, MaterialPageRoute(builder: (_) => JoinScreen(groupId: id)));
  }

  Future<void> _directions() =>
      launchUrl(Uri.parse(mapsLink(_plan!)), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(41.0151, 28.9795),
            initialZoom: 11,
            onTap: (_, p) => _onMapTap(p),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              tileProvider: NetworkTileProvider(headers: {'User-Agent': appUserAgent}),
            ),
            if (plan != null)
              PolylineLayer(polylines: [
                for (var i = 0; i < _people.length; i++)
                  Polyline(
                    points: plan.routes[i],
                    color: _people[i].color,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
              ]),
            MarkerLayer(markers: [
              if (plan != null)
                for (final v in _venues ?? const <Venue>[])
                  if (v.point != plan.result.point)
                    Marker(
                      point: v.point,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: _busy == null ? () => _find(venue: v) : null,
                        child: Tooltip(
                          message: v.name,
                          child: CircleAvatar(
                            backgroundColor: scheme.secondaryContainer,
                            child: Icon(v.kind.icon, size: 16, color: scheme.onSecondaryContainer),
                          ),
                        ),
                      ),
                    ),
              for (final p in _people)
                if (p.place != null)
                  Marker(
                    point: p.place!.point,
                    width: 40,
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                      ),
                      child: CircleAvatar(
                        backgroundColor: p.color,
                        child: Icon(p.mode.icon, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              if (plan != null)
                Marker(
                  point: plan.result.point,
                  width: 52,
                  height: 52,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on,
                      size: 52, color: scheme.primary, shadows: const [Shadow(blurRadius: 8, color: Colors.black38)]),
                ),
            ]),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.topRight, child: _Attribution()),
              if (_pickingFor != null)
                Card(
                  color: scheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: Text('${_people[_pickingFor!].name} için haritada bir yere dokun'),
                    trailing: IconButton(
                      tooltip: 'Vazgeç',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _pickingFor = null),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        if (_pickingFor == null)
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.18,
            maxChildSize: 0.94,
            builder: (context, scroll) => Material(
              elevation: 8,
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Ortak Nokta',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Ortada değil, adil buluşun.', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Adalet defteri',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => HistorySheet(store: _history),
                      ),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<VoidCallback>(
                      tooltip: 'Davet',
                      icon: const Icon(Icons.group_add_outlined),
                      onSelected: (f) => f(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: _invite,
                          child: const ListTile(
                              leading: Icon(Icons.link), title: Text('Arkadaşlarını linkle davet et')),
                        ),
                        PopupMenuItem(
                          value: _joinWithCode,
                          child: const ListTile(leading: Icon(Icons.login), title: Text('Davet koduyla katıl')),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _people.length; i++) _personCard(i),
                  if (_people.length < _maxPeople)
                    Row(children: [
                      TextButton.icon(
                        onPressed: _busy != null
                            ? null
                            : () => _changed(() => _people.add(Participant('Kişi ${_people.length + 1}',
                                _colors.firstWhere((c) => _people.every((p) => p.color != c))))),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Kişi ekle'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _busy != null ? null : _invite,
                        icon: const Icon(Icons.link),
                        label: const Text('Linkle davet et'),
                      ),
                    ]),
                  const SizedBox(height: 8),
                  _options(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    onPressed: _busy == null ? () => _find() : null,
                    icon: _busy == null || _venueRequest != null
                        ? const Icon(Icons.join_inner)
                        : const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    label: Text(_busy != null && _venueRequest == null ? _busy! : 'Ortak noktayı bul'),
                  ),
                  if (_busy != null && _venueRequest != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${_venueRequest!.name} için süreler hesaplanıyor…', textAlign: TextAlign.center),
                    ),
                  if (plan != null)
                    ResultView(
                      plan: plan,
                      people: _people,
                      arrival: _effectiveArrival,
                      arrivalIsAuto: _arrival == null,
                      saved: _saved,
                      venues: _venues,
                      venuesError: _venuesError,
                      busy: _busy != null,
                      onShare: () => showShareSheet(context, plan, _people, _effectiveArrival),
                      onDirections: _directions,
                      onSave: _save,
                      onPickArrival: _pickArrival,
                      onVenue: (v) => _find(venue: v),
                      onRetryVenues: () => _loadVenues(plan.result.point),
                    ),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _options() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<FairnessMode>(
            showSelectedIcon: false,
            segments: [
              for (final m in FairnessMode.values) ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_mode},
            onSelectionChanged: _busy != null
                ? null
                : (s) {
                    _changed(() => _mode = s.single);
                    _history.savePrefs(_mode, _rotate);
                  },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_mode.hint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Dönüşümlü adalet'),
            subtitle: const Text('Geçmişte fazla yol yapanın lehine'),
            value: _rotate,
            onChanged: _busy != null
                ? null
                : (v) {
                    _changed(() => _rotate = v);
                    _history.savePrefs(_mode, _rotate);
                  },
          ),
        ]),
      ),
    );
  }

  Widget _personCard(int i) {
    final p = _people[i];
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ObjectKey(p),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: p.color, child: Icon(p.mode.icon, size: 16, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: p.name,
                maxLength: 30,
                decoration: const InputDecoration(isDense: true, counterText: '', border: InputBorder.none),
                style: Theme.of(context).textTheme.titleMedium,
                onChanged: (v) => p.name = v.trim().isEmpty ? 'Kişi ${i + 1}' : v.trim(),
              ),
            ),
            if (_people.length > 2)
              IconButton(
                tooltip: 'Kişiyi çıkar',
                icon: const Icon(Icons.close),
                onPressed: _busy != null ? null : () => _changed(() => _people.removeAt(i)),
              ),
          ]),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(p.place?.label ?? 'Başlangıç konumu seç',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: p.place == null ? TextStyle(color: scheme.primary) : null),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy != null ? null : () => _chooseLocation(i),
          ),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final m in TravelMode.values)
              ChoiceChip(
                avatar: Icon(m.icon, size: 18),
                label: Text(m.available ? m.label : '${m.label} · Yakında'),
                selected: p.mode == m,
                onSelected: _busy != null
                    ? null
                    : (_) => m.available
                        ? _changed(() => p.mode = m)
                        : _snack('${m.label} desteği yakında eklenecek. Şimdilik yürüyüş veya araç seç.'),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// OSM politikası: atıf görünür olmalı, menü arkasına saklanamaz.
class _Attribution extends StatelessWidget {
  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
          onPressed: () => _open('https://www.openstreetmap.org/copyright'),
          child: const Text('© OpenStreetMap katkıcıları', style: TextStyle(fontSize: 11)),
        ),
        IconButton(
          tooltip: 'Hakkında',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.info_outline, size: 18),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Hakkında ve gizlilik'),
              content: const Text(
                'Harita verisi © OpenStreetMap katkıcıları, ODbL lisansı ile.\n'
                'Rotalar: OSRM (FOSSGIS sunucusu). Adres arama: Nominatim. Mekanlar: Overpass API.\n\n'
                'Konumların yalnızca rota hesaplamak için bu servislere gönderilir. Davet linki '
                'kullanırsan grup konumları 24 saat sonra sunucudan silinir. Kaydettiğin buluşmalar '
                'yalnızca bu cihazda tutulur.',
              ),
              actions: [
                TextButton(
                    onPressed: () => _open('https://www.openstreetmap.org/fixthemap'),
                    child: const Text('Haritayı düzelt')),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

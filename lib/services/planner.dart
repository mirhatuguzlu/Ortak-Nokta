import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../engine/meeting_engine.dart';
import '../models.dart';
import 'osm_api.dart';

class Plan {
  const Plan(this.result, this.label, this.routes, this.reasons, {this.venue});
  final MeetingResult result;
  final String label;
  final List<List<LatLng>> routes;
  final List<String> reasons;

  /// Kullanıcı yakındaki bir mekanı seçtiyse o mekan; adil noktanın kendisiyse null.
  final Venue? venue;
}

/// Herkesin kendi aracıyla gerçek yol süresini hesaplayıp adil buluşma noktasını bulur.
/// `venue` verilirse aday aramaz, süreleri o mekana göre hesaplar. `at`: trafik
/// tahmini için yolculuk zamanı. `weights`: dönüşümlü adalet çarpanları.
Future<Plan> planMeeting(OsmApi api, List<Participant> people,
    {FairnessMode mode = FairnessMode.fair,
    List<double>? weights,
    DateTime? at,
    Venue? venue,
    void Function(String step)? onStep}) async {
  final points = [for (final p in people) p.place!.point];
  var candidates = venue == null ? candidateGrid(points) : [venue.point];
  final legs = List<List<Leg?>>.filled(people.length, const []);

  // Aynı araçla gelenler tek istekte hesaplanır.
  final groups = <String, List<int>>{};
  for (var i = 0; i < people.length; i++) {
    final url = people[i].mode.osrmUrl;
    if (url == null) throw ApiException('${people[i].mode.label} desteği yakında eklenecek.');
    groups.putIfAbsent(url, () => []).add(i);
  }
  final traffic = trafficFactor(at ?? DateTime.now());
  List<LatLng?>? snapped;
  for (final MapEntry(key: url, value: idx) in groups.entries) {
    onStep?.call('Yol süreleri hesaplanıyor…');
    final t = await api.table(url, [for (final i in idx) points[i]], candidates);
    final f = url == osrmCarUrl ? traffic : 1.0;
    for (var k = 0; k < idx.length; k++) {
      legs[idx[k]] = [for (final l in t.rows[k]) l == null ? null : Leg(l.seconds * f, l.meters)];
    }
    snapped ??= t.snapped;
  }
  // Marker yol üzerinde dursun diye adayı ilk grubun yola yapışmış konumuyla değiştir
  // (mekan seçildiyse mekanın kendi konumu kalır).
  if (venue == null) {
    candidates = [for (var c = 0; c < candidates.length; c++) snapped![c] ?? candidates[c]];
  }

  final best = pickBest(candidates, legs, mode: mode, weights: weights);
  if (best == null) {
    throw ApiException(venue == null
        ? 'Bu konumlar için herkesin ulaşabildiği bir nokta bulunamadı.'
        : '${venue.name} için herkesin kullanabileceği bir yol bulunamadı.');
  }
  onStep?.call('Rotalar çiziliyor…');
  final routes = [
    for (var i = 0; i < people.length; i++)
      await api.route(people[i].mode.osrmUrl!, points[i], best.point),
  ];
  final String label;
  if (venue != null) {
    label = venue.name;
  } else {
    onStep?.call('Adres bulunuyor…');
    label = await api.reverse(best.point).catchError((_) => null) ?? 'Buluşma noktası';
  }
  final names = [for (final p in people) p.name];
  return Plan(
      best,
      label,
      routes,
      [
        if (venue != null) '${venue.kind.label} seçtiniz; süreler bu mekana göre.',
        ...reasons(best, names, mode: mode, compareCenter: venue == null),
        if (weights != null && venue == null && weights.any((w) => (w - 1).abs() > 0.02))
          'Dönüşümlü adalet: geçmiş buluşmalarda daha çok yol yapan '
              '${names[_argMax(weights)]} lehine ayarlandı.',
        if (groups.containsKey(osrmCarUrl))
          'Araç süreleri ${at == null ? 'şu saatin' : 'yolculuk saatinin'} tahmini trafiğine göre '
              '×${traffic.toStringAsFixed(2)} artırıldı (canlı trafik değil).',
      ],
      venue: venue);
}

int _argMax(List<double> xs) {
  var best = 0;
  for (var i = 1; i < xs.length; i++) {
    if (xs[i] > xs[best]) best = i;
  }
  return best;
}

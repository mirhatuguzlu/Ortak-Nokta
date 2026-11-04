import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ortak_nokta/engine/meeting_engine.dart';

void main() {
  const a = LatLng(41.00, 29.00), b = LatLng(41.02, 29.04);

  test('ızgara 7x7 ve ortası ağırlık merkezi', () {
    final g = candidateGrid([a, b]);
    expect(g.length, gridSize * gridSize);
    expect(g[g.length ~/ 2].latitude, closeTo(41.01, 1e-9));
    expect(g[g.length ~/ 2].longitude, closeTo(29.02, 1e-9));
  });

  test('trafik katsayısı: hafta içi zirve > gündüz > gece', () {
    final rush = trafficFactor(DateTime(2026, 11, 2, 8)); // pazartesi
    final day = trafficFactor(DateTime(2026, 11, 2, 13));
    final night = trafficFactor(DateTime(2026, 11, 2, 2));
    expect(rush > day && day > night && night > 1, isTrue);
    expect(trafficFactor(DateTime(2026, 11, 1, 8)), day); // pazar sabahı zirve yok
  });

  test('aynı noktadaki kişiler için ızgara çökmez', () {
    final g = candidateGrid([a, a]);
    expect(g.first.latitude, lessThan(g.last.latitude));
  });

  test('en uzun yolculuğu en aza indireni seçer, ulaşılamayanı eler', () {
    final c = [a, b, const LatLng(41.01, 29.02)];
    final legs = [
      [const Leg(60, 100), null, const Leg(600, 1000)], // aday 1'e kişi 0 ulaşamıyor
      [const Leg(3000, 5000), const Leg(60, 100), const Leg(660, 1100)],
    ];
    final r = pickBest(c, legs)!;
    expect(r.index, 2); // aday 0: max 50 dk, aday 2: max 11 dk
    expect(r.maxSeconds, 660);
    expect(r.gapSeconds, 60);
  });

  test('eşit dakikada toplam süresi kısa olan kazanır', () {
    final legs = [
      [const Leg(600, 0), const Leg(300, 0)],
      [const Leg(610, 0), const Leg(600, 0)],
    ];
    expect(pickBest([a, b], legs)!.index, 1);
  });

  test('kimse ortak noktaya ulaşamıyorsa null', () {
    expect(pickBest([a], [[null], [const Leg(1, 1)]]), isNull);
  });

  test('gerekçeler kuş uçumu karşılaştırmasını içerir', () {
    final r = MeetingResult(0, a, const [Leg(600, 1), Leg(900, 1)], const [Leg(300, 1), Leg(1800, 1)]);
    final text = reasons(r, ['Ali', 'Ayşe']).join(' ');
    expect(text, contains('15 dk'));
    expect(text, contains('30 dk'));
    expect(text, contains('fark 5 dk'));
  });

  test('modlar farklı adayı seçebilir', () {
    // aday 0: 10+40 dk (toplam en kısa), aday 1: 30+30 dk (en uzun en kısa, eşit)
    final legs = [
      [const Leg(600, 0), const Leg(1800, 0)],
      [const Leg(2400, 0), const Leg(1800, 0)],
    ];
    expect(pickBest([a, b], legs, mode: FairnessMode.fair)!.index, 1);
    expect(pickBest([a, b], legs, mode: FairnessMode.fast)!.index, 0);
    expect(pickBest([a, b], legs, mode: FairnessMode.equal)!.index, 1);
  });

  test('ağırlık, fazla yol yapmış kişinin lehine seçtirir', () {
    final legs = [
      [const Leg(1200, 0), const Leg(1500, 0)], // kişi 0
      [const Leg(1500, 0), const Leg(1200, 0)], // kişi 1
    ];
    expect(pickBest([a, b], legs, weights: [1.2, 0.8])!.index, 0);
    expect(pickBest([a, b], legs, weights: [0.8, 1.2])!.index, 1);
  });

  test('çıkış saatleri herkesi aynı anda getirir, dakikaya aşağı yuvarlanır', () {
    final at = DateTime(2026, 11, 4, 19, 15);
    final d = departures(at, const [Leg(1500, 0), Leg(610, 0)]);
    expect(formatClock(d[0]), '18:50');
    expect(formatClock(d[1]), '19:04'); // 10 dk 10 sn önce = 19:04:50 → 19:04
    expect(suggestedArrival(DateTime(2026, 11, 4, 18, 31), 1500), DateTime(2026, 11, 4, 19, 0));
  });

  test('defter: fazla yol yapanın bakiyesi pozitif, çarpanı büyük', () {
    final recs = [
      MeetingRecord(DateTime(2026), 'x', const ['Ali', 'Ayşe'], const [3000, 1200]),
      MeetingRecord(DateTime(2026), 'y', const ['ali ', 'Can'], const [2400, 2400]),
    ];
    final bal = balances(recs);
    expect(bal['ali'], 900); // 3000-2100 + 0
    expect(bal['ayşe'], -900);
    final w = fairnessWeights(['Ali', 'Ayşe'], bal);
    expect(w[0], greaterThan(1));
    expect(w[1], lessThan(1));
    expect(MeetingRecord.fromJson(recs[0].toJson()).seconds, recs[0].seconds);
  });

  test('biçimlendirme', () {
    expect(formatDuration(3720), '1 sa 2 dk');
    expect(formatDistance(1530), '1.5 km');
    expect(formatDistance(420), '420 m');
  });

  test('ince ızgara kaba ızgaranın bir adımı içinde kalır', () {
    final coarse = candidateGrid([a, b]);
    final best = coarse[10];
    final fine = refineGrid(coarse, best);
    expect(fine.length, 25);
    expect(fine[12].latitude, closeTo(best.latitude, 1e-9));
    final step = coarse[gridSize].latitude - coarse[0].latitude;
    expect(fine.last.latitude - fine.first.latitude, closeTo(2 * step, 1e-9));
  });

  test('geç kalma payı çıkış saatini erkene çeker', () {
    final at = DateTime(2026, 11, 4, 19, 0);
    final d = departures(at, const [Leg(600, 0), Leg(600, 0)], [0, 10]);
    expect(formatClock(d[0]), '18:50');
    expect(formatClock(d[1]), '18:40');
  });
}

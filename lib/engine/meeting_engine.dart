import 'dart:math';

import 'package:latlong2/latlong.dart';

class Leg {
  const Leg(this.seconds, this.meters);
  final double seconds;
  final double meters;
}

/// "Adil" kelimesinin hangi anlamda kullanılacağı.
enum FairnessMode {
  fair('En adil', 'En uzun yolculuğu kısaltır'),
  fast('En hızlı', 'Toplam yolu kısaltır'),
  equal('Eşit süre', 'Süre farkını kapatır');

  const FairnessMode(this.label, this.hint);
  final String label;
  final String hint;
}

const gridSize = 7;

/// Kişilerin ağırlık merkezi etrafında kare bir aday ızgarası üretir.
/// Orta eleman (index `length ~/ 2`) tam ağırlık merkezidir = "kuş uçumu orta nokta".
List<LatLng> candidateGrid(List<LatLng> people) {
  final lat = people.map((p) => p.latitude).reduce((a, b) => a + b) / people.length;
  final lon = people.map((p) => p.longitude).reduce((a, b) => a + b) / people.length;
  final k = cos(lat * pi / 180); // boylam derecesi kuzeye gidildikçe kısalır
  var r = 0.005; // ~550 m: aynı yerdeki kişiler için de anlamlı ızgara
  for (final p in people) {
    final dLat = p.latitude - lat, dLon = (p.longitude - lon) * k;
    r = max(r, sqrt(dLat * dLat + dLon * dLon));
  }
  return [
    for (var i = 0; i < gridSize; i++)
      for (var j = 0; j < gridSize; j++)
        LatLng(
          (lat + r * (2 * i / (gridSize - 1) - 1)).clamp(-89.9, 89.9),
          (lon + r * (2 * j / (gridSize - 1) - 1) / k).clamp(-180.0, 180.0),
        ),
  ];
}

class MeetingResult {
  const MeetingResult(this.index, this.point, this.legs, this.centerLegs);
  final int index;
  final LatLng point;
  final List<Leg> legs;

  /// Kuş uçumu orta noktadaki süreler; oraya yol yoksa (deniz, park) null.
  final List<Leg>? centerLegs;

  double get maxSeconds => legs.map((l) => l.seconds).reduce(max);
  double get gapSeconds => maxSeconds - legs.map((l) => l.seconds).reduce(min);
}

/// Bir sonucun seçilen moda göre "maliyeti" (saniye).
double metric(FairnessMode mode, List<Leg> legs) {
  final s = legs.map((l) => l.seconds);
  return switch (mode) {
    FairnessMode.fair => s.reduce(max),
    FairnessMode.fast => s.fold(0.0, (a, b) => a + b),
    FairnessMode.equal => s.reduce(max) - s.reduce(min),
  };
}

/// legs[kişi][aday]. Moda göre en iyi adayı seçer (dakikaya yuvarlanmış; eşitlikte
/// ikincil ölçüt). `weights`: kişi başı çarpan, dönüşümlü adalet için (>1 = lehine).
/// Herkesin ulaşamadığı adaylar elenir.
MeetingResult? pickBest(List<LatLng> candidates, List<List<Leg?>> legs,
    {FairnessMode mode = FairnessMode.fair, List<double>? weights}) {
  List<Leg>? at(int c) {
    final row = [for (final p in legs) p[c]];
    return row.contains(null) ? null : row.cast<Leg>();
  }

  int? best;
  var bestKey = (0, 0.0);
  for (var c = 0; c < candidates.length; c++) {
    final row = at(c);
    if (row == null) continue;
    final w = [for (var i = 0; i < row.length; i++) Leg(row[i].seconds * (weights?[i] ?? 1), 0)];
    final m = (metric(mode, w) / 60).round();
    final tie = mode == FairnessMode.fair ? metric(FairnessMode.fast, w) : metric(FairnessMode.fair, w);
    if (best == null || m < bestKey.$1 || (m == bestKey.$1 && tie < bestKey.$2)) {
      best = c;
      bestKey = (m, tie);
    }
  }
  if (best == null) return null;
  return MeetingResult(best, candidates[best], at(best)!, at(candidates.length ~/ 2));
}

String formatDuration(double seconds) {
  final m = (seconds / 60).round();
  return m < 60 ? '$m dk' : '${m ~/ 60} sa ${m % 60} dk';
}

String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Kimse beklemesin diye herkesin `arrival` anında varması için çıkış saatleri
/// (dakikaya aşağı yuvarlanır: geç kalmaktansa bir dakika erken).
List<DateTime> departures(DateTime arrival, List<Leg> legs) => [
      for (final l in legs)
        _floorMinute(arrival.subtract(Duration(seconds: l.seconds.ceil()))),
    ];

/// Varış saati seçilmediyse: en uzaktaki kişi şimdi çıkar, varış 5 dakikaya yukarı yuvarlanır.
DateTime suggestedArrival(DateTime now, double maxSeconds) {
  const step = 5 * 60 * 1000;
  final ms = now.add(Duration(seconds: maxSeconds.ceil())).millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch((ms + step - 1) ~/ step * step);
}

DateTime _floorMinute(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// OSRM boş yol hızıyla hesaplar (trafik, ışık, kavşak beklemesi yok). Araç
/// sürelerini saate göre bu katsayıyla çarparız.
/// shortcut: sabit tahmin, canlı trafik değil; gerçek veri için TomTom/HERE/Google gibi
/// ücretli bir trafik API'sine geç.
double trafficFactor(DateTime t) {
  final weekday = t.weekday <= DateTime.friday;
  final h = t.hour;
  if (h >= 23 || h < 6) return 1.15;
  if (weekday && ((h >= 7 && h < 10) || (h >= 17 && h < 20))) return 1.8;
  return 1.4;
}

const _metricName = {
  FairnessMode.fair: 'en uzun yolculuk',
  FairnessMode.fast: 'toplam yolculuk',
  FairnessMode.equal: 'süre farkı',
};

/// Kullanıcıya gösterilen "neden burası?" açıklamaları. `compareCenter` false ise
/// (kullanıcı mekanı kendisi seçtiyse) kuş uçumu karşılaştırması yapılmaz.
List<String> reasons(MeetingResult r, List<String> names,
    {FairnessMode mode = FairnessMode.fair, bool compareCenter = true}) {
  final out = <String>[
    switch (mode) {
      FairnessMode.fair => 'En uzun yolculuk ${formatDuration(r.maxSeconds)}: gerçek yol ağına göre, '
          'herkesin ulaşabildiği noktalar arasında en kısa olanı bu.',
      FairnessMode.fast => 'Toplam yolculuk ${formatDuration(metric(mode, r.legs))}: herkesin '
          'süreleri toplandığında en kısa nokta bu.',
      FairnessMode.equal => 'Süreleriniz birbirine en yakın nokta bu; en uzun yolculuk '
          '${formatDuration(r.maxSeconds)}.',
    },
  ];
  if (names.length > 1) {
    out.add(r.gapSeconds < 60
        ? 'Yolculuk süreleriniz neredeyse eşit.'
        : 'En hızlı ve en yavaş gelen arasındaki fark ${formatDuration(r.gapSeconds)}.');
  }
  if (!compareCenter) return out;
  final c = r.centerLegs;
  if (c == null) {
    out.add('Kuş uçumu orta noktaya yol yok (deniz, park vb.); '
        'bu yüzden yol ağına göre başka bir nokta seçildi.');
  } else {
    final center = metric(mode, c);
    final saved = center - metric(mode, r.legs);
    out.add(saved >= 60
        ? 'Kuş uçumu orta noktada buluşsaydınız ${_metricName[mode]} '
            '${formatDuration(center)} olacaktı; burası ${formatDuration(saved)} daha '
            '${mode == FairnessMode.fair ? 'adil' : 'iyi'}.'
        : 'Kuş uçumu orta nokta da benzer süre veriyor; bu nokta ona çok yakın.');
  }
  return out;
}

/// Onaylanmış bir buluşma: dönüşümlü adaletin hafızası.
class MeetingRecord {
  const MeetingRecord(this.date, this.label, this.names, this.seconds);
  final DateTime date;
  final String label;
  final List<String> names;
  final List<double> seconds;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'label': label, 'names': names, 'seconds': seconds};

  factory MeetingRecord.fromJson(Map<String, dynamic> j) {
    final names = [for (final n in j['names'] as List) n as String];
    final seconds = [for (final s in j['seconds'] as List) (s as num).toDouble()];
    if (names.length != seconds.length || names.isEmpty) throw const FormatException();
    return MeetingRecord(DateTime.parse(j['date'] as String), j['label'] as String, names, seconds);
  }
}

String _key(String name) => name.trim().toLowerCase();

/// İsim → geçmiş buluşmalarda o buluşmanın ortalamasından fazla yapılan yol (sn).
/// Pozitif = bu kişi şimdiye kadar fazla yol yaptı.
Map<String, double> balances(Iterable<MeetingRecord> records) {
  final out = <String, double>{};
  for (final r in records) {
    final avg = r.seconds.reduce((a, b) => a + b) / r.seconds.length;
    for (var i = 0; i < r.names.length; i++) {
      out.update(_key(r.names[i]), (v) => v + r.seconds[i] - avg, ifAbsent: () => r.seconds[i] - avg);
    }
  }
  return out;
}

/// Bu gruptaki kişiler için çarpanlar: grup içinde fazla yol yapmış olanın süresi
/// daha ağır sayılır, böylece nokta ona yaklaşır. Etki ±%25 ile sınırlı.
List<double> fairnessWeights(List<String> names, Map<String, double> balance) {
  final b = [for (final n in names) balance[_key(n)] ?? 0.0];
  final mean = b.reduce((a, c) => a + c) / b.length;
  return [for (final x in b) 1 + ((x - mean) / 3600).clamp(-0.25, 0.25)];
}

double balanceOf(Map<String, double> balance, String name) => balance[_key(name)] ?? 0;

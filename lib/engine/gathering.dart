/// Buluşmanın "lojistiği": kim ne getiriyor ve kim kime ne kadar borçlu.
/// Saf Dart; UI ve depolama bağımsız.
library;

class BringItem {
  BringItem(this.name, {this.who, this.done = false});
  String name;

  /// Üstlenen kişinin adı; null = henüz kimse almadı.
  String? who;
  bool done;

  Map<String, dynamic> toJson() => {'name': name, 'who': who, 'done': done};
  factory BringItem.fromJson(Map<String, dynamic> j) =>
      BringItem(j['name'] as String, who: j['who'] as String?, done: j['done'] == true);
}

class Expense {
  Expense(this.what, this.payer, this.kurus, this.forWhom);
  final String what;
  final String payer;

  /// Tutar kuruş cinsinden: kayan nokta yuvarlama hatası olmasın.
  final int kurus;

  /// Masrafı paylaşanlar (ödeyen dahil olabilir).
  final List<String> forWhom;

  Map<String, dynamic> toJson() => {'what': what, 'payer': payer, 'kurus': kurus, 'for': forWhom};
  factory Expense.fromJson(Map<String, dynamic> j) {
    final e = Expense(j['what'] as String, j['payer'] as String, (j['kurus'] as num).toInt(),
        [for (final x in j['for'] as List) x as String]);
    if (e.kurus <= 0 || e.forWhom.isEmpty) throw const FormatException();
    return e;
  }
}

class Transfer {
  const Transfer(this.from, this.to, this.kurus);
  final String from, to;
  final int kurus;
}

/// Kişi → net bakiye (kuruş). Pozitif = alacaklı.
Map<String, int> netBalances(List<String> people, List<Expense> expenses) {
  final net = {for (final p in people) p: 0};
  for (final e in expenses) {
    net[e.payer] = (net[e.payer] ?? 0) + e.kurus;
    final share = e.kurus ~/ e.forWhom.length;
    var rest = e.kurus - share * e.forWhom.length; // bölünemeyen kuruşlar ilk kişilere
    for (final p in e.forWhom) {
      final extra = rest > 0 ? 1 : 0;
      rest -= extra;
      net[p] = (net[p] ?? 0) - share - extra;
    }
  }
  return net;
}

/// En az sayıda havaleyle hesabı kapatır: en çok borçlu, en çok alacaklıya öder.
/// `minKurus` altındaki havaleler atlanır (anketlerde çoğu kişi küçük tutar istemeyi ayıp buluyor).
List<Transfer> settle(List<String> people, List<Expense> expenses, {int minKurus = 0}) {
  final net = netBalances(people, expenses);
  final debt = [for (final e in net.entries) if (e.value < 0) [e.key, -e.value]];
  final credit = [for (final e in net.entries) if (e.value > 0) [e.key, e.value]];
  int amount(List x) => x[1] as int;
  final out = <Transfer>[];
  while (debt.isNotEmpty && credit.isNotEmpty) {
    debt.sort((a, b) => amount(b) - amount(a));
    credit.sort((a, b) => amount(b) - amount(a));
    final d = debt.first, c = credit.first;
    final x = amount(d) < amount(c) ? amount(d) : amount(c);
    if (x >= minKurus) out.add(Transfer(d[0] as String, c[0] as String, x));
    d[1] = amount(d) - x;
    c[1] = amount(c) - x;
    if (amount(d) == 0) debt.removeAt(0);
    if (amount(c) == 0) credit.removeAt(0);
  }
  return out;
}

String formatTl(int kurus) {
  final tl = kurus ~/ 100, k = kurus % 100;
  return k == 0 ? '$tl ₺' : '$tl,${k.toString().padLeft(2, '0')} ₺';
}

/// "120,50" / "120.5" / "120" → kuruş. Geçersizse null.
int? parseTl(String s) {
  final m = RegExp(r'^\s*(\d{1,7})(?:[.,](\d{1,2}))?\s*(?:₺|tl|TL)?\s*$').firstMatch(s);
  if (m == null) return null;
  final k = (m.group(2) ?? '0').padRight(2, '0');
  final v = int.parse(m.group(1)!) * 100 + int.parse(k);
  return v == 0 ? null : v;
}

/// Hazır listeler: "ne getirelim" tartışmasını başlatan şablonlar.
const bringTemplates = {
  'Piknik': ['Mangal', 'Kömür', 'Et / tavuk', 'Ekmek', 'Salata malzemesi', 'İçecek', 'Buz', 'Örtü', 'Çöp poşeti', 'Islak mendil'],
  'Ev oturması': ['Atıştırmalık', 'İçecek', 'Tatlı', 'Oyun (kart/kutu)', 'Buz'],
  'Maç izleme': ['Çekirdek', 'Cips', 'İçecek', 'Pizza siparişi', 'Forma / atkı'],
  'Doğum günü': ['Pasta', 'Mum', 'Hediye (ortak)', 'Balon', 'Kart'],
  'Kamp': ['Çadır', 'Uyku tulumu', 'Kamp ocağı', 'Fener', 'İlk yardım', 'Su', 'Çakı'],
};

/// Bir buluşmanın lojistik defteri; buluşma etiketiyle saklanır.
class Gathering {
  Gathering(this.key, this.people, {List<BringItem>? items, List<Expense>? expenses, this.spot = ''})
      : items = items ?? [],
        expenses = expenses ?? [];
  final String key;
  final List<String> people;
  final List<BringItem> items;
  final List<Expense> expenses;

  /// "Tam olarak nerede?": giriş kapısı, saat kulesinin altı vb.
  String spot;

  Map<String, dynamic> toJson() => {
        'key': key,
        'people': people,
        'items': [for (final i in items) i.toJson()],
        'expenses': [for (final e in expenses) e.toJson()],
        'spot': spot,
      };

  factory Gathering.fromJson(Map<String, dynamic> j) => Gathering(
        j['key'] as String,
        [for (final p in j['people'] as List) p as String],
        items: [for (final i in j['items'] as List) BringItem.fromJson(i as Map<String, dynamic>)],
        expenses: [for (final e in j['expenses'] as List) Expense.fromJson(e as Map<String, dynamic>)],
        spot: j['spot'] as String? ?? '',
      );

  /// WhatsApp grubuna yapıştırılacak özet.
  String summary() {
    final lines = <String>[];
    if (spot.trim().isNotEmpty) lines.add('📌 Tam yer: ${spot.trim()}');
    if (items.isNotEmpty) {
      lines.add('🧺 Kim ne getiriyor');
      for (final i in items) {
        lines.add('${i.done ? '✅' : '▫️'} ${i.name}: ${i.who ?? 'kimse almadı!'}');
      }
    }
    final t = settle(people, expenses, minKurus: 100);
    if (expenses.isNotEmpty) {
      final total = expenses.fold(0, (a, e) => a + e.kurus);
      lines.add('💸 Hesap (toplam ${formatTl(total)})');
      lines.addAll(t.isEmpty ? ['Herkes ödeşti 🎉'] : [for (final x in t) '${x.from} → ${x.to}: ${formatTl(x.kurus)}']);
    }
    return lines.join('\n');
  }
}

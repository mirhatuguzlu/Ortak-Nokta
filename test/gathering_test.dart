import 'package:flutter_test/flutter_test.dart';
import 'package:ortak_nokta/engine/gathering.dart';

void main() {
  const people = ['Ali', 'Ayşe', 'Can'];

  test('hesap: en az havaleyle ödeşilir, toplam korunur', () {
    final ex = [
      Expense('Market', 'Ali', 30000, people), // 300 ₺, kişi başı 100
      Expense('Kahve', 'Ayşe', 6000, ['Ayşe', 'Can']), // 60 ₺, kişi başı 30
    ];
    final net = netBalances(people, ex);
    expect(net.values.fold(0, (a, b) => a + b), 0);
    expect(net, {'Ali': 20000, 'Ayşe': -7000, 'Can': -13000});
    final t = settle(people, ex);
    expect(t.length, 2);
    expect(t.every((x) => x.to == 'Ali'), isTrue);
    expect(t.fold(0, (a, x) => a + x.kurus), 20000);
  });

  test('bölünemeyen kuruş kaybolmaz, küçük havale atlanabilir', () {
    final ex = [Expense('x', 'Ali', 100, people)]; // 1 ₺ / 3
    expect(netBalances(people, ex).values.fold(0, (a, b) => a + b), 0);
    expect(settle(people, ex, minKurus: 100), isEmpty);
  });

  test('tutar ayrıştırma', () {
    expect(parseTl('120,50'), 12050);
    expect(parseTl('120.5'), 12050);
    expect(parseTl('85 TL'), 8500);
    expect(parseTl('0'), isNull);
    expect(parseTl('abc'), isNull);
    expect(formatTl(12050), '120,50 ₺');
    expect(formatTl(8500), '85 ₺');
  });

  test('defter JSON gidiş-dönüş ve özet', () {
    final g = Gathering('ali|ayşe', ['Ali', 'Ayşe'],
        items: [BringItem('Kömür', who: 'Ali'), BringItem('Ekmek')],
        expenses: [Expense('Et', 'Ayşe', 40000, ['Ali', 'Ayşe'])],
        spot: 'Ana kapı');
    final back = Gathering.fromJson(g.toJson());
    expect(back.items[0].who, 'Ali');
    expect(back.items[1].who, isNull);
    expect(back.spot, 'Ana kapı');
    final text = back.summary();
    expect(text, contains('Ekmek: kimse almadı'));
    expect(text, contains('Ali → Ayşe: 200 ₺'));
  });
}

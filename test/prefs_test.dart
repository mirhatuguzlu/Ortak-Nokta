import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ortak_nokta/models.dart';
import 'package:ortak_nokta/services/prefs.dart';
import 'package:ortak_nokta/ui/inbox_screen.dart';

void main() {
  test('tercihler sunucu biçimine gidip geri gelir', () {
    final p = Prefs(
      mode: TravelMode.car,
      home: const Place('Moda', LatLng(40.98, 29.02)),
      late: true,
      off: {NotifyKind.items},
    );
    final j = p.toJson();
    // Sunucu yalnızca notify.<tür> = false olana telefon bildirimi göndermez.
    expect(j['notify'], {'group': true, 'items': false, 'money': true, 'live': true, 'reminder': true});
    final back = Prefs.fromJson(j);
    expect(back.mode, TravelMode.car);
    expect(back.home?.label, 'Moda');
    expect(back.late, isTrue);
    expect(back.off, {NotifyKind.items});
    expect(back.copyWith(home: () => null).home, isNull);
  });

  test('bozuk ya da eski tercih kaydı varsayılana döner', () {
    final p = Prefs.fromJson({'mode': 'bus', 'home': {'label': 'x', 'lat': 200, 'lon': 0}, 'notify': 'x'});
    expect(p.mode, TravelMode.walk); // otobüs henüz yok
    expect(p.home, isNull);
    expect(p.off, isEmpty);
    expect(Prefs.fromJson(null).mode, TravelMode.walk);
  });

  test('kısa zaman metni', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(ago(now.subtract(const Duration(seconds: 20)), now), 'şimdi');
    expect(ago(now.subtract(const Duration(minutes: 3)), now), '3 dk önce');
    expect(ago(now.subtract(const Duration(hours: 5)), now), '5 sa önce');
    expect(ago(DateTime(2026, 10, 1), now), '1.10.2026');
  });
}

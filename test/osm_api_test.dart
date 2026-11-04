import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ortak_nokta/config.dart';
import 'package:ortak_nokta/services/osm_api.dart';

void main() {
  const p = LatLng(41, 29);

  test('table: yola uzak hedef null olur, User-Agent gönderilir', () async {
    late http.Request sent;
    final api = OsmApi(client: MockClient((req) async {
      sent = req;
      return http.Response(
          jsonEncode({
            'code': 'Ok',
            'durations': [[120, 50]],
            'distances': [[900, 400]],
            'destinations': [
              {'distance': 10, 'location': [29.001, 41.001]},
              {'distance': 900, 'location': [29.1, 41.1]},
            ],
          }),
          200);
    }));
    final t = await api.table(osrmFootUrl, [p], [p, p]);
    expect(sent.headers['User-Agent'], appUserAgent);
    expect(sent.url.queryParameters['sources'], '0');
    expect(sent.url.queryParameters['destinations'], '1;2');
    expect(t.rows[0][0]!.seconds, 120);
    expect(t.rows[0][1], isNull);
    expect(t.snapped[0]!.latitude, 41.001);
  });

  test('araç: yola uzak hedefe park edip yürüme süresi eklenir', () async {
    final api = OsmApi(client: MockClient((_) async => http.Response(
        jsonEncode({
          'code': 'Ok',
          'durations': [[120, 50]],
          'distances': [[900, 400]],
          'destinations': [
            {'distance': 13, 'location': [29.001, 41.001]},
            {'distance': 650, 'location': [29.1, 41.1]},
          ],
        }),
        200)));
    final t = await api.table(osrmCarUrl, [p], [p, p], walkLastMeters: 700);
    expect(t.rows[0][0]!.seconds, 130); // 13 m / 1.3 m/sn
    expect(t.rows[0][1]!.seconds, 550);
    expect(t.rows[0][1]!.meters, 1050);
    expect(t.snapped[1], isNull); // marker yine yürüyüş ağına göre konur
  });

  test('hava: buluşma saatinin tahmini okunur', () async {
    final api = OsmApi(client: MockClient((_) async => http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2026-11-04T18:00', '2026-11-04T19:00'],
            'precipitation_probability': [10, 70],
            'temperature_2m': [14.2, 12.6],
          },
        }),
        200)));
    final w = await api.weather(p, DateTime(2026, 11, 4, 19, 30));
    expect(w!.rainChance, 70);
    expect(w.stayInside, isTrue);
    expect(await api.weather(p, DateTime(2026, 11, 9, 9)), isNull);
  });

  test('bozuk veya kötü niyetli yanıt kullanıcı dostu hataya döner', () async {
    final api = OsmApi(client: MockClient((_) async => http.Response('{"code":"Ok","routes":"x"}', 200)));
    expect(api.route(osrmCarUrl, p, p), throwsA(isA<ApiException>()));
  });

  test('geçersiz koordinat reddedilir', () async {
    final api = OsmApi(client: MockClient((_) async => http.Response(
        jsonEncode([{'lat': '999', 'lon': '29', 'display_name': 'x'}]), 200)));
    expect(api.search('kadıköy'), throwsA(isA<ApiException>()));
  });

  test('http adresi engellenir, istek gönderilmez', () async {
    var called = false;
    final api = OsmApi(client: MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    }));
    await expectLater(api.route('http://evil.example', p, p), throwsA(isA<ApiException>()));
    expect(called, isFalse);
  });

  test('arama kısa sorguda istek atmaz, sonucu önbelleğe alır', () async {
    var calls = 0;
    final api = OsmApi(client: MockClient((_) async {
      calls++;
      return http.Response.bytes(
          utf8.encode(jsonEncode(
              [{'lat': '40.99', 'lon': '29.03', 'name': 'Moda', 'display_name': 'Moda, Kadıköy, İstanbul'}])),
          200);
    }));
    expect(await api.search('ab'), isEmpty);
    final r = await api.search('Moda');
    await api.search('moda ');
    expect(calls, 1);
    expect(r.single.label, 'Moda, Kadıköy, İstanbul');
  });

  test('nearby: isimsiz ve tanınmayan yerleri atar, yakından uzağa sıralar', () async {
    final api = OsmApi(client: MockClient((req) async {
      expect(req.url.queryParameters['data'], contains('around:450,41.000000,29.000000'));
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'elements': [
              {'type': 'node', 'lat': 41.003, 'lon': 29, 'tags': {'amenity': 'cafe', 'name': 'Uzak Kafe'}},
              {'type': 'way', 'center': {'lat': 41.001, 'lon': 29}, 'tags': {'leisure': 'park', 'name': 'Park'}},
              {'type': 'node', 'lat': 41.001, 'lon': 29, 'tags': {'amenity': 'cafe'}},
              {'type': 'node', 'lat': 41.001, 'lon': 29, 'tags': {'amenity': 'bank', 'name': 'Banka'}},
            ],
          })),
          200);
    }));
    final v = await api.nearby(p);
    expect(v.map((x) => x.name), ['Park', 'Uzak Kafe']);
    expect(v.first.meters, closeTo(111, 2));
  });

  test('nearby: ana sunucu 502 verirse yedek sunucuyu dener', () async {
    final hosts = <String>[];
    final api = OsmApi(client: MockClient((req) async {
      hosts.add(req.url.host);
      return hosts.length == 1 ? http.Response('', 502) : http.Response('{"elements":[]}', 200);
    }));
    expect(await api.nearby(p), isEmpty);
    expect(hosts, [Uri.parse(overpassUrl).host, Uri.parse(overpassFallbackUrl).host]);
  });

  test('429 hatası anlaşılır mesaj verir', () async {
    final api = OsmApi(client: MockClient((_) async => http.Response('', 429)));
    expect(api.reverse(p), throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('Çok fazla'))));
  });
}

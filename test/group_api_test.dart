import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ortak_nokta/engine/gathering.dart';
import 'package:ortak_nokta/main.dart';
import 'package:ortak_nokta/services/gathering_sync.dart';
import 'package:ortak_nokta/services/group_api.dart';
import 'package:ortak_nokta/services/osm_api.dart';

void main() {
  const id = '3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90';

  test('davet kodu linkten, koddan ve metin içinden ayıklanır', () {
    expect(GroupApi.parseId('https://ortaknokta.app/g/$id'), id);
    expect(GroupApi.parseId('Kod: ${id.toUpperCase()} gel'), id);
    expect(GroupApi.parseId('merhaba'), isNull);
  });

  test('yalnızca /g/<uuid> rotası katılım ekranını açar; giriş dönüşü ayrı tanınır', () {
    expect(groupIdFromRoute('/g/$id'), id);
    expect(groupIdFromRoute('/g/abc'), isNull);
    expect(groupIdFromRoute('/x/$id'), isNull);
    expect(groupIdFromRoute(null), isNull);
    expect(isAuthCallback('/?code=abc'), isTrue);
    expect(isAuthCallback('/g/$id'), isFalse);
  });

  test('yapılandırılmamışsa sunucuya gitmeden anlaşılır hata verir', () {
    expect(GroupApi.configured, isFalse);
    expect(GroupApi().create(), throwsA(isA<Exception>()));
  });

  /// Sahte Supabase: fonksiyon adına göre yanıt verir, gönderilenleri kaydeder.
  (GroupApi, List<http.Request>) fake(Map<String, Object?> replies, {String? token = 'tok'}) {
    final sent = <http.Request>[];
    final api = GroupApi(
      url: 'https://x.supabase.co',
      key: 'anon',
      token: () => token,
      client: MockClient((req) async {
        sent.add(req);
        final fn = req.url.pathSegments.last;
        final r = replies[fn];
        if (r is int) return http.Response(jsonEncode({'message': 'not_member'}), r);
        return http.Response.bytes(utf8.encode(jsonEncode(r)), 200);
      }),
    );
    return (api, sent);
  }

  test('çağrılar kullanıcının oturumuyla gider; oturum yoksa istek atılmaz', () async {
    final (api, sent) = fake({'create_group': id});
    expect(await api.create(), id);
    expect(sent.single.headers['Authorization'], 'Bearer tok');
    expect(sent.single.headers['apikey'], 'anon');

    final (noSession, none) = fake({}, token: null);
    await expectLater(noSession.create(), throwsA(isA<ApiException>()));
    expect(none, isEmpty);
  });

  final members = [
    {'id': 'm1', 'user_id': 'u1', 'name': 'Ali', 'tag': 'ali.k@gmail.com', 'is_me': true, 'mode': 'car', 'lat': 41.0, 'lon': 29.0, 'label': 'Kadıköy'},
    {'id': 'm2', 'user_id': 'u2', 'name': 'Ali', 'tag': 'ali.y@gmail.com', 'is_me': false, 'mode': 'walk', 'lat': 41.1, 'lon': 29.1, 'label': 'Beşiktaş'},
  ];

  test('aynı isimdeki üyeler e-postayla ayrışır', () async {
    final (api, _) = fake({'group_members': members});
    final m = await api.members(id);
    expect(m.map((x) => x.label), ['Ali (ali.k@gmail.com)', 'Ali (ali.y@gmail.com)']);
    expect(m.first.isMe, isTrue);
    expect(m.first.userId, 'u1');
  });

  test('ortak defter: sunucu kimlikleri isimlere, isimler kimliklere çevrilir', () async {
    final (api, sent) = fake({
      'group_members': members,
      'gathering': {
        'spot': 'Ana kapı',
        'items': [
          {'id': 'i1', 'name': 'Kömür', 'who': 'u2', 'done': false},
          {'id': 'i2', 'name': 'Ekmek', 'who': null, 'done': true},
        ],
        'expenses': [
          {'id': 'e1', 'what': 'Market', 'payer': 'u1', 'kurus': 30000, 'for': ['u1', 'u2']},
        ],
      },
      'add_expense': 'e2',
      'set_item': null,
    });
    final m = await api.members(id);
    final sync = SharedGathering(api, id, m);
    await sync.reload();
    final g = sync.gathering;
    expect(g.spot, 'Ana kapı');
    expect(g.items.first.who, 'Ali (ali.y@gmail.com)');
    expect(g.items.first.id, 'i1');
    expect(settle(g.people, g.expenses).single.from, 'Ali (ali.y@gmail.com)');

    g.items.first.who = 'Ali (ali.k@gmail.com)';
    await sync.updateItem(g.items.first);
    expect(jsonDecode(sent.last.body), {'iid': 'i1', 'p_who': 'u1', 'p_done': false});

    final e = Expense('Kahve', 'Ali (ali.y@gmail.com)', 5000, ['Ali (ali.k@gmail.com)']);
    await sync.addExpense(e);
    expect(e.id, 'e2');
    expect(jsonDecode(sent.last.body)['p_payer'], 'u2');
    expect(jsonDecode(sent.last.body)['p_for'], ['u1']);
  });

  test('bildirimler: kutu okunur, yoldayım ve sessize alma doğru gider', () async {
    final (api, sent) = fake({
      'my_notifications': [
        {'id': 'n1', 'group_id': id, 'kind': 'assigned', 'title': 'Ali sana bir iş verdi', 'body': '"Kömür" senden.',
         'created_at': '2026-11-05T09:00:00+00:00', 'read': false},
      ],
      'ping': null,
      'set_muted': null,
      'mark_read': null,
      'group_members': [
        {...members.first, 'muted': true},
      ],
    });
    final n = (await api.notifications()).single;
    expect(n.groupId, id);
    expect(n.read, isFalse);
    expect(n.at.toUtc(), DateTime.utc(2026, 11, 5, 9));
    await api.ping(id, 'late', 7);
    expect(jsonDecode(sent.last.body), {'gid': id, 'p_kind': 'late', 'p_minutes': 7});
    await api.setMuted(id, true);
    expect(jsonDecode(sent.last.body), {'gid': id, 'p': true});
    await api.markRead();
    expect(jsonDecode(sent.last.body), {'p_ids': null});
    expect((await api.members(id)).single.muted, isTrue);
  });

  test('üye olmayan defteri açamaz, mesaj anlaşılır', () async {
    final (api, _) = fake({'gathering': 403});
    expect(
        () => api.gathering(id, const []),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('önce gruba katılmalısın'))));
  });
}

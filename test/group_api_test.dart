import 'package:flutter_test/flutter_test.dart';
import 'package:ortak_nokta/main.dart';
import 'package:ortak_nokta/services/group_api.dart';

void main() {
  const id = '3f2a9c1e-5b7d-4e8a-9c21-7d4e5f6a8b90';

  test('davet kodu linkten, koddan ve metin içinden ayıklanır', () {
    expect(GroupApi.parseId('https://ortaknokta.app/g/$id'), id);
    expect(GroupApi.parseId('Kod: ${id.toUpperCase()} gel'), id);
    expect(GroupApi.parseId('merhaba'), isNull);
  });

  test('yalnızca /g/<uuid> rotası katılım ekranını açar', () {
    expect(groupIdFromRoute('/g/$id'), id);
    expect(groupIdFromRoute('/g/abc'), isNull);
    expect(groupIdFromRoute('/x/$id'), isNull);
    expect(groupIdFromRoute(null), isNull);
  });

  test('yapılandırılmamışsa sunucuya gitmeden anlaşılır hata verir', () {
    expect(GroupApi.configured, isFalse);
    expect(GroupApi().create(), throwsA(isA<Exception>()));
  });
}

// Tanıtım sitesi. Derleme: flutter build web -t lib/site/main.dart (SETUP.md).
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '../main.dart' show groupIdFromRoute;
import '../ui/group_screens.dart';
import '../ui/theme.dart';
import 'landing_page.dart';
import 'privacy_page.dart';

void main() {
  usePathUrlStrategy(); // /g/<id> gibi temiz adresler (# yok)
  runApp(const SiteApp());
}

class SiteApp extends StatelessWidget {
  const SiteApp({super.key});

  static Route<void> _route(String? name) {
    final id = groupIdFromRoute(name);
    return MaterialPageRoute(
      settings: RouteSettings(name: name),
      builder: (_) => switch (name) {
        _ when id != null => JoinScreen(groupId: id, onWeb: true),
        '/gizlilik' => const PrivacyPage(),
        _ => const LandingPage(),
      },
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ortak Nokta · Ortada değil, adil buluşun',
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        // Doğrudan /g/... adresine gelen ziyaretçi ara sayfaları görmesin.
        onGenerateInitialRoutes: (name) => [_route(name)],
        onGenerateRoute: (s) => _route(s.name),
      );
}

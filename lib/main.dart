import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'services/group_api.dart';
import 'services/prefs.dart';
import 'services/push.dart';
import 'ui/auth_screens.dart';
import 'ui/group_screens.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

/// Bildirime dokununca açılan sayfa için (uygulama o an hangi ekranda olursa olsun).
final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLocalPrefs();
  // Yapılandırılmamışsa (SUPABASE_URL yok) uygulama hesapsız, yalnızca bu cihazda çalışır.
  if (GroupApi.configured) await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const OrtakNoktaApp());
  // Bildirime dokunarak açılınca o grubun sayfası; giriş ekranı varsa girişten sonra görünür.
  await Push.init((id) => navKey.currentState?.push(MaterialPageRoute(builder: (_) => JoinScreen(groupId: id))));
}

/// Davet linki rotası: `/g/{grup kimliği}` (`ortaknokta://join/g/{id}` veya `https://{site}/g/{id}`).
String? groupIdFromRoute(String? route) {
  final segments = Uri.tryParse(route ?? '')?.pathSegments ?? const [];
  return segments.length == 2 && segments[0] == 'g' ? GroupApi.parseId(segments[1]) : null;
}

/// Google girişinden dönüş (`ortaknokta://login-callback?code=…`): Supabase kendisi işler,
/// Flutter'ın derin link olarak bir sayfa daha açmasına gerek yok.
bool isAuthCallback(String? route) {
  final q = Uri.tryParse(route ?? '')?.queryParameters ?? const {};
  return q.containsKey('code') || q.containsKey('error_description');
}

class OrtakNoktaApp extends StatelessWidget {
  const OrtakNoktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    Route<void> home() => MaterialPageRoute(builder: (_) => const AppShell());
    Route<void>? join(String? route) {
      final id = groupIdFromRoute(route);
      return id == null ? null : MaterialPageRoute(builder: (_) => JoinScreen(groupId: id));
    }

    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
      navigatorKey: navKey,
      title: 'Ortak Nokta',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: mode,
      builder: (context, child) => AuthGate(child: child!),
      // Uygulama bir davet linkiyle açılırsa ana ekranın üstüne katılım ekranı gelir.
      onGenerateInitialRoutes: (route) => [home(), ?join(route)],
      onGenerateRoute: (s) => join(s.name) ?? (isAuthCallback(s.name) ? _Done() : home()),
    ),
    );
  }
}

/// Hemen kendini kapatan, görünmez sayfa.
class _Done extends PageRouteBuilder<void> {
  _Done()
      : super(
          opaque: false,
          pageBuilder: (context, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).maybePop();
            });
            return const SizedBox.shrink();
          },
        );
}

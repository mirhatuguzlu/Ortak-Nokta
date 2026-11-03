import 'package:flutter/material.dart';

import 'services/group_api.dart';
import 'ui/group_screens.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const OrtakNoktaApp());

/// Davet linki rotası: `/g/{grup kimliği}` (`ortaknokta://join/g/{id}` veya `https://{site}/g/{id}`).
String? groupIdFromRoute(String? route) {
  final segments = Uri.tryParse(route ?? '')?.pathSegments ?? const [];
  return segments.length == 2 && segments[0] == 'g' ? GroupApi.parseId(segments[1]) : null;
}

class OrtakNoktaApp extends StatelessWidget {
  const OrtakNoktaApp({super.key});

  @override
  Widget build(BuildContext context) {
    Route<void> home() => MaterialPageRoute(builder: (_) => const HomeScreen());
    Route<void>? join(String? route) {
      final id = groupIdFromRoute(route);
      return id == null ? null : MaterialPageRoute(builder: (_) => JoinScreen(groupId: id));
    }

    return MaterialApp(
      title: 'Ortak Nokta',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      // Uygulama bir davet linkiyle açılırsa ana ekranın üstüne katılım ekranı gelir.
      onGenerateInitialRoutes: (route) => [home(), ?join(route)],
      onGenerateRoute: (s) => join(s.name) ?? home(),
    );
  }
}

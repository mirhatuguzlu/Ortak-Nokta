import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/osm_api.dart';

const istanbul = LatLng(41.0151, 28.9795);

// Tek örnek: her build'de yeni NetworkTileProvider oluşturmak süren karo yüklemelerini iptal ediyor.
final osmTiles = TileLayer(
      urlTemplate: tileUrl,
      tileProvider: NetworkTileProvider(headers: {'User-Agent': appUserAgent}),
    );

Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void showAbout(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hakkında ve gizlilik'),
        content: const Text(
          'Harita verisi © OpenStreetMap katkıcıları, ODbL lisansı ile.\n'
          'Rotalar: OSRM (FOSSGIS sunucusu). Adres arama: Nominatim. Mekanlar: Overpass API. Hava: Open-Meteo.\n\n'
          'Konumların yalnızca rota hesaplamak için bu servislere gönderilir. Davet linki '
          'kullanırsan Google hesabınla giriş yaparsın; grup konumları, ortak liste ve hesap 7 gün sonra sunucudan silinir. Kaydettiğin buluşmalar '
          'yalnızca bu cihazda tutulur.',
        ),
        actions: [
          TextButton(onPressed: () => _open('https://www.openstreetmap.org/fixthemap'), child: const Text('Haritayı düzelt')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );

/// OSM politikası: atıf görünür olmalı, menü arkasına saklanamaz.
class Attribution extends StatelessWidget {
  const Attribution({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () => _open('https://www.openstreetmap.org/copyright'),
            style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 11)),
            child: const Text('© OpenStreetMap katkıcıları'),
          ),
          IconButton(
            tooltip: 'Hakkında',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: () => showAbout(context),
          ),
        ]),
      );
}

/// Tek iş: haritayı kaydırıp iğneyi başlangıç noktasının üstüne getirmek.
class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key, required this.api, required this.name, this.start});
  final OsmApi api;
  final String name;
  final LatLng? start;

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final _map = MapController();
  bool _busy = false;

  Future<void> _done() async {
    final p = _map.camera.center;
    setState(() => _busy = true);
    final label = await widget.api.reverse(p).catchError((_) => null);
    if (mounted) Navigator.pop(context, Place(label ?? 'Haritadan seçildi', p));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.name} nereden çıkacak?')),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: widget.start ?? istanbul, initialZoom: widget.start == null ? 11 : 15),
          children: [osmTiles],
        ),
        // İğnenin ucu harita merkezine denk gelsin.
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Icon(Icons.location_on, size: 48, color: scheme.secondary,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black26)]),
            ),
          ),
        ),
        const Positioned(top: 8, right: 8, child: Attribution()),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Haritayı kaydır, iğne doğru yere gelince onayla.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _done,
              child: Text(_busy ? 'Adres bulunuyor…' : 'Burası'),
            ),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';
import '../services/osm_api.dart';

/// Haritadan seçim isteği için sonuç değeri.
const pickOnMap = Place('', LatLng(0, 0));

class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key, required this.api, required this.name, this.allowMapPick = true});
  final OsmApi api;
  final String name;

  /// Haritanın olmadığı ekranlarda (davete katılım) "Haritadan seç" gizlenir.
  final bool allowMapPick;

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  final _query = TextEditingController();
  List<Place>? _results;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Bir şeyler ters gitti. Tekrar dene.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _search() {
    if (_query.text.trim().length < 3) {
      setState(() => _error = 'En az 3 karakter yaz.');
      return;
    }
    FocusScope.of(context).unfocus();
    _run(() async => _results = await widget.api.search(_query.text));
  }

  void _myLocation() => _run(() async {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const ApiException('Konum servisi kapalı.');
        }
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          throw const ApiException('Konum izni verilmedi. Adres arayabilir veya haritadan seçebilirsin.');
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
        );
        if (mounted) Navigator.pop(context, Place('Mevcut konum', LatLng(pos.latitude, pos.longitude)));
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.name} nereden geliyor?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Adres, semt veya mekan',
                  helperText: 'Yazıp klavyeden "Ara"ya bas',
                  counterText: '',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                      tooltip: 'Ara', onPressed: _busy ? null : _search, icon: const Icon(Icons.arrow_forward)),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _busy ? null : _myLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Konumum')),
                ),
                if (widget.allowMapPick) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => Navigator.pop(context, pickOnMap),
                        icon: const Icon(Icons.touch_app),
                        label: const Text('Haritadan seç')),
                  ),
                ],
              ]),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: scheme.error)),
                ),
              if (_results != null && _results!.isEmpty && !_busy)
                const Padding(padding: EdgeInsets.only(top: 12), child: Text('Sonuç bulunamadı.')),
              if (_results?.isNotEmpty ?? false)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in _results!)
                        ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, p),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

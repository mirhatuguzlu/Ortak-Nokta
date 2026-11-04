import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';

enum TravelMode {
  walk('Yürüyüş', Icons.directions_walk, osrmFootUrl),
  car('Araç', Icons.directions_car, osrmCarUrl),
  bus('Otobüs', Icons.directions_bus, null),
  taxi('Taksi', Icons.local_taxi, null);

  const TravelMode(this.label, this.icon, this.osrmUrl);
  final String label;
  final IconData icon;

  /// null: henüz desteklenmiyor ("yakında").
  final String? osrmUrl;
  bool get available => osrmUrl != null;
}

class Place {
  const Place(this.label, this.point);
  final String label;
  final LatLng point;
}

class Participant {
  Participant(this.name, this.color);
  String name;
  final Color color;
  Place? place;
  TravelMode mode = TravelMode.walk;

  /// "Hep geç kalır": çıkış saati bu kadar dakika erken gösterilir (gizli değil, mesajda yazar).
  int lateBuffer = 0;
}

const lateBufferMinutes = 10;

enum VenueKind {
  cafe('Kafe', Icons.local_cafe),
  restaurant('Restoran', Icons.restaurant),
  fastFood('Hızlı yemek', Icons.fastfood),
  bar('Bar', Icons.local_bar),
  dessert('Tatlı', Icons.icecream),
  park('Park', Icons.park);

  const VenueKind(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Yağmurda/soğukta önce kapalı mekanlar önerilir.
  bool get indoor => this != park;

  static VenueKind? fromTags(Map tags) => switch (tags['amenity'] ?? tags['leisure']) {
        'cafe' => cafe,
        'restaurant' => restaurant,
        'fast_food' => fastFood,
        'pub' || 'bar' => bar,
        'ice_cream' => dessert,
        'park' => park,
        _ => null,
      };
}

/// OSM etiketlerinden okunan, buluşmada işe yarayan mekan özellikleri.
enum VenueFeature {
  wheelchair('Engelsiz', Icons.accessible),
  outdoor('Açık hava', Icons.deck_outlined),
  wifi('Wi-Fi', Icons.wifi),
  veggie('Vejetaryen', Icons.eco_outlined),
  openLate('Gece açık', Icons.nightlight_outlined);

  const VenueFeature(this.label, this.icon);
  final String label;
  final IconData icon;

  static Set<VenueFeature> fromTags(Map tags) {
    final hours = '${tags['opening_hours'] ?? ''}';
    return {
      if (tags['wheelchair'] == 'yes') wheelchair,
      if (tags['outdoor_seating'] == 'yes') outdoor,
      if (const ['wlan', 'yes', 'wifi'].contains(tags['internet_access'])) wifi,
      if (const ['yes', 'only'].contains(tags['diet:vegetarian']) || const ['yes', 'only'].contains(tags['diet:vegan']))
        veggie,
      // shortcut: opening_hours tam ayrıştırılmıyor; 24/7 ya da 23:00 sonrası kapanış metinde aranır.
      if (hours == '24/7' || RegExp(r'-(2[3-4]|0[0-5]):').hasMatch(hours)) openLate,
    };
  }
}

class Venue {
  const Venue(this.name, this.kind, this.point, this.meters, {this.features = const {}, this.hours});
  final String name;
  final VenueKind kind;
  final LatLng point;

  /// Adil noktaya kuş uçumu uzaklık.
  final double meters;
  final Set<VenueFeature> features;

  /// OSM opening_hours metni (ör. "Mo-Su 08:00-23:00"); yoksa null.
  final String? hours;
}

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
}

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

class Venue {
  const Venue(this.name, this.kind, this.point, this.meters);
  final String name;
  final VenueKind kind;
  final LatLng point;

  /// Adil noktaya kuş uçumu uzaklık.
  final double meters;
}

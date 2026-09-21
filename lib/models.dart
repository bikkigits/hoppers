import 'package:flutter/material.dart';

// --- LANGUAGE ---
enum AppLanguage { english, bengali, hindi }

// --- ENUMS & POI TYPES ---
enum CrowdLevel { low, medium, insane }

extension CrowdLevelX on CrowdLevel {
  String get label => switch (this) {
        CrowdLevel.low => 'Low',
        CrowdLevel.medium => 'Medium',
        CrowdLevel.insane => 'Insane',
      };
}

enum PoiType { pandal, gate, police, toilet, parking, veg, nonVeg, bar, railway, ferry }

extension PoiTypeUi on PoiType {
  IconData get icon => switch (this) {
        PoiType.pandal => Icons.temple_hindu_rounded,
        PoiType.gate => Icons.sensor_door_rounded,
        PoiType.police => Icons.local_police_rounded,
        PoiType.toilet => Icons.wc_rounded,
        PoiType.parking => Icons.local_parking_rounded,
        PoiType.veg => Icons.eco_rounded,
        PoiType.nonVeg => Icons.set_meal_rounded,
        PoiType.bar => Icons.local_bar_rounded,
        PoiType.railway => Icons.train_rounded,
        PoiType.ferry => Icons.directions_boat_rounded,
      };

  String get label => switch (this) {
        PoiType.pandal => 'Pandals',
        PoiType.gate => 'Gates',
        PoiType.police => 'Police',
        PoiType.toilet => 'Toilets',
        PoiType.parking => 'Parking',
        PoiType.veg => 'Veg',
        PoiType.nonVeg => 'Non-Veg',
        PoiType.bar => 'Bars',
        PoiType.railway => 'Railway',
        PoiType.ferry => 'Ferry',
      };
}

class ZonePreset {
  const ZonePreset({required this.id, required this.label, required this.lat, required this.lng, required this.zoom, required this.zoneTag});
  final String id;
  final String label;
  final double lat;
  final double lng;
  final double zoom;
  final String zoneTag;

  static const List<ZonePreset> presets = [
    ZonePreset(id: 'north', label: 'North Heritage', lat: 22.610, lng: 88.372, zoom: 14.2, zoneTag: 'north'),
    ZonePreset(id: 'south', label: 'South Themes', lat: 22.505, lng: 88.353, zoom: 14.0, zoneTag: 'south'),
  ];
}
typedef ZonePresetTap = void Function(ZonePreset preset);

// --- DATA MODELS ---

class Pandal {
  const Pandal({
    required this.id,
    required this.name,
    required this.theme,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.nearestMetroId,
    required this.nearestMetroName,
    this.verified = false,
    this.isFeatured = false,
    this.address,
    this.rating,
    this.crowdLevel = CrowdLevel.medium,
    this.crowdUpdatedAt,
  });

  final String id;
  final String name;
  final String theme;
  final String zone;
  final double lat;
  final double lng;
  final String nearestMetroId;
  final String nearestMetroName;
  final bool verified;
  final bool isFeatured;
  final String? address;
  final double? rating;
  final CrowdLevel crowdLevel;
  final DateTime? crowdUpdatedAt;

  factory Pandal.fromJson(Map<String, dynamic> j) => Pandal(
        id: j['id'] as String,
        name: j['name'] as String,
        theme: j['theme'] as String? ?? '',
        zone: j['zone'] as String? ?? 'others',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        nearestMetroId: j['nearestMetroId'] as String? ?? '',
        nearestMetroName: j['nearestMetroName'] as String? ?? '',
        verified: j['verified'] as bool? ?? false,
        isFeatured: j['isFeatured'] as bool? ?? false,
        address: j['address'] as String?,
        rating: j['rating'] != null ? (j['rating'] as num).toDouble() : null,
        crowdLevel: CrowdLevel.values.firstWhere(
          (c) => c.name == (j['crowdLevel'] as String? ?? 'medium'),
          orElse: () => CrowdLevel.medium,
        ),
        crowdUpdatedAt: j['crowdUpdatedAt'] != null ? DateTime.tryParse(j['crowdUpdatedAt'] as String) : null,
      );
}

class Poi {
  const Poi({required this.id, required this.name, required this.type, required this.lat, required this.lng, this.description});
  final String id;
  final String name;
  final PoiType type;
  final double lat;
  final double lng;
  final String? description;

  factory Poi.fromJson(Map<String, dynamic> j) => Poi(
        id: j['id'] as String,
        name: j['name'] as String,
        type: PoiType.values.firstWhere((t) => t.name == (j['type'] as String? ?? 'toilet'), orElse: () => PoiType.toilet),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        description: j['description'] as String?,
      );
}

class MetroStation {
  const MetroStation({required this.id, required this.name, required this.lat, required this.lng});
  final String id;
  final String name;
  final double lat;
  final double lng;

  factory MetroStation.fromJson(Map<String, dynamic> j) => MetroStation(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

class MetroEdge {
  const MetroEdge(this.toId, this.minutes, this.line);
  final String toId;
  final double minutes;
  final String line;
}

class MetroGraph {
  const MetroGraph(this.stations, this.edges);
  final Map<String, MetroStation> stations;
  final Map<String, List<MetroEdge>> edges;

  factory MetroGraph.fromJson(Map<String, dynamic> j) {
    final sMap = <String, MetroStation>{};
    for (final s in (j['stations'] as List).cast<Map<String, dynamic>>()) {
      sMap[s['id'] as String] = MetroStation.fromJson(s);
    }
    final eMap = <String, List<MetroEdge>>{};
    final rawEdges = j['edges'] as Map<String, dynamic>;
    for (final k in rawEdges.keys) {
      final list = (rawEdges[k] as List).cast<Map<String, dynamic>>();
      eMap[k] = list.map((e) => MetroEdge(e['to'] as String, (e['minutes'] as num).toDouble(), e['line'] as String)).toList();
    }
    return MetroGraph(sMap, eMap);
  }
}
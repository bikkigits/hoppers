import 'package:flutter/material.dart';

enum AppLocale { en, bn, hi }
enum CrowdLevel { low, medium, insane }
extension CrowdLevelUi on CrowdLevel {
  String get label => switch (this) { CrowdLevel.low => 'Low', CrowdLevel.medium => 'Medium', CrowdLevel.insane => 'Insane' };
}

enum PoiType { pandal, gate, police, toilet, parking, veg, nonVeg, bar }
extension PoiTypeUi on PoiType {
  IconData get icon => switch (this) { PoiType.pandal => Icons.temple_hindu_rounded, PoiType.gate => Icons.sensor_door_rounded, PoiType.police => Icons.local_police_rounded, PoiType.toilet => Icons.wc_rounded, PoiType.parking => Icons.local_parking_rounded, PoiType.veg => Icons.eco_rounded, PoiType.nonVeg => Icons.set_meal_rounded, PoiType.bar => Icons.local_bar_rounded };
  String get label => switch (this) { PoiType.pandal => 'Pandals', PoiType.gate => 'Gates', PoiType.police => 'Police', PoiType.toilet => 'Toilets', PoiType.parking => 'Parking', PoiType.veg => 'Veg', PoiType.nonVeg => 'Non-Veg', PoiType.bar => 'Bars' };
}

class ZonePreset {
  const ZonePreset({required this.id, required this.label, required this.lat, required this.lng, required this.zoom, required this.zoneTag});
  final String id; final String label; final double lat; final double lng; final double zoom; final String zoneTag;
  static const List<ZonePreset> presets = [
    ZonePreset(id: 'north', label: 'North Heritage', lat: 22.610, lng: 88.372, zoom: 14.2, zoneTag: 'north'),
    ZonePreset(id: 'south', label: 'South Themes', lat: 22.505, lng: 88.345, zoom: 14.2, zoneTag: 'south'),
  ];
}

// YEH RAHI MISSING LINE JO ERROR KO FIX KAREGI
typedef ZonePresetTap = void Function(ZonePreset preset);

class Pandal {
  const Pandal({required this.id, required this.name, required this.theme, required this.zone, required this.lat, required this.lng, required this.nearestMetroId, required this.nearestMetroName, this.verified = false, this.crowdLevel = CrowdLevel.medium});
  final String id; final String name; final String theme; final String zone; final double lat; final double lng; final String nearestMetroId; final String nearestMetroName; final bool verified; final CrowdLevel crowdLevel;
  factory Pandal.fromJson(Map<String, dynamic> j) => Pandal(id: j['id'], name: j['name'], theme: j['theme'] ?? '', zone: j['zone'] ?? 'others', lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble(), nearestMetroId: j['nearestMetroId'] ?? '', nearestMetroName: j['nearestMetroName'] ?? '', verified: j['verified'] ?? false, crowdLevel: CrowdLevel.values.firstWhere((c) => c.name == (j['crowdLevel'] ?? 'medium'), orElse: () => CrowdLevel.medium));
}

class MetroStation {
  const MetroStation({required this.id, required this.name, required this.lat, required this.lng});
  final String id; final String name; final double lat; final double lng;
  factory MetroStation.fromJson(Map<String, dynamic> j) => MetroStation(id: j['id'], name: j['name'], lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble());
}

class MetroEdge { const MetroEdge(this.toId, this.minutes, this.line); final String toId; final double minutes; final String line; }

class MetroGraph {
  MetroGraph(this.stations, this.adjacency);
  final Map<String, MetroStation> stations; final Map<String, List<MetroEdge>> adjacency;
  factory MetroGraph.fromJson(Map<String, dynamic> j) {
    final stations = <String, MetroStation>{};
    for (final raw in (j['stations'] as List)) { final s = MetroStation.fromJson(raw); stations[s.id] = s; }
    final adjacency = <String, List<MetroEdge>>{};
    for (final raw in (j['edges'] as List)) {
      final from = raw['from']; final to = raw['to']; final minutes = (raw['minutes'] as num).toDouble(); final line = raw['line'];
      adjacency.putIfAbsent(from, () => []).add(MetroEdge(to, minutes, line)); adjacency.putIfAbsent(to, () => []).add(MetroEdge(from, minutes, line));
    }
    return MetroGraph(stations, adjacency);
  }
}
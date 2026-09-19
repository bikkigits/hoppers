import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'models.dart';

class AppStrings {
  const AppStrings(this.locale); final AppLocale locale;
  static const Map<String, Map<AppLocale, String>> _table = {
    'home': {AppLocale.en: 'Home', AppLocale.bn: 'হোম', AppLocale.hi: 'होम'}, 'nearby_needs': {AppLocale.en: 'Nearby Needs', AppLocale.bn: 'আশেপাশে', AppLocale.hi: 'आस-पास'}, 'action_hub': {AppLocale.en: 'Action Hub', AppLocale.bn: 'অ্যাকশন হাব', AppLocale.hi: 'हब'}, 'profile': {AppLocale.en: 'Passport', AppLocale.bn: 'পাসপোর্ট', AppLocale.hi: 'पासपोर्ट'}, 'sos': {AppLocale.en: 'SOS', AppLocale.bn: 'SOS', AppLocale.hi: 'SOS'}, 'expected_crowd': {AppLocale.en: 'Expected Crowd', AppLocale.bn: 'ভিড়', AppLocale.hi: 'अनुमानित भीड़'}, 'take_me_there': {AppLocale.en: 'Take me there', AppLocale.bn: 'আমাকে নিয়ে চলো', AppLocale.hi: 'मुझे वहाँ ले चलो'}, 'share_location': {AppLocale.en: 'Share', AppLocale.bn: 'শেয়ার করুন', AppLocale.hi: 'शेयर करें'}, 'mark_visited': {AppLocale.en: 'Mark visited', AppLocale.bn: 'ঘুরে দেখা হয়েছে', AppLocale.hi: 'देखा हुआ'}, 'update_crowd': {AppLocale.en: 'Update crowd', AppLocale.bn: 'আপডেট করুন', AppLocale.hi: 'अपडेट करें'}, 'verified': {AppLocale.en: 'Verified', AppLocale.bn: 'যাচাইকৃত', AppLocale.hi: 'सत्यापित'}, 'metro_router': {AppLocale.en: 'Metro Router', AppLocale.bn: 'মেট্রো রাউটার', AppLocale.hi: 'मेट्रो राउटर'}, 'change_language': {AppLocale.en: 'Change language', AppLocale.bn: 'ভাষা', AppLocale.hi: 'भाषा बदलें'}, 'suggest_pandal': {AppLocale.en: 'Suggest pandal', AppLocale.bn: 'সাজেস্ট করুন', AppLocale.hi: 'सुझाएँ'}, 'about_us': {AppLocale.en: 'About Us', AppLocale.bn: 'আমাদের সম্পর্কে', AppLocale.hi: 'हमारे बारे में'},
  };
  String t(String key) => _table[key]?[locale] ?? key;
}

class DataService {
  DataService() : _client = http.Client(); final http.Client _client;
  Future<void> init() async { await Hive.openBox<String>('pandals_cache'); await Hive.openBox<String>('metro_cache'); }
  Future<List<Pandal>> loadPandals() async {
    final bundled = jsonDecode(await rootBundle.loadString('assets/data/pandals.sample.json')) as List;
    return bundled.map((e) => Pandal.fromJson(e)).toList();
  }
  Future<MetroGraph> loadMetroGraph() async {
    final bundled = jsonDecode(await rootBundle.loadString('assets/data/metro_graph.sample.json'));
    return MetroGraph.fromJson(bundled);
  }
}

class RouteStep { const RouteStep(this.station, this.arrivalLine); final MetroStation station; final String? arrivalLine; }
class MetroRoute {
  const MetroRoute(this.steps, this.totalMinutes, this.transfers); final List<RouteStep> steps; final double totalMinutes; final int transfers;
  List<String> toInstructions() {
    final out = <String>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (i == 0) { out.add('Board ${steps.length > 1 ? steps[1].arrivalLine : '—'} Line at ${step.station.name}'); continue; }
      if (step.arrivalLine != steps[i - 1].arrivalLine) out.add('Change to ${step.arrivalLine} Line at ${step.station.name}');
      if (i == steps.length - 1) out.add('Alight at ${step.station.name}');
    }
    return out;
  }
}

class MetroRouterService {
  MetroRouterService(this.graph); final MetroGraph graph;
  MetroRoute? findRoute(String fromId, String toId) {
    if (fromId == toId || !graph.stations.containsKey(fromId) || !graph.stations.containsKey(toId)) return null;
    final dist = <String, double>{fromId: 0}; final arrivedVia = <String, String>{}; final cameFrom = <String, String>{}; final visited = <String>{};
    final frontier = HeapPriorityQueue<String>((a, b) => (dist[a] ?? double.infinity).compareTo(dist[b] ?? double.infinity))..add(fromId);
    while (frontier.isNotEmpty) {
      final current = frontier.removeFirst();
      if (visited.contains(current)) continue; visited.add(current); if (current == toId) break;
      for (final edge in graph.adjacency[current] ?? const <MetroEdge>[]) {
        if (visited.contains(edge.toId)) continue;
        final isTransfer = arrivedVia[current] != null && arrivedVia[current] != edge.line;
        final cost = edge.minutes + (isTransfer ? 5 : 0);
        final candidate = (dist[current] ?? double.infinity) + cost;
        if (candidate < (dist[edge.toId] ?? double.infinity)) {
          dist[edge.toId] = candidate; arrivedVia[edge.toId] = edge.line; cameFrom[edge.toId] = current; frontier.add(edge.toId);
        }
      }
    }
    if (!dist.containsKey(toId)) return null;
    final orderedIds = <String>[toId]; var cursor = toId;
    while (cameFrom.containsKey(cursor)) { cursor = cameFrom[cursor]!; orderedIds.add(cursor); }
    final steps = orderedIds.reversed.map((id) => RouteStep(graph.stations[id]!, arrivedVia[id])).toList();
    var transfers = 0; for (var i = 2; i < steps.length; i++) { if (steps[i].arrivalLine != steps[i - 1].arrivalLine) transfers++; }
    return MetroRoute(steps, dist[toId]!, transfers);
  }
}

class CachingTileProvider extends TileProvider {
  CachingTileProvider() : _client = http.Client(); final http.Client _client; static const boxName = 'map_tile_cache_v1';
  static Future<void> ensureBoxOpen() async { if (!Hive.isBoxOpen(boxName)) await Hive.openBox<Uint8List>(boxName); }
  @override ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(url: getTileUrl(coordinates, options), cacheKey: '${coordinates.z}_${coordinates.x}_${coordinates.y}', client: _client);
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({required this.url, required this.cacheKey, required this.client});
  final String url; final String cacheKey; final http.Client client;
  @override Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<_CachedTileImage>(this);
  @override ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1.0, debugLabel: cacheKey);
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    await CachingTileProvider.ensureBoxOpen(); final box = Hive.box<Uint8List>(CachingTileProvider.boxName);
    Uint8List? bytes = box.get(cacheKey);
    if (bytes == null) { final res = await client.get(Uri.parse(url)); if (res.statusCode == 200) { bytes = res.bodyBytes; unawaited(box.put(cacheKey, bytes)); } else { throw Exception(); } }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }
  @override bool operator ==(Object other) => other is _CachedTileImage && other.cacheKey == cacheKey;
  @override int get hashCode => cacheKey.hashCode;
}
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'models.dart';
import 'providers.dart';
import 'services.dart';
import 'ui_widgets.dart';

class MainScreen extends ConsumerStatefulWidget { const MainScreen({super.key}); @override ConsumerState<MainScreen> createState() => _MSState(); }
class _MSState extends ConsumerState<MainScreen> {
  final _map = MapController(); bool _showFilters = false; Position? _pos;
  @override void initState() { super.initState(); Geolocator.getCurrentPosition().then((p) { if(mounted) setState(() => _pos = p); }).catchError((_) {}); }
  @override Widget build(BuildContext context) {
    final pandals = ref.watch(pandalsProvider);
    return Scaffold(
      backgroundColor: HoppersColors.midnight,
      body: Stack(children: [
        pandals.when(loading: () => const Center(child: CircularProgressIndicator(color: HoppersColors.gold)), error: (e,_) => Center(child: Text('$e')), data: (p) => _buildMap(p)),
        Column(children: [
          const SafeArea(bottom: false, child: Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: CircleAvatar(radius: 18, backgroundColor: HoppersColors.midnightHi, child: Icon(Icons.person, color: HoppersColors.gold, size: 20)))),
          const TickerBar(items: ['🚔 Traffic: Southern Ave one-way after 6 PM', '🙏 Next Pushpanjali in 42 min']),
          if (_showFilters) Padding(padding: const EdgeInsets.only(top: 8), child: FilterBar(onTap: (p) { setState(() => _showFilters = true); _map.move(ll.LatLng(p.lat, p.lng), p.zoom); }))
        ]),
        Positioned(left: 0, right: 0, bottom: 0, child: BottomDock(
          onHome: () { setState(() => _showFilters = false); ref.read(activeFiltersProvider.notifier).state = {}; _map.move(const ll.LatLng(22.5726, 88.3639), 13); },
          onNearbyNeeds: () => setState(() => _showFilters = !_showFilters),
          onActionHub: () => showActionHubSheet(context), onProfile: (){}, onSos: () => launchUrl(Uri(scheme: 'tel', path: '100'))
        )),
      ]),
    );
  }
  Widget _buildMap(List<Pandal> pandals) => FlutterMap(
    mapController: _map, options: const MapOptions(initialCenter: ll.LatLng(22.5726, 88.3639), initialZoom: 13),
    children: [
      TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd'], tileProvider: CachingTileProvider()),
      MarkerLayer(markers: [
        for (final p in pandals) Marker(point: ll.LatLng(p.lat, p.lng), width: 40, height: 40, child: GestureDetector(onTap: () => showPandalCard(context, p, userPosition: _pos), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: HoppersColors.midnight.withOpacity(0.85), shape: BoxShape.circle, border: Border.all(color: HoppersColors.crimson, width: 1.5)), child: SvgPicture.asset('assets/icons/pandal_marker.svg', colorFilter: const ColorFilter.mode(HoppersColors.crimson, BlendMode.srcIn)))))
      ])
    ]);
}
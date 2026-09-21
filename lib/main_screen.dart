import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

// Sahi import paths
import 'models.dart';
import 'providers.dart';
import 'theme.dart';
import 'ui_widgets.dart';
import 'services.dart'; 

const double kAuxiliaryMarkerZoomThreshold = 15.5;
const ll.LatLng kKolkataCenter = ll.LatLng(22.5726, 88.3639);
const double kDefaultZoom = 13.0;

// Dummy POIs jab tak aap JSON add na karein
final List<Poi> dummyPois = [
  Poi(id: 'p1', name: 'Police Assistance', type: PoiType.police, lat: 22.5990, lng: 88.3730),
  Poi(id: 't1', name: 'Public Toilet', type: PoiType.toilet, lat: 22.5980, lng: 88.3710),
  Poi(id: 'r1', name: 'Sealdah Railway', type: PoiType.railway, lat: 22.5675, lng: 88.3707),
  Poi(id: 'f1', name: 'Howrah Ferry', type: PoiType.ferry, lat: 22.5852, lng: 88.3105),
];

// ... BAAKI KA PURANA CLASS _MainScreenState AUR USKA CODE YAHAN WAISE HI RAHEGA ...
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final _mapController = MapController();
  double _zoom = kDefaultZoom;
  bool _showFilterBar = false;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _tryLocateUser();
  }

  Future<void> _tryLocateUser() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {
      // Ignored - works offline without location too.
    }
  }

  void _onZonePreset(ZonePreset preset) {
    setState(() => _showFilterBar = true);
    _mapController.move(ll.LatLng(preset.lat, preset.lng), preset.zoom);
  }

  void _resetMap() {
    setState(() => _showFilterBar = false);
    ref.read(activeFiltersProvider.notifier).state = {};
    _mapController.move(kKolkataCenter, kDefaultZoom);
  }

  Widget _buildMap(List<Pandal> pandals, Set<PoiType> filters) {
    // Zoom logic: Show only featured pandals when zoomed out, unless a filter is active
    final visiblePandals = pandals.where((p) {
      if (filters.isNotEmpty) return true; // Show all if searching
      if (_zoom >= kAuxiliaryMarkerZoomThreshold) return true; // Show all if zoomed in
      return p.isFeatured; // Only show featured on zoomed out map
    }).toList();

    // Auxiliary POI Filter logic
    final showAuxiliary = filters.isNotEmpty || _zoom >= kAuxiliaryMarkerZoomThreshold;
    final visiblePois = dummyPois.where((poi) {
      final matchesFilter = filters.isEmpty || filters.contains(poi.type);
      return showAuxiliary && matchesFilter;
    }).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: kKolkataCenter,
        initialZoom: kDefaultZoom,
        // CRITICAL FIX: Lock the map rotation North-facing so user doesn't get lost
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onPositionChanged: (camera, hasGesture) {
           if(mounted) setState(() => _zoom = camera.zoom);
        },
      ),
      children: [
        // CRITICAL FIX: Removed CartoDB (API Key Required) and Added Free OpenStreetMap (OSM)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bikkigits.hoppers',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            // Pandal Markers (Golden/Crimson pure widgets instead of SVGs)
            for (final p in visiblePandals)
              Marker(
                point: ll.LatLng(p.lat, p.lng),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => showPandalCard(context, p, userPosition: _userPosition),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HoppersColors.midnight.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: HoppersColors.crimson, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: const Icon(Icons.temple_hindu_rounded, color: HoppersColors.gold, size: 22),
                  ),
                ),
              ),

            // Auxiliary POI Markers (Toilets, Police, Railway, Ferry)
            for (final poi in visiblePois)
              Marker(
                point: ll.LatLng(poi.lat, poi.lng),
                width: 32,
                height: 32,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(poi.name), duration: const Duration(seconds: 1)));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: HoppersColors.midnight.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: HoppersColors.gold, width: 1.5),
                    ),
                    child: Icon(poi.type.icon, size: 16, color: HoppersColors.gold),
                  ),
                ),
              ),
              
            // Live User Location (Blue Dot)
            if (_userPosition != null)
              Marker(
                point: ll.LatLng(_userPosition!.latitude, _userPosition!.longitude),
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 5)
                    ]
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pandalsAsync = ref.watch(pandalsProvider);
    final activeFilters = ref.watch(activeFiltersProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: HoppersColors.midnight,
      body: Stack(
        children: [
          // 1. The Map Background
          Positioned.fill(
            child: pandalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: HoppersColors.gold)),
              error: (e, _) => Center(
                child: Text('Could not load pandal data.\n$e', style: const TextStyle(color: Colors.white)),
              ),
              data: (pandals) => _buildMap(pandals, activeFilters),
            ),
          ),
          
          // 2. The Top UI Layer (Z-Index Fixed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SafeArea(
                  bottom: false, 
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Profile / Passport
                        GestureDetector(
                          onTap: () => showHopperPassportSheet(context),
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundColor: HoppersColors.midnightHi,
                            child: Icon(Icons.person_rounded, color: HoppersColors.gold, size: 22),
                          ),
                        ),
                        // Right: Quick Route Button
                        ElevatedButton.icon(
                          onPressed: () {
                             showDialog(context: context, builder: (_) => const MetroRouterDialog());
                          },
                          icon: const Icon(Icons.alt_route_rounded, size: 18),
                          label: Text(AppStrings.get(lang, 'smart_metro_router')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HoppersColors.gold,
                            foregroundColor: HoppersColors.midnight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 4,
                          ),
                        )
                      ],
                    ),
                  )
                ),
                const SizedBox(height: 8),
                TickerBar(items: [AppStrings.get(lang, 'kp_advisory')]),
                if (_showFilterBar)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilterBar(onTap: _onZonePreset),
                  ),
              ],
            ),
          ),

          // 3. The Bottom Dock Layer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: BottomDock(
                onHome: _resetMap,
                onNearbyNeeds: () => setState(() => _showFilterBar = !_showFilterBar),
                onActionHub: () => showActionHubSheet(context),
                onProfile: () => showHopperPassportSheet(context),
                onSos: () => showSosSheet(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
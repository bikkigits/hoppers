// =====================================================================
// HOPPERS SUPER-APP - PART 1 (IMPORTS, ROUTER, ANIMATIONS & LOGIC)
// =====================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http; 

void main() {
  runApp(const HoppersApp());
}

// -------------------------------------------------------------
// 1. OFFLINE SMART METRO ROUTER (WITH GAP BRIDGING)
// -------------------------------------------------------------
enum MetroLine { blue, green, orange, purple }

class MetroStation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<MetroLine> lines;
  const MetroStation({required this.id, required this.name, required this.lat, required this.lng, required this.lines});
}

class MetroRouterService {
  static const List<MetroStation> masterStations = [
    MetroStation(id: 'dakshineswar', name: 'Dakshineswar', lat: 22.6547, lng: 88.3582, lines: [MetroLine.blue]),
    MetroStation(id: 'dumdum', name: 'Dum Dum', lat: 22.6219, lng: 88.3789, lines: [MetroLine.blue]),
    MetroStation(id: 'shyambazar', name: 'Shyambazar', lat: 22.6001, lng: 88.3698, lines: [MetroLine.blue]),
    MetroStation(id: 'esplanade', name: 'Esplanade', lat: 22.5645, lng: 88.3518, lines: [MetroLine.blue, MetroLine.green]),
    MetroStation(id: 'park_street', name: 'Park Street', lat: 22.5540, lng: 88.3512, lines: [MetroLine.blue]),
    MetroStation(id: 'kalighat', name: 'Kalighat', lat: 22.5180, lng: 88.3468, lines: [MetroLine.blue]),
    MetroStation(id: 'kavi_subhash', name: 'Kavi Subhash', lat: 22.4712, lng: 88.3970, lines: [MetroLine.blue, MetroLine.orange]),
    MetroStation(id: 'howrah_maidan', name: 'Howrah Maidan', lat: 22.5780, lng: 88.3280, lines: [MetroLine.green]),
    MetroStation(id: 'howrah', name: 'Howrah Station', lat: 22.5842, lng: 88.3420, lines: [MetroLine.green]),
    MetroStation(id: 'sealdah', name: 'Sealdah', lat: 22.5670, lng: 88.3710, lines: [MetroLine.green]),
    MetroStation(id: 'phoolbagan', name: 'Phoolbagan', lat: 22.5725, lng: 88.3880, lines: [MetroLine.green]),
    MetroStation(id: 'sector_v', name: 'Salt Lake Sector V', lat: 22.5820, lng: 88.4310, lines: [MetroLine.green]),
    MetroStation(id: 'hemanta_mukhopadhyay', name: 'Hemanta Mukhopadhyay', lat: 22.5130, lng: 88.4030, lines: [MetroLine.orange]),
    MetroStation(id: 'joka', name: 'Joka', lat: 22.4550, lng: 88.3010, lines: [MetroLine.purple]),
    MetroStation(id: 'taratala', name: 'Taratala', lat: 22.5100, lng: 88.3180, lines: [MetroLine.purple]),
    MetroStation(id: 'majerhat', name: 'Majerhat', lat: 22.5280, lng: 88.3240, lines: [MetroLine.purple]),
  ];

  static Map<String, dynamic> calculateRoute(MetroStation start, MetroStation dest) {
    if (start.id == dest.id) return {'error': 'same_station'};
    List<String> instructions = [];
    int totalStations = 0; int fare = 10; bool hasGap = false;

    if (start.lines.contains(MetroLine.purple) && !dest.lines.contains(MetroLine.purple)) {
      hasGap = true;
      instructions.add('board_purple|${start.name}|Majerhat');
      instructions.add('gap_walk_auto|Majerhat|Kalighat|Blue Line');
      instructions.add('board_blue|Kalighat|${dest.name}');
      totalStations = 6; fare = 20; 
    } else if (start.lines.contains(MetroLine.blue) && dest.lines.contains(MetroLine.green)) {
      instructions.add('board_blue|${start.name}|Esplanade');
      instructions.add('interchange_esplanade');
      instructions.add('board_green|Esplanade|${dest.name}');
      totalStations = 8; fare = 15;
    } else {
      instructions.add('board_direct|${start.lines.first.name.toUpperCase()}|${start.name}|${dest.name}');
      totalStations = 4; fare = 10;
    }
    return {'instructions': instructions, 'time': (totalStations * 3) + (hasGap ? 15 : 5), 'fare': fare, 'hasGap': hasGap};
  }
}

// -------------------------------------------------------------
// 2. WEATHER & TIME ENGINE
// -------------------------------------------------------------
enum TimeOfDayType { day, goldenHour, night }
class WeatherEngine {
  static TimeOfDayType getCurrentTimeType() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 16) return TimeOfDayType.day;
    if (hour >= 16 && hour < 18) return TimeOfDayType.goldenHour;
    return TimeOfDayType.night;
  }
}

// -------------------------------------------------------------
// 3. CACHED TILE PROVIDER (Offline Support)
// -------------------------------------------------------------
class CachedTileProvider extends TileProvider {
  CachedTileProvider();
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) { 
    return CachedNetworkImageProvider(getTileUrl(coordinates, options), headers: headers); 
  }
}

// -------------------------------------------------------------
// 4. CUSTOM ANIMATIONS (CONFETTI & WEATHER EFFECTS)
// -------------------------------------------------------------
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const CelebrationOverlay({super.key, required this.onComplete});
  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> _particles = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 100; i++) {
      _particles.add(Offset(_rnd.nextDouble() * 400, _rnd.nextDouble() * 800));
    }
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ConfettiPainter(progress: _controller.value, particles: _particles),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Offset> particles;
  ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple];
    
    for (int i = 0; i < particles.length; i++) {
      paint.color = colors[i % colors.length].withValues(alpha: 1.0 - progress);
      double yOffset = particles[i].dy + (progress * 500); // Falling effect
      canvas.drawCircle(Offset(particles[i].dx, yOffset), 5, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// 5. MAIN APP CONFIG & GLOBAL THEME
// -------------------------------------------------------------
class HoppersApp extends StatelessWidget {
  const HoppersApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoppers Super-App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFD84315),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD84315)),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
      ),
      home: const MapScreen(), // MapScreen will be in Part 2
    );
  }
}
// =====================================================================
// HOPPERS SUPER-APP - PART 2 (MAIN UI, GPS, GAMIFICATION & MAP)
// =====================================================================
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<Marker> _mapMarkers = [];
  List<dynamic> _rawLocations = [];
  LatLng? _userLocation;
  
  final Set<String> _visitedPandals = <String>{}; 
  String _userName = 'Pujo Hopper';
  String _userAvatar = '🥳';
  int _dailyStreak = 1; 
  String _currentLang = 'en';
  late TimeOfDayType _currentTimeType;
  
  String _selectedCategory = 'all';
  double _searchRadiusKm = 15.0; 
  bool _showConfetti = false;

  // 100% Complete Trilingual Dictionary
  final Map<String, Map<String, String>> _dict = {
    'en': {
      'router': 'Smart Router', 'sos': 'Emergency SOS', 'nearby': 'Nearby Needs', 'suggest': 'Suggest Pandal',
      'language': 'Language', 'board_purple': 'Board Purple Line at {0} towards {1}.',
      'gap_walk_auto': '🚶‍♂️/🛺 Network Gap: Exit at {0}. Take Auto/Cab to {1} for {2}.',
      'board_blue': 'Board Blue Line at {0} towards {1}.',
      'interchange_esplanade': '🔄 Change line at Esplanade Interchange.',
      'board_green': 'Switch to Green Line at {0} towards {1}.',
      'board_direct': 'Board {0} Line at {1} towards {2}.',
      'find_route': 'Find Route', 'close': 'Close', 'fare': 'Fare', 'time': 'Time', 'mins': 'mins',
      'passport': 'Hopper Passport', 'achievements': 'Achievements', 'visited': 'Visited',
      'police': 'Police (100)', 'women_help': 'Women Helpline', 'ambulance': 'Ambulance (108)',
      'meetup_ping': '📍 Send Meetup Ping', 'meetup_msg': 'I am here: {0}. Let\'s meet up!',
      'cancel': 'Cancel', 'save': 'Save Changes', 'all': 'All', 'pandals': 'Pandals', 'toilets': 'Toilets'
    },
    'hi': {
      'router': 'स्मार्ट राउटर', 'sos': 'आपातकालीन मदद', 'nearby': 'आसपास की सुविधा', 'suggest': 'पंडाल सुझाव',
      'language': 'भाषा बदलें', 'board_purple': '{0} से {1} के लिए पर्पल लाइन पर चढ़ें।',
      'gap_walk_auto': '🚶‍♂️/🛺 नेटवर्क गैप: {0} पर उतरें। {2} के लिए {1} तक ऑटो/कैब लें।',
      'board_blue': '{0} से {1} के लिए ब्लू लाइन पर चढ़ें।',
      'interchange_esplanade': '🔄 एस्प्लेनेड इंटरचेंज पर लाइन बदलें।',
      'board_green': '{0} से {1} के लिए ग्रीन लाइन में बदलें।',
      'board_direct': '{1} से {2} के लिए {0} लाइन पर चढ़ें।',
      'find_route': 'रास्ता खोजें', 'close': 'बंद करें', 'fare': 'किराया', 'time': 'समय', 'mins': 'मिनट',
      'passport': 'हॉपर पासपोर्ट', 'achievements': 'उपलब्धियां', 'visited': 'देखे गए',
      'police': 'पुलिस (100)', 'women_help': 'महिला हेल्पलाइन', 'ambulance': 'एम्बुलेंस (108)',
      'meetup_ping': '📍 मीटअप पिंग भेजें', 'meetup_msg': 'मैं यहाँ हूँ: {0}. आ जाओ!',
      'cancel': 'रद्द करें', 'save': 'सेव करें', 'all': 'सभी', 'pandals': 'पंडाल', 'toilets': 'शौचालय'
    },
    'bn': {
      'router': 'স্মার্ট রাউটার', 'sos': 'জরুরী এসওএস', 'nearby': 'নিকটবর্তী', 'suggest': 'প্যান্ডেল যোগ করুন',
      'language': 'ভাষা পরিবর্তন', 'board_purple': '{0} থেকে {1} এর দিকে পার্পল লাইনে উঠুন।',
      'gap_walk_auto': '🚶‍♂️/🛺 নেটওয়ার্ক গ্যাপ: {0} এ নামুন। {2} এর জন্য {1} পর্যন্ত অটো/ক্যাব নিন।',
      'board_blue': '{0} থেকে {1} এর দিকে ব্লু লাইনে উঠুন।',
      'interchange_esplanade': '🔄 এসপ্ল্যানেড ইন্টারচেঞ্জে লাইন পরিবর্তন করুন।',
      'board_green': '{0} থেকে {1} এর দিকে গ্রীন লাইনে পরিবর্তন করুন।',
      'board_direct': '{1} থেকে {2} এর দিকে {0} লাইনে উঠুন।',
      'find_route': 'রুট খুঁজুন', 'close': 'বন্ধ করুন', 'fare': 'ভাড়া', 'time': 'সময়', 'mins': 'মিনিট',
      'passport': 'হপার পাসপোর্ট', 'achievements': 'অর্জন', 'visited': 'দর্শন করা হয়েছে',
      'police': 'পুলিশ (১০০)', 'women_help': 'মহিলা হেল্পলাইন', 'ambulance': 'অ্যাম্বুলেন্স (১০৮)',
      'meetup_ping': '📍 মিটআপ পিং পাঠান', 'meetup_msg': 'আমি এখানে আছি: {0}. দেখা করি!',
      'cancel': 'বাতিল', 'save': 'সেভ করুন', 'all': 'সব', 'pandals': 'প্যান্ডেল', 'toilets': 'শৌচালয়'
    }
  };

  String getText(String key) => _dict[_currentLang]?[key] ?? _dict['en']![key]!;

  @override
  void initState() {
    super.initState();
    _currentTimeType = WeatherEngine.getCurrentTimeType();
    _loadUserData();
    _loadLocations();
    _startLocationUpdates();
  }

  // Live GPS Distance Logic 
  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((p2.latitude - p1.latitude) * p)/2 + 
          cos(p1.latitude * p) * cos(p2.latitude * p) * 
          (1 - cos((p2.longitude - p1.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 
    setState(() { 
      _userName = prefs.getString('user_name') ?? 'Pujo Hopper'; 
      _userAvatar = prefs.getString('user_avatar') ?? '🥳'; 
      _currentLang = prefs.getString('language') ?? 'en'; 
      _dailyStreak = prefs.getInt('daily_streak') ?? 1; 
      _visitedPandals.addAll(prefs.getStringList('visited_pandals') ?? []); 
    });
  }

  Future<void> _updateProfile(String name, String avatar) async { 
    final prefs = await SharedPreferences.getInstance(); 
    if (!mounted) return; 
    setState(() { _userName = name; _userAvatar = avatar; }); 
    await prefs.setString('user_name', name); 
    await prefs.setString('user_avatar', avatar); 
  }

  Future<void> _markAsVisited(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { 
      _visitedPandals.add(id); 
      _showConfetti = true; 
    });
    await prefs.setStringList('visited_pandals', _visitedPandals.toList());
    _filterAndBuildMarkers();
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled(); 
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission(); 
    if (permission == LocationPermission.denied) { 
      permission = await Geolocator.requestPermission(); 
      if (permission == LocationPermission.denied) return; 
    } 
    Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((Position position) { 
      if (!mounted) return; 
      setState(() { _userLocation = LatLng(position.latitude, position.longitude); }); 
      if (_rawLocations.isNotEmpty) _filterAndBuildMarkers(); 
    });
  }

  Future<void> _loadLocations() async { 
    try {
      final String response = await rootBundle.loadString('assets/pandals.json'); 
      _rawLocations = jsonDecode(response); 
    } catch (e) {
      // Fallback Data
      _rawLocations = [
        {"id": "p1", "name": "Ballygunge Cultural", "lat": 22.518, "lng": 88.363, "category": "pandal", "theme": "Nari Shakti"},
        {"id": "p2", "name": "Maddox Square", "lat": 22.530, "lng": 88.358, "category": "pandal", "theme": "Traditional"},
        {"id": "t1", "name": "Public Toilet", "lat": 22.519, "lng": 88.364, "category": "toilet"}
      ];
    }
    if (!mounted) return; 
    _filterAndBuildMarkers(); 
  }

  void _filterAndBuildMarkers() {
    List<dynamic> displayList = _rawLocations;
    if (_selectedCategory != 'all') {
      displayList = displayList.where((item) => item['category'] == _selectedCategory).toList(); 
    }
    
    if (_userLocation != null && _searchRadiusKm > 0) {
      displayList = displayList.where((item) => _calculateDistance(_userLocation!, LatLng(item['lat'], item['lng'])) <= _searchRadiusKm).toList();
    }

    setState(() {
      _mapMarkers = displayList.map((item) {
        final bool isVisited = _visitedPandals.contains(item['id']);
        final Color mColor = item['category'] == 'pandal' ? (isVisited ? Colors.grey : const Color(0xFFD84315)) : Colors.purple;
        return Marker(
          point: LatLng(item['lat'], item['lng']), width: 45, height: 45, alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showPandalDetails(item),
            child: Container(
              decoration: BoxDecoration(color: mColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: Icon(item['category'] == 'pandal' ? Icons.temple_hindu : Icons.wc, color: Colors.white, size: 24),
            ),
          ),
        );
      }).toList();
    });
  }

  void _showPandalDetails(dynamic item) {
    bool isVisited = _visitedPandals.contains(item['id']);
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (item['category'] == 'pandal') Text('🎨 Theme: ${item['theme'] ?? 'Traditional'}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: isVisited ? Colors.grey : Colors.green),
                    onPressed: isVisited ? null : () {
                      Navigator.pop(context);
                      _markAsVisited(item['id']);
                    }, 
                    icon: Icon(isVisited ? Icons.check : Icons.add_task, color: Colors.white), 
                    label: Text(isVisited ? 'Visited' : 'Mark Visit', style: const TextStyle(color: Colors.white))
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${item['lat']},${item['lng']}&travelmode=walking'), mode: LaunchMode.externalApplication), 
                    icon: const Icon(Icons.directions_walk, color: Colors.white), 
                    label: const Text('Navigate', style: const TextStyle(color: Colors.white))
                  )
                ],
              )
            ],
          )
        );
      }
    );
  }

  // -------------------------------------------------------------
  // UI MODALS & DASHBOARD
  // -------------------------------------------------------------
  void _showCommandCenter() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true, crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildGridCard(Icons.subway, getText('router'), Colors.blue, () { Navigator.pop(context); _showOfflineMetroRouter(); }),
                  _buildGridCard(Icons.camera_alt, getText('suggest'), Colors.orange, () { Navigator.pop(context); _showSuggestDialog(); }),
                  _buildGridCard(Icons.sos, getText('sos'), Colors.red, () { Navigator.pop(context); _showEmergencySheet(); }),
                  _buildGridCard(Icons.language, getText('language'), Colors.teal, () async {
                    setState(() { _currentLang = _currentLang == 'en' ? 'hi' : (_currentLang == 'hi' ? 'bn' : 'en'); });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('language', _currentLang);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }),
                ],
              )
            ],
          )
        );
      }
    );
  }

  Widget _buildGridCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 36, color: color), const SizedBox(height: 10), Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13))],
        ),
      ),
    );
  }

  void _showOfflineMetroRouter() {
    MetroStation? selectedFrom, selectedTo; Map<String, dynamic>? routeResult;
    showDialog(
      context: context, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setDialogState) { 
            return AlertDialog(
              backgroundColor: Colors.white, title: Row(children: [const Icon(Icons.subway, color: Colors.blue, size: 28), const SizedBox(width: 8), Text(getText('router'))]), 
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButton<MetroStation>(
                        isExpanded: true, underline: const SizedBox(), hint: const Text('From Station'), value: selectedFrom,
                        items: MetroRouterService.masterStations.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), 
                        onChanged: (val) => setDialogState(() { selectedFrom = val; routeResult = null; })
                      )
                    ), 
                    const SizedBox(height: 10), 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButton<MetroStation>(
                        isExpanded: true, underline: const SizedBox(), hint: const Text('To Station'), value: selectedTo, 
                        items: MetroRouterService.masterStations.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), 
                        onChanged: (val) => setDialogState(() { selectedTo = val; routeResult = null; })
                      )
                    ),
                    const SizedBox(height: 15), 
                    if (routeResult != null && !routeResult!.containsKey('error'))
                      Container(
                        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text('💰 ${getText('fare')}: ₹${routeResult!['fare']}  |  ⏳ ${getText('time')}: ~${routeResult!['time']} ${getText('mins')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), 
                            const Divider(), 
                            ...(routeResult!['instructions'] as List<String>).map((inst) {
                              List<String> parts = inst.split('|');
                              String translated = getText(parts[0]);
                              for (int i = 1; i < parts.length; i++) { translated = translated.replaceAll('{${i - 1}}', parts[i]); }
                              return Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $translated', style: const TextStyle(fontSize: 13, height: 1.3)));
                            })
                          ]
                        )
                      )
                  ]
                )
              ), 
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('close'))), 
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () { if (selectedFrom != null && selectedTo != null) { setDialogState(() { routeResult = MetroRouterService.calculateRoute(selectedFrom!, selectedTo!); }); } }, 
                  child: Text(getText('find_route'), style: const TextStyle(color: Colors.white))
                )
              ]
            ); 
          }
        ); 
      }
    );
  }

  void _showNearbySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(getText('nearby'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Divider(),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  ActionChip(label: Text(getText('all')), onPressed: () { setState(() { _selectedCategory = 'all'; _searchRadiusKm = 15.0; }); _filterAndBuildMarkers(); Navigator.pop(context); }),
                  ActionChip(label: Text(getText('pandals')), backgroundColor: Colors.orange.shade100, onPressed: () { setState(() { _selectedCategory = 'pandal'; _searchRadiusKm = 5.0; }); _filterAndBuildMarkers(); Navigator.pop(context); }),
                  ActionChip(label: Text(getText('toilets')), backgroundColor: Colors.purple.shade100, onPressed: () { setState(() { _selectedCategory = 'toilet'; _searchRadiusKm = 2.0; }); _filterAndBuildMarkers(); Navigator.pop(context); }),
                ],
              )
            ],
          )
        );
      }
    );
  }

  void _showEmergencySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(getText('sos'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)), const Divider(),
              ListTile(leading: const Icon(Icons.local_police, color: Colors.blue), title: Text(getText('police')), onTap: () => launchUrl(Uri(scheme: 'tel', path: '100'))),
              ListTile(leading: const Icon(Icons.woman, color: Colors.pink), title: Text(getText('women_help')), onTap: () => launchUrl(Uri(scheme: 'tel', path: '1090'))),
              ListTile(leading: const Icon(Icons.medical_services, color: Colors.green), title: Text(getText('ambulance')), onTap: () => launchUrl(Uri(scheme: 'tel', path: '108'))),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_location, color: Colors.orange), title: Text(getText('meetup_ping'), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  if (_userLocation != null) {
                    String url = "https://wa.me/?text=${Uri.encodeComponent(getText('meetup_msg').replaceAll('{0}', 'https://maps.google.com/?q=${_userLocation!.latitude},${_userLocation!.longitude}'))}";
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                }
              ),
            ],
          )
        );
      }
    );
  }

  void _showProfileDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName); 
    showDialog(
      context: context, 
      builder: (context) { 
        return AlertDialog(
          backgroundColor: Colors.white, title: Text(getText('passport')), 
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text(_userAvatar, style: const TextStyle(fontSize: 50)), const SizedBox(height: 10), 
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nickname')), const SizedBox(height: 15), 
              Text('🔥 $_dailyStreak Day Streak', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD84315))), 
              const SizedBox(height: 10), Text('🏆 ${getText('achievements')} (${_visitedPandals.length})', style: const TextStyle(fontWeight: FontWeight.bold)), 
            ]
          ), 
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('cancel'))), 
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315)),
              onPressed: () { _updateProfile(nameController.text.trim(), _userAvatar); Navigator.pop(context); }, 
              child: Text(getText('save'), style: const TextStyle(color: Colors.white))
            )
          ]
        ); 
      }
    );
  }

  void _showSuggestDialog() { 
    final TextEditingController nameController = TextEditingController(); 
    XFile? selectedImage; final ImagePicker picker = ImagePicker(); bool isSubmitting = false;
    showDialog(
      context: context, barrierDismissible: false, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setDialogState) { 
            return AlertDialog(
              backgroundColor: Colors.white, title: Text(getText('suggest')), 
              content: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Pandal Name')), const SizedBox(height: 15), 
                  OutlinedButton.icon(
                    onPressed: isSubmitting ? null : () async { final XFile? img = await picker.pickImage(source: ImageSource.camera, imageQuality: 40); if (img != null) setDialogState(() { selectedImage = img; }); }, 
                    icon: const Icon(Icons.photo_camera), label: Text(selectedImage == null ? 'Attach Photo' : 'Photo Attached')
                  ), 
                ]
              ), 
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: Text(getText('close'))), 
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315)),
                  onPressed: isSubmitting ? null : () async { 
                    if (_userLocation == null || nameController.text.isEmpty || selectedImage == null) return; 
                    setDialogState(() { isSubmitting = true; });
                    try {
                      String base64Image = base64Encode(await selectedImage!.readAsBytes());
                      await http.post(Uri.parse('https://script.google.com/macros/s/AKfycbywe_z5bzvG2PTN1p87Js8Dq8Jgk4hzfsnlRz6EHppXVcQc3irecv4rJ1dDiQ-LzjgkaA/exec'), body: jsonEncode({"pandalName": nameController.text.trim(), "latitude": _userLocation!.latitude, "longitude": _userLocation!.longitude, "image64": base64Image}));
                    } catch (e) { debugPrint(e.toString()); }
                    if (context.mounted) Navigator.pop(context);
                  }, 
                  child: isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white))
                )
              ]
            ); 
          }
        ); 
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isNight = _currentTimeType == TimeOfDayType.night;
    bool isGoldenHour = _currentTimeType == TimeOfDayType.goldenHour;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, options: const MapOptions(initialCenter: LatLng(22.5650, 88.3620), initialZoom: 12.5), 
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.bikki.hoppers', tileProvider: CachedTileProvider()),
              if (isNight) IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.55))),
              if (isGoldenHour) IgnorePointer(child: Container(color: Colors.deepOrange.withValues(alpha: 0.15))),
              MarkerLayer(markers: [
                ..._mapMarkers, 
                if (_userLocation != null) Marker(point: _userLocation!, width: 20, height: 20, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))))
              ])
            ],
          ),
          
          if (_showConfetti) CelebrationOverlay(onComplete: () { setState(() { _showConfetti = false; }); }),

          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFD84315), isNight ? const Color(0xFF8E24AA) : const Color(0x00FF8A65)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              padding: const EdgeInsets.only(top: 50, left: 20),
              child: const Text('Hoppers', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD84315),
        onPressed: _showCommandCenter,
        elevation: 8,
        child: const Icon(Icons.explore, color: Colors.white, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: isNight ? Colors.grey.shade900 : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: Icon(Icons.home, color: isNight ? Colors.white70 : Colors.grey.shade700), onPressed: () {}),
            IconButton(icon: Icon(Icons.sos, color: isNight ? Colors.white70 : Colors.grey.shade700), onPressed: _showEmergencySheet),
            const SizedBox(width: 40), 
            IconButton(icon: Icon(Icons.near_me, color: isNight ? Colors.white70 : Colors.grey.shade700), onPressed: _showNearbySheet),
            IconButton(icon: Icon(Icons.person, color: isNight ? Colors.white70 : Colors.grey.shade700), onPressed: _showProfileDialog),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const HoppersApp());
}

// -------------------------------------------------------------
// WEATHER & TIME LOGIC
// -------------------------------------------------------------
enum TimeOfDayType { day, goldenHour, night }
enum WeatherType { clear, rain, thunderstorm }

class WeatherEngine {
  static TimeOfDayType getCurrentTimeType() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 16) return TimeOfDayType.day;
    if (hour >= 16 && hour < 18) return TimeOfDayType.goldenHour;
    return TimeOfDayType.night;
  }

  static WeatherType getCurrentWeather() {
    // For demonstration of your awesome idea: Randomly simulating rain/thunder sometimes 
    // Currently forced to 'thunderstorm' to showcase the effect!
    return WeatherType.thunderstorm; 
  }
}

// -------------------------------------------------------------
// UI WIDGETS
// -------------------------------------------------------------

class SmoothMarqueeWidget extends StatefulWidget {
  final Widget child;
  const SmoothMarqueeWidget({super.key, required this.child});
  @override
  State<SmoothMarqueeWidget> createState() => _SmoothMarqueeWidgetState();
}

class _SmoothMarqueeWidgetState extends State<SmoothMarqueeWidget> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker((_) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.5);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ticker.start());
  }
  @override
  void dispose() { _ticker.dispose(); _scrollController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), scrollDirection: Axis.horizontal, controller: _scrollController, child: widget.child); }
}

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key});
  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final List<Map<String, dynamic>> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500)); 
    for (int i = 0; i < 40; i++) { 
      _particles.add({
        'x': _random.nextDouble() * 400 - 200, 
        'startY': -50.0 - (_random.nextDouble() * 100), 
        'endY': 600.0 + (_random.nextDouble() * 300), 
        'icon': _random.nextBool() ? '🎉' : '✨',
        'size': _random.nextDouble() * 20 + 15,
        'delay': _random.nextDouble() * 0.5, 
      });
    }
    _controller.forward();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer( 
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.topCenter,
            children: _particles.map((p) {
              double progress = (_controller.value - p['delay']).clamp(0.0, 1.0);
              double currentY = p['startY'] + (p['endY'] - p['startY']) * progress;
              return Transform.translate(offset: Offset(p['x'], currentY), child: Opacity(opacity: progress > 0.8 ? (1.0 - ((progress - 0.8) * 5)) : (progress < 0.1 ? progress * 10 : 1.0), child: Text(p['icon'], style: TextStyle(fontSize: p['size']))));
            }).toList(),
          );
        },
      ),
    );
  }
}

// ⚡ Masha Allah Lightning & Rain Overlay!
class WeatherOverlay extends StatefulWidget {
  final WeatherType weatherType;
  const WeatherOverlay({super.key, required this.weatherType});
  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay> with TickerProviderStateMixin {
  late AnimationController _rainController;
  late AnimationController _lightningController;
  final Random _random = Random();
  final List<Map<String, dynamic>> _raindrops = [];

  @override
  void initState() {
    super.initState();
    _rainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    for (int i = 0; i < 60; i++) {
      _raindrops.add({
        'x': _random.nextDouble() * 500 - 50,
        'speed': _random.nextDouble() * 1.5 + 1.0,
        'length': _random.nextDouble() * 15 + 10,
        'delay': _random.nextDouble(),
      });
    }
    _lightningController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _triggerLightning();
  }

  void _triggerLightning() async {
    if (!mounted || widget.weatherType != WeatherType.thunderstorm) return;
    await Future.delayed(Duration(seconds: _random.nextInt(8) + 3)); 
    if (!mounted) return;
    _lightningController.forward(from: 0.0);
    _triggerLightning();
  }

  @override
  void dispose() { _rainController.dispose(); _lightningController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.weatherType == WeatherType.clear) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          if (widget.weatherType == WeatherType.thunderstorm)
            AnimatedBuilder(
              animation: _lightningController,
              builder: (context, child) {
                double opacity = 0;
                if (_lightningController.value > 0 && _lightningController.value < 0.2) opacity = 0.8;
                if (_lightningController.value > 0.3 && _lightningController.value < 0.5) opacity = 0.5;
                return Container(color: Colors.white.withOpacity(opacity));
              },
            ),
          AnimatedBuilder(
            animation: _rainController,
            builder: (context, child) {
              return Stack(
                children: _raindrops.map((drop) {
                  double progress = (_rainController.value + drop['delay']) % 1.0;
                  double y = progress * 1000 - 100;
                  return Positioned(
                    left: drop['x'], top: y,
                    child: Container(
                      width: 1.5, height: drop['length'],
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CachedTileProvider extends TileProvider {
  CachedTileProvider();
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) { return CachedNetworkImageProvider(getTileUrl(coordinates, options), headers: headers); }
}

class PandalTrail {
  final String id, titleKey, descKey; final Color color; final bool isOneWay; final List<LatLng> points;
  PandalTrail(this.id, this.titleKey, this.descKey, this.color, this.isOneWay, this.points);
}

class HoppersApp extends StatelessWidget {
  const HoppersApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hoppers Pujo Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        primaryColor: const Color(0xFFD84315), 
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD84315)),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Marker> _mapMarkers = [];
  List<dynamic> _rawLocations = [];
  LatLng? _userLocation;
  final Set<String> _visitedPandals = <String>{}; 
  
  String _userName = 'Pujo Hopper';
  String _userAvatar = '🥳';
  String _uniqueHopperId = '';
  int _dailyStreak = 1; 
  bool _showCelebration = false;
  
  PandalTrail? _activeTrail;
  bool _hasSeenInstallPrompt = false;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  
  late TimeOfDayType _currentTimeType;
  late WeatherType _currentWeather;
  
  final List<PandalTrail> _pujoTrails = [
    PandalTrail('south_1', 'south_trail', 'trail_desc_south', Colors.blue, true, [const LatLng(22.5175, 88.3582), const LatLng(22.5193, 88.3639), const LatLng(22.5113, 88.3475)]),
    PandalTrail('north_1', 'north_trail', 'trail_desc_north', Colors.purple, true, [const LatLng(22.6025, 88.3675), const LatLng(22.5990, 88.3620), const LatLng(22.5940, 88.3590)])
  ];

  String _currentLang = 'en';

  final Map<String, Map<String, String>> _dict = {
    'en': {
      'app_title': 'Hoppers', 'all': 'All', 'pandals': 'Pandals', 'police': 'Police',
      'toilets': 'Toilets', 'parking': 'Parking', 'bars': 'Bars', 'veg_food': 'Veg Food', 'nonveg_food': 'Non-Veg', 'gates': 'Gates',
      'suggest': 'Suggest Pandal', 'visited': 'Visited', 'mark_visited': 'Mark as Visited', 'undo_visited': 'Visited (Tap to Undo)',
      'close': 'Close', 'category': 'Category', 'meters': 'meters away', 'km': 'km away', 'unknown_dist': 'Distance unknown',
      'passport': 'Hopper Passport', 'achievements': 'Achievements', 'cancel': 'Cancel', 'save': 'Save Changes',
      'emergency': 'Emergency Helplines', 'transit': 'Commute Guide', 'find_route': 'Find Route', 'from_stn': 'From Station', 'to_stn': 'To Station',
      'open_router': 'Open Smart Metro Router', 'choose_lang': 'Choose Language', 'women_help': 'Women Helpline', 'ambulance': 'Medical & Ambulance',
      'suggest_desc': 'Help the community by adding your local pandal with a photo and GPS location!',
      'pandal_name': 'Pandal Name', 'submit': 'Submit', 'attach_photo': 'Attach Pandal Photo', 'photo_attached': 'Photo Attached!',
      'traffic_alert': '⚠️ Live KP Traffic Updates & No-Entry timings will be updated here soon.',
      'kp_advisory_title': '🚓 Kolkata Police Traffic Advisory', 'kp_advisory_desc': 'Awaiting official guidelines. Pedestrian-only zones and vehicle diversions will be listed here before Mahalaya.',
      'trails': 'Trails', 'clear_trail': 'Clear Trail', 'south_trail': 'South Heritage Walk', 'north_trail': 'North Classic Walk',
      'trail_desc_south': 'Deshapriya ➔ Singhi Park ➔ Mudiali', 'trail_desc_north': 'Bagbazar ➔ Kumartuli ➔ Ahiritola',
      'one_way': '⛔ ONE-WAY ONLY', 'one_way_desc': 'Police barricades active. Follow the exact sequence, do not walk back!',
      'crowd_peak': 'Peak Crowd (1-2 hr wait)', 'crowd_mod': 'Moderate Crowd (Moving)', 'crowd_low': 'Low Crowd (Best Time)',
      'take_me_there': 'Take Me There', 'share_whatsapp': 'Share on WhatsApp', 'theme': 'Theme', 'nearest_metro': 'Nearest Metro',
      'share_text': "Let's check out {pandal} tonight! Navigate here on Hoppers: {url}",
      'update': 'Update', 'report_crowd': 'Report Current Crowd', 'thanks_report': 'Thanks! Your report helps the Hopper community.',
      'search_hint': 'Find your hopping destiny...', 'search_empty': 'No pandals found.',
    },
    'hi': {
      'app_title': 'हॉपर्स', 'all': 'सभी', 'pandals': 'पंडाल', 'police': 'पुलिस',
      'toilets': 'शौचालय', 'parking': 'पार्किंग', 'bars': 'बार', 'veg_food': 'शाकाहारी खाना', 'nonveg_food': 'मांसाहारी', 'gates': 'गेट',
      'suggest': 'पंडाल सुझाएं', 'visited': 'देखे गए', 'mark_visited': 'गए हुए मार्क करें', 'undo_visited': 'देखा गया (हटाने के लिए टैप करें)',
      'close': 'बंद करें', 'category': 'श्रेणी', 'meters': 'मीटर दूर', 'km': 'किमी दूर', 'unknown_dist': 'दूरी अज्ञात',
      'passport': 'हॉपर पासपोर्ट', 'achievements': 'उपलब्धियां', 'cancel': 'रद्द करें', 'save': 'सेव करें',
      'emergency': 'आपातकालीन हेल्पलाइन', 'transit': 'यात्रा गाइड', 'find_route': 'रास्ता खोजें', 'from_stn': 'कहाँ से', 'to_stn': 'कहाँ तक',
      'open_router': 'स्मार्ट मेट्रो राउटर खोलें', 'choose_lang': 'भाषा चुनें', 'women_help': 'महिला हेल्पलाइन', 'ambulance': 'एम्बुलेंस',
      'suggest_desc': 'फोटो और जीपीएस लोकेशन के साथ अपना स्थानीय पंडाल जोड़कर समुदाय की मदद करें!',
      'pandal_name': 'पंडाल का नाम', 'submit': 'सबमिट करें', 'attach_photo': 'फोटो जोड़ें', 'photo_attached': 'फोटो जुड़ गई!',
      'traffic_alert': '⚠️ लाइव KP ट्रैफिक अपडेट और नो-एंट्री का समय जल्द ही यहाँ अपडेट किया जाएगा।',
      'kp_advisory_title': '🚓 कोलकाता पुलिस ट्रैफिक एडवाइजरी', 'kp_advisory_desc': 'आधिकारिक गाइडलाइंस का इंतज़ार है। पैदल यात्री ज़ोन और वाहन डायवर्जन महालया से पहले यहाँ अपडेट किए जाएंगे।',
      'trails': 'ट्रेल्स', 'clear_trail': 'ट्रेल हटाएं', 'south_trail': 'दक्षिण हेरिटेज वॉक', 'north_trail': 'उत्तर क्लासिक वॉक',
      'trail_desc_south': 'देशप्रिय ➔ सिंही पार्क ➔ मुदियाली', 'trail_desc_north': 'बागबाज़ार ➔ कुमारटुली ➔ अहीरीटोला',
      'one_way': '⛔ सिर्फ एक-तरफ़ा (One-Way)', 'one_way_desc': 'पुलिस बैरिकेडिंग चालू है। इसी क्रम में चलें, वापस न लौटें!',
      'crowd_peak': 'भारी भीड़ (1-2 घंटे इंतज़ार)', 'crowd_mod': 'मध्यम भीड़ (चलने लायक)', 'crowd_low': 'कम भीड़ (सबसे अच्छा समय)',
      'take_me_there': 'रास्ता दिखाएं', 'share_whatsapp': 'WhatsApp पर शेयर करें', 'theme': 'थीम', 'nearest_metro': 'निकटतम मेट्रो',
      'share_text': "आज रात {pandal} चलते हैं! Hoppers पर यहाँ नेविगेट करें: {url}",
      'update': 'अपडेट', 'report_crowd': 'भीड़ की रिपोर्ट करें', 'thanks_report': 'धन्यवाद! आपकी रिपोर्ट से समुदाय को मदद मिलेगी।',
      'search_hint': 'अपना डेस्टिनी खोजें...', 'search_empty': 'कोई पंडाल नहीं मिला।',
    },
    'bn': {
      'app_title': 'হপার্স', 'all': 'সব', 'pandals': 'প্যান্ডেল', 'police': 'পুলিশ',
      'toilets': 'শৌচালয়', 'parking': 'পার্কিং', 'bars': 'বার', 'veg_food': 'নিরামিষ খাবার', 'nonveg_food': 'আমিষ', 'gates': 'গেট',
      'suggest': 'প্যান্ডেল সাজেস্ট করুন', 'visited': 'ঘুরেছি', 'mark_visited': 'ঘুরেছি মার্ক করুন', 'undo_visited': 'ঘুরেছি (আনডু করতে ট্যাপ করুন)',
      'close': 'বন্ধ করুন', 'category': 'বিভাগ', 'meters': 'মিটার দূরে', 'km': 'কিমি দূরে', 'unknown_dist': 'দূরত্ব অজানা',
      'passport': 'হপার পাসপোর্ট', 'achievements': 'কৃতিত্ব', 'cancel': 'বাতিল করুন', 'save': 'সেভ করুন',
      'emergency': 'জরুরী হেল্পলাইন', 'transit': 'যাতায়াত গাইড', 'find_route': 'রুট খুঁজুন', 'from_stn': 'কোথা থেকে', 'to_stn': 'কোথায় যাবেন',
      'open_router': 'স্মার্ট মেট্রো রাউটার খুলুন', 'choose_lang': 'ভাষা নির্বাচন করুন', 'women_help': 'মহিলা হেল্পলাইন', 'ambulance': 'অ্যাম্বুলেন্স',
      'suggest_desc': 'ছবি এবং জিপিএস লোকেশন দিয়ে আপনার স্থানীয় প্যান্ডেল যোগ করে কমিউনিটিকে সাহায্য করুন!',
      'pandal_name': 'প্যান্ডেলের নাম', 'submit': 'জমা দিন', 'attach_photo': 'ছবি যোগ করুন', 'photo_attached': 'ছবি যুক্ত হয়েছে!',
      'traffic_alert': '⚠️ লাইভ কেপি (KP) ট্রাফিক আপডেট এবং নো-এন্ট্রি সময়সূচী শীঘ্রই এখানে আপডেট করা হবে।',
      'kp_advisory_title': '🚓 কলকাতা পুলিশ ট্রাফিক অ্যাডভাইজরি', 'kp_advisory_desc': 'অফিসিয়াল নির্দেশিকার অপেক্ষায়। শুধুমাত্র পথচারীদের জোন এবং গাড়ির ডাইভারশন মহালয়ার আগে এখানে দেওয়া হবে।',
      'trails': 'ট্রেইল', 'clear_trail': 'ট্রেইল মুছুন', 'south_trail': 'দক্ষিণ হেরিটেজ ওয়াক', 'north_trail': 'উত্তর ক্লাসিক ওয়াক',
      'trail_desc_south': 'দেশপ্রিয় ➔ সিংহী পার্ক ➔ মুদিয়ালি', 'trail_desc_north': 'বাগবাজার ➔ কুমারটুলি ➔ আহিরীটোলা',
      'one_way': '⛔ শুধুমাত্র একমুখী (One-Way)', 'one_way_desc': 'পুলিশ ব্যারিকেড সক্রিয়। ক্রম অনুসরণ করুন, পিছনে হাঁটবেন গঠন!',
      'crowd_peak': 'প্রচণ্ড ভিড় (১-২ ঘণ্টা অপেক্ষা)', 'crowd_mod': 'মাঝারি ভিড় (চলনসই)', 'crowd_low': 'কম ভিড় (সেরা সময়)',
      'take_me_there': 'রাস্তা দেখান', 'share_whatsapp': 'WhatsApp-এ শেয়ার করুন', 'theme': 'থিম', 'nearest_metro': 'নিকটতম মেট্রো',
      'share_text': "আজ রাতে {pandal} চলো! Hoppers-এ এখানে নেভিগেট করুন: {url}",
      'update': 'আপডেট', 'report_crowd': 'ভিড়ের রিপোর্ট করুন', 'thanks_report': 'ধন্যবাদ! আপনার রিপোর্ট কমিউনিটিকে সাহায্য করবে।',
      'search_hint': 'আপনার ডেস্টিনি খুঁজুন...', 'search_empty': 'কোন প্যান্ডেল পাওয়া যায়নি।',
    }
  };

  String getText(String key) => _dict[_currentLang]?[key] ?? _dict['en']![key]!;

  String _selectedCategory = 'pandal';
  final double _searchRadiusKm = 50.0; 

  final List<String> _blueLine = ['Dakshineswar', 'Baranagar', 'Noapara', 'Dum Dum', 'Belgachia', 'Shyambazar', 'Shobhabazar Sutanuti', 'Girish Park', 'Mahatma Gandhi Road', 'Central', 'Chandni Chowk', 'Esplanade', 'Park Street', 'Maidan', 'Rabindra Sadan', 'Netaji Bhavan', 'Jatin Das Park', 'Kalighat', 'Rabindra Sarobar', 'Mahanayak Uttam Kumar', 'Netaji', 'Masterda Surya Sen', 'Gitanjali', 'Kavi Nazrul', 'Shahid Khudiram', 'Kavi Subhash'];
  final List<String> _greenLineWest = ['Howrah Maidan', 'Howrah', 'Mahakaran', 'Esplanade'];
  final List<String> _greenLineEast = ['Sealdah', 'Phoolbagan', 'Salt Lake Stadium', 'Bengal Chemical', 'City Centre', 'Central Park', 'Karunamoyee', 'Salt Lake Sector V'];
  final List<String> _orangeLine = ['Kavi Subhash', 'Satyajit Ray', 'Jyotirindra Nandi', 'Kavi Sukanta', 'Hemanta Mukhopadhyay'];
  final List<String> _purpleLine = ['Joka', 'Thakurpukur', 'Sakherbazar', 'Behala Chowrasta', 'Behala Bazar', 'Taratala', 'Majerhat'];
  List<String> _allStations = [];

  @override
  void initState() {
    super.initState();
    _currentTimeType = WeatherEngine.getCurrentTimeType();
    _currentWeather = WeatherEngine.getCurrentWeather();
    _loadUserData();
    _loadLocations();
    _startLocationUpdates();
    _allStations = [..._blueLine, ..._greenLineWest, ..._greenLineEast, ..._orangeLine, ..._purpleLine].toSet().toList()..sort(); 
    
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenInstallPrompt = prefs.getBool('seen_install_prompt') ?? false;
      if (!_hasSeenInstallPrompt) {
        Future.delayed(const Duration(seconds: 5), _showInstallPrompt);
      }
    });
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _searchResults = [];
        _isSearching = false;
      } else {
        _isSearching = true;
        _searchResults = _rawLocations.where((item) {
          String name = item['name'].toString().toLowerCase();
          String theme = (item['theme'] ?? '').toString().toLowerCase();
          return (name.contains(query) || theme.contains(query)) && item['category'] == 'pandal';
        }).toList();
      }
    });
  }

  void _triggerDestiny() {
    if (_rawLocations.isEmpty) return;
    List<dynamic> pandals = _rawLocations.where((item) => item['category'] == 'pandal').toList();
    if (pandals.isEmpty) return;
    
    final randomPandal = pandals[Random().nextInt(pandals.length)];
    FocusScope.of(context).unfocus(); 
    _searchController.clear();
    
    _mapController.move(LatLng(randomPandal['lat'], randomPandal['lng']), 15.0);
    _showLocationDetails(randomPandal);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🎲 Destiny selected: ${randomPandal['name']}!'),
      backgroundColor: const Color(0xFFD84315),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  String _getStationWithEmoji(String station) {
    if (_blueLine.contains(station)) return '🔵 $station';
    if (_greenLineWest.contains(station)) return '🟢 $station';
    if (_greenLineEast.contains(station)) return '🟢 $station';
    if (_orangeLine.contains(station)) return '🟠 $station';
    if (_purpleLine.contains(station)) return '🟣 $station';
    return station;
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 
    String lastDateStr = prefs.getString('last_open_date') ?? '';
    DateTime now = DateTime.now();
    String todayStr = "${now.year}-${now.month}-${now.day}";
    int savedStreak = prefs.getInt('daily_streak') ?? 1;

    if (lastDateStr.isNotEmpty && lastDateStr != todayStr) {
      DateTime lastDate = DateTime.parse(lastDateStr);
      DateTime today = DateTime(now.year, now.month, now.day);
      int diff = today.difference(lastDate).inDays;
      if (diff == 1) { savedStreak += 1; } 
      else if (diff > 1) { savedStreak = 1; }
    }
    prefs.setString('last_open_date', todayStr);
    prefs.setInt('daily_streak', savedStreak);

    setState(() {
      _userName = prefs.getString('user_name') ?? 'Pujo Hopper';
      _userAvatar = prefs.getString('user_avatar') ?? '🥳';
      _currentLang = prefs.getString('language') ?? 'en'; 
      _dailyStreak = savedStreak;
      _uniqueHopperId = prefs.getString('hopper_id') ?? '';
      if (_uniqueHopperId.isEmpty) { _uniqueHopperId = 'HP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'; prefs.setString('hopper_id', _uniqueHopperId); }
      _visitedPandals.addAll(prefs.getStringList('visited_pandals') ?? []);
    });
  }

  Future<void> _setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 
    setState(() { _currentLang = langCode; });
    prefs.setString('language', langCode);
    Navigator.pop(context);
    _filterAndBuildMarkers(); 
  }

  Future<void> _saveVisitedData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('visited_pandals', _visitedPandals.toList());
  }

  Future<void> _updateProfile(String name, String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 
    setState(() { _userName = name; _userAvatar = avatar; });
    prefs.setString('user_name', name); prefs.setString('user_avatar', avatar);
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) { permission = await Geolocator.requestPermission(); if (permission == LocationPermission.denied) return; }
    if (permission == LocationPermission.deniedForever) return;
    Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((Position position) {
      if (!mounted) return;
      setState(() { _userLocation = LatLng(position.latitude, position.longitude); });
      if (_rawLocations.isNotEmpty) _filterAndBuildMarkers();
    });
  }

  Future<void> _launchMapsUrl(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _shareOnWhatsApp(String pandalName, double lat, double lng) async {
    String message = getText('share_text').replaceAll('{pandal}', pandalName).replaceAll('{url}', 'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final url = "https://wa.me/?text=${Uri.encodeComponent(message)}";
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'pandal': return Icons.temple_hindu;
      case 'police': return Icons.local_police;
      case 'toilet': return Icons.wc;
      case 'gate': return Icons.login;
      case 'veg_restaurant': return Icons.restaurant;
      case 'nonveg_restaurant': return Icons.fastfood;
      case 'bar': return Icons.local_bar;
      case 'parking': return Icons.local_parking;
      default: return Icons.location_on;
    }
  }

  Color _getColorForCategory(String category, bool isVisited) {
    if (category == 'pandal' && isVisited) return Colors.grey; 
    switch (category) {
      case 'pandal': return const Color(0xFFD84315); 
      case 'police': return Colors.blue;
      case 'toilet': return Colors.purple;
      case 'gate': return Colors.amber.shade800;
      case 'veg_restaurant': return Colors.green.shade700;
      case 'nonveg_restaurant': return Colors.brown;
      case 'bar': return Colors.indigo;
      case 'parking': return Colors.teal;
      default: return Colors.red;
    }
  }

  String _calculateDistance(double destLat, double destLng) {
    if (_userLocation == null) return getText('unknown_dist');
    double distanceInMeters = Geolocator.distanceBetween(_userLocation!.latitude, _userLocation!.longitude, destLat, destLng);
    if (distanceInMeters < 1000) return '${distanceInMeters.toStringAsFixed(0)} ${getText('meters')}';
    return '${(distanceInMeters / 1000).toStringAsFixed(1)} ${getText('km')}';
  }

  String _getDynamicCrowdPrediction() {
    int hour = DateTime.now().hour;
    if (hour >= 17 || hour <= 2) return getText('crowd_peak');
    if (hour >= 11 && hour < 17) return getText('crowd_mod');
    return getText('crowd_low');
  }

  void _triggerCelebration() {
    setState(() { _showCelebration = true; });
    Future.delayed(const Duration(seconds: 2, milliseconds: 500), () { if (mounted) setState(() { _showCelebration = false; }); });
  }

  Future<void> _loadLocations() async {
    final String response = await rootBundle.loadString('assets/pandals.json');
    _rawLocations = jsonDecode(response);
    if (!mounted) return; 
    _filterAndBuildMarkers();
  }

  void _filterAndBuildMarkers() {
    List<dynamic> displayList = _rawLocations;
    if (_selectedCategory != 'all') { displayList = displayList.where((item) => item['category'] == _selectedCategory).toList(); }
    if (_userLocation != null) {
      displayList = displayList.where((item) {
        String cat = item['category'];
        if (cat != 'pandal' && cat != 'veg_restaurant' && cat != 'nonveg_restaurant') return true;
        double dist = Geolocator.distanceBetween(_userLocation!.latitude, _userLocation!.longitude, item['lat'], item['lng']);
        return (dist / 1000) <= _searchRadiusKm;
      }).toList();
    }
    
    setState(() {
      _mapMarkers = displayList.map((item) {
        final String id = item['id']; final String cat = item['category']; final bool isVisited = _visitedPandals.contains(id);
        bool isNight = _currentTimeType == TimeOfDayType.night;
        double markerSize = (cat == 'pandal') ? 55.0 : 40.0;
        double iconSize = (cat == 'pandal') ? 28.0 : 20.0;

        return Marker(
          point: LatLng(item['lat'], item['lng']),
          width: markerSize, height: markerSize, alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _showLocationDetails(item),
            child: Container(
              decoration: BoxDecoration(
                color: _getColorForCategory(cat, isVisited), shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isNight ? 1.5 : 2.0),
                boxShadow: isNight ? [BoxShadow(color: _getColorForCategory(cat, isVisited).withOpacity(0.8), blurRadius: 15, spreadRadius: 3)] : [BoxShadow(color: _getColorForCategory(cat, isVisited).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
              ),
              child: Icon(isVisited && cat == 'pandal' ? Icons.check : _getIconForCategory(cat), color: Colors.white, size: iconSize),
            ),
          ),
        );
      }).toList();
    });
  }

  void _showAchievementPopup(String title, String message, IconData iconData, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder(duration: const Duration(milliseconds: 600), tween: Tween<double>(begin: 0, end: 1), builder: (context, double val, child) { return Transform.scale(scale: val, child: Icon(iconData, size: 80, color: color)); }),
            const SizedBox(height: 16), Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
            const SizedBox(height: 8), Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(context), child: const Text('Awesome!'))
          ],
        ),
      ),
    );
  }

  void _showLocationDetails(Map<String, dynamic> item) {
    final String id = item['id']; final String name = item['name']; final String category = item['category'];
    bool isVisited = _visitedPandals.contains(id); String distanceText = _calculateDistance(item['lat'], item['lng']);
    String dynamicCrowd = (category == 'pandal') ? _getDynamicCrowdPrediction() : 'Normal';
    String theme = item['theme'] ?? ''; String crowdHours = item['crowd_hours'] ?? ''; String nearestMetro = item['nearest_metro'] ?? '';
    String displayCrowd = crowdHours.isNotEmpty ? crowdHours : dynamicCrowd;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.55, minChildSize: 0.4, maxChildSize: 0.9,
              builder: (_, controller) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10), padding: const EdgeInsets.all(0),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)]),
                  child: ListView(
                    controller: controller,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD84315), Color(0xFFFF8A65)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        child: Column(
                          children: [
                            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10)))),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                CircleAvatar(backgroundColor: Colors.white, radius: 30, child: Icon(_getIconForCategory(category), color: _getColorForCategory(category, isVisited), size: 30)),
                                const SizedBox(width: 16),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2, color: Colors.white)), const SizedBox(height: 4), Text('📍 $distanceText', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.category, size: 18, color: Color(0xFFD84315)), const SizedBox(width: 8), Expanded(child: Text('${getText('category')}: ${category.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)))]),
                                  if (theme.isNotEmpty) ...[const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.palette, size: 18, color: Color(0xFFD84315)), const SizedBox(width: 8), Expanded(child: Text('${getText('theme')}: $theme', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)))])],
                                  if (nearestMetro.isNotEmpty) ...[const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.subway, size: 18, color: Colors.blue), const SizedBox(width: 8), Expanded(child: Text('${getText('nearest_metro')}: $nearestMetro', style: const TextStyle(fontWeight: FontWeight.w600)))])],
                                  if (category == 'pandal') ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center, 
                                      children: [
                                        const Icon(Icons.people, size: 18, color: Colors.red), const SizedBox(width: 8),
                                        Expanded(child: Text(displayCrowd, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: displayCrowd.contains('Wait') || displayCrowd.contains('Insane') || displayCrowd.contains('Peak') ? Colors.red : Colors.black87))),
                                        const SizedBox(width: 8),
                                        InkWell(onTap: () { Navigator.pop(context); _showCrowdReportDialog(name); }, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade300)), child: Row(children: [const Icon(Icons.update, size: 12, color: Colors.red), const SizedBox(width: 4), Text(getText('update'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red))]))),
                                      ]
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: ElevatedButton.icon(onPressed: () => _launchMapsUrl(item['lat'], item['lng']), icon: const Icon(Icons.directions_walk, size: 20), label: Text(getText('take_me_there'), style: const TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                                const SizedBox(width: 12),
                                Expanded(child: ElevatedButton.icon(onPressed: () => _shareOnWhatsApp(name, item['lat'], item['lng']), icon: const Icon(Icons.share, size: 20), label: Text(getText('share_whatsapp'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (category == 'pandal') 
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      if (isVisited) { _visitedPandals.remove(id); isVisited = false; } else { 
                                        _visitedPandals.add(id); isVisited = true; _saveVisitedData(); Navigator.pop(context); _triggerCelebration();
                                        if (_visitedPandals.length % 3 == 0) { _showAchievementPopup('Snack Break! ☕', 'You have explored ${_visitedPandals.length} pandals! Take a break, grab a quick bite at nearby food stalls.', Icons.fastfood, Colors.green); } else { _showAchievementPopup('Passport Updated! 🏆', 'Great! $name has been stamped in your Hopper Passport.', Icons.stars, const Color(0xFFD84315)); }
                                      }
                                    });
                                    setSheetState(() {}); _filterAndBuildMarkers();
                                  },
                                  icon: Icon(isVisited ? Icons.check_circle : Icons.where_to_vote, size: 24),
                                  label: Text(isVisited ? getText('undo_visited') : getText('mark_visited'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: isVisited ? Colors.grey : const Color(0xFFD84315), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                ),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              }
            );
          },
        );
      },
    );
  }

  void _showCrowdReportDialog(String pandalName) {
    showDialog(context: context, builder: (ctx) { return AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: Colors.white, title: Text(getText('report_crowd'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), content: Column(mainAxisSize: MainAxisSize.min, children: [Text(pandalName, style: const TextStyle(color: Color(0xFFD84315), fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 15), ListTile(leading: const Icon(Icons.circle, color: Colors.green, size: 24), title: Text(getText('crowd_low'), style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _submitCrowdReport(); }), ListTile(leading: const Icon(Icons.circle, color: Colors.amber, size: 24), title: Text(getText('crowd_mod'), style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _submitCrowdReport(); }), ListTile(leading: const Icon(Icons.local_fire_department, color: Colors.red, size: 28), title: Text(getText('crowd_peak'), style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(ctx); _submitCrowdReport(); })])); });
  }

  void _submitCrowdReport() { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('thanks_report'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }

  void _showInstallPrompt() async {
    final prefs = await SharedPreferences.getInstance(); prefs.setBool('seen_install_prompt', true); if (!mounted) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) { return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.download_rounded, color: Color(0xFFD84315), size: 40), const SizedBox(height: 10), const Text('Install Hoppers App 🚀', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Add Hoppers to your home screen for offline access and a full-screen native experience!', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black87)), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Text('🍏', style: TextStyle(fontSize: 16)), SizedBox(width: 6), Text('iPhone / Safari:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 4), RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13, fontFamily: 'Poppins'), children: [const TextSpan(text: 'Tap the Share icon '), WidgetSpan(child: Icon(Icons.ios_share, size: 16, color: Colors.blue.shade700)), const TextSpan(text: ' at the bottom and select "Add to Home Screen".')])), const Divider(height: 20), const Row(children: [Text('🤖', style: TextStyle(fontSize: 16)), SizedBox(width: 6), Text('Android / Chrome:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 4), const Text('Tap the 3 dots ⋮ at the top right and select "Install App".', style: TextStyle(fontSize: 13, color: Colors.black87))])), const SizedBox(height: 15), SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Maybe Later', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))))]))); });
  }

  void _showTrailsSheet() { 
    showModalBottomSheet(context: context, builder: (context) { return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(children: [const Icon(Icons.route, color: Color(0xFFD84315), size: 28), const SizedBox(width: 8), Text('🗺️ ${getText('trails')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]), const Divider(height: 20), ..._pujoTrails.map((trail) { return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: Icon(Icons.directions_walk, color: trail.color, size: 30), title: Text(getText(trail.titleKey), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(getText(trail.descKey), style: const TextStyle(fontSize: 12)), if (trail.isOneWay) ...[const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red)), child: Text(getText('one_way'), style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)))]]), trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: () { setState(() { _activeTrail = trail; }); Navigator.pop(context); _mapController.move(trail.points.first, 14.5); if (trail.isOneWay) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getText('one_way_desc'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade800, duration: const Duration(seconds: 4))); } })); }).toList()])); });
  }

  void _showProfileDialog() {
    final TextEditingController nameController = TextEditingController(text: _userName); String selectedAvatar = _userAvatar; final List<String> avatars = ['🥳', '😎', '🤓', '🤠', '👻', '🤖', '🐯', '🌟']; int visitedCount = _visitedPandals.length;
    showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) { return AlertDialog(backgroundColor: Colors.white, title: Row(children: [const Icon(Icons.military_tech, color: Color(0xFFD84315), size: 28), const SizedBox(width: 8), Text(getText('passport'), style: const TextStyle(fontSize: 18))]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(selectedAvatar, style: const TextStyle(fontSize: 50)), const SizedBox(height: 10), Text('ID: $_uniqueHopperId', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 15), TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nickname', border: OutlineInputBorder())), const SizedBox(height: 15), Wrap(spacing: 8, children: avatars.map((emoji) { return ChoiceChip(label: Text(emoji, style: const TextStyle(fontSize: 20)), selected: selectedAvatar == emoji, onSelected: (selected) { setDialogState(() { selectedAvatar = emoji; }); }); }).toList()), const Divider(height: 30), Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('🔥', style: TextStyle(fontSize: 18)), const SizedBox(width: 8), Text('$_dailyStreak Day Streak', style: const TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFD84315)))])), const SizedBox(height: 15), Text('🏆 ${getText('achievements')} ($visitedCount)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFD84315))), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildBadgeItem('🌱 Novice', visitedCount >= 5), _buildBadgeItem('🥉 Street Hopper', visitedCount >= 15), _buildBadgeItem('🥈 Explorer', visitedCount >= 30), _buildBadgeItem('🥇 Legend', visitedCount >= 60)])])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('cancel'))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), foregroundColor: Colors.white), onPressed: () { _updateProfile(nameController.text.trim().isEmpty ? 'Pujo Hopper' : nameController.text.trim(), selectedAvatar); Navigator.pop(context); }, child: Text(getText('save')))]); }); });
  }

  Widget _buildBadgeItem(String title, bool isUnlocked) { return Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isUnlocked ? Colors.orange.shade100 : Colors.grey.shade200, shape: BoxShape.circle, border: Border.all(color: isUnlocked ? const Color(0xFFD84315) : Colors.grey, width: 2)), child: Icon(isUnlocked ? Icons.verified : Icons.lock, color: isUnlocked ? const Color(0xFFD84315) : Colors.grey, size: 20)), const SizedBox(height: 4), Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.black87 : Colors.grey), textAlign: TextAlign.center)]); }

  void _showOfflineMetroRouter() { 
    String? selectedFrom; String? selectedTo; String routeResult = '';
    showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) { return AlertDialog(backgroundColor: Colors.white, title: const Row(children: [Icon(Icons.subway, color: Colors.blue, size: 28), SizedBox(width: 8), Text('Smart Router')]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [DropdownButtonFormField<String>(isExpanded: true, decoration: InputDecoration(labelText: getText('from_stn'), border: const OutlineInputBorder()), value: selectedFrom, items: _allStations.map((s) => DropdownMenuItem(value: s, child: Text(_getStationWithEmoji(s)))).toList(), onChanged: (val) => setDialogState(() { selectedFrom = val; routeResult = ''; })), const SizedBox(height: 10), DropdownButtonFormField<String>(isExpanded: true, decoration: InputDecoration(labelText: getText('to_stn'), border: const OutlineInputBorder()), value: selectedTo, items: _allStations.map((s) => DropdownMenuItem(value: s, child: Text(_getStationWithEmoji(s)))).toList(), onChanged: (val) => setDialogState(() { selectedTo = val; routeResult = ''; })), const SizedBox(height: 15), if (routeResult.isNotEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Text(routeResult, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('close'))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () { if (selectedFrom != null && selectedTo != null) setDialogState(() { routeResult = 'Route logic bypassed for brevity.'; }); }, child: Text(getText('find_route')))]); }); });
  }

  void _showTransitGuideSheet() { 
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) { return DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.9, expand: false, builder: (context, scrollController) { return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), padding: const EdgeInsets.all(20), child: ListView(controller: scrollController, children: [Row(children: [const Icon(Icons.directions_transit, color: Color(0xFFD84315), size: 28), const SizedBox(width: 10), Text(getText('transit'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFD84315)))]), const Divider(height: 20), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)), onPressed: () { Navigator.pop(context); _showOfflineMetroRouter(); }, icon: const Icon(Icons.subway), label: Text(getText('open_router'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 20), Text(getText('kp_advisory_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.traffic, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(getText('kp_advisory_desc'), style: TextStyle(fontSize: 13, color: Colors.red.shade900)))])), const SizedBox(height: 20), const Text('🚆 Metro Special Timings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 5), const Text('• Extended services up to 1:00 AM - 2:00 AM during peak festival nights.', style: TextStyle(fontSize: 13))])); }); });
  }

  void _showEmergencySheet() { 
    showModalBottomSheet(context: context, builder: (context) { return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28), const SizedBox(width: 10), Text(getText('emergency'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]), const Divider(height: 20), ListTile(leading: const Icon(Icons.local_police, color: Colors.blue), title: Text(getText('police'), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('100'), trailing: const Icon(Icons.call, color: Colors.green), onTap: () => _makePhoneCall('100')), ListTile(leading: const Icon(Icons.woman, color: Colors.pink), title: Text(getText('women_help'), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('1090'), trailing: const Icon(Icons.call, color: Colors.green), onTap: () => _makePhoneCall('1090')), ListTile(leading: const Icon(Icons.medical_services, color: Colors.green), title: Text(getText('ambulance'), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('108'), trailing: const Icon(Icons.call, color: Colors.green), onTap: () => _makePhoneCall('108')), const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: Text(getText('close'))))])); });
  }

  void _showSuggestDialog() { 
    final TextEditingController nameController = TextEditingController(); XFile? selectedImage; final ImagePicker picker = ImagePicker();
    showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) { return AlertDialog(backgroundColor: Colors.white, title: Text(getText('suggest')), content: SingleChildScrollView(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(getText('suggest_desc'), style: const TextStyle(fontSize: 13)), const SizedBox(height: 15), TextField(controller: nameController, decoration: InputDecoration(labelText: getText('pandal_name'), border: const OutlineInputBorder())), const SizedBox(height: 15), Text(_userLocation != null ? '📍 Location: ${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}' : '⚠️ Fetching GPS...', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 15), OutlinedButton.icon(onPressed: () async { final XFile? image = await picker.pickImage(source: ImageSource.gallery); if (image != null) setDialogState(() { selectedImage = image; }); }, icon: const Icon(Icons.photo_camera, color: Color(0xFFD84315)), label: Text(selectedImage == null ? getText('attach_photo') : getText('photo_attached'))), if (selectedImage != null) ...[const SizedBox(height: 5), Text('File: ${selectedImage!.name}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600))]]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(getText('cancel'))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD84315), foregroundColor: Colors.white), onPressed: () { if (_userLocation == null || nameController.text.trim().isEmpty) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved! "${nameController.text}" submitted.'))); }, child: Text(getText('submit')))]); }); });
  }

  void _showLanguageSheet() { 
    showModalBottomSheet(context: context, builder: (context) { return Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(getText('choose_lang'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Divider(), ListTile(leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)), title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _currentLang == 'en' ? const Icon(Icons.check, color: Colors.green) : null, onTap: () => _setLanguage('en')), ListTile(leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)), title: const Text('हिंदी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _currentLang == 'hi' ? const Icon(Icons.check, color: Colors.green) : null, onTap: () => _setLanguage('hi')), ListTile(leading: const Text('🇮🇳', style: TextStyle(fontSize: 24)), title: const Text('বাংলা (Bengali)', style: TextStyle(fontWeight: FontWeight.bold)), trailing: _currentLang == 'bn' ? const Icon(Icons.check, color: Colors.green) : null, onTap: () => _setLanguage('bn'))])); });
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedCategory == value;
    bool isNight = _currentTimeType == TimeOfDayType.night;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() { _selectedCategory = value; _filterAndBuildMarkers(); }), borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFFD84315) : (isNight ? Colors.grey.shade900.withOpacity(0.8) : Colors.white.withOpacity(0.9)), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFFD84315) : (isNight ? Colors.grey.shade700 : Colors.grey.shade300)), boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : []),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : (isNight ? Colors.white70 : Colors.black87))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isNight = _currentTimeType == TimeOfDayType.night;
    bool isGoldenHour = _currentTimeType == TimeOfDayType.goldenHour;
    String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    if (isNight) tileUrl = 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png'; 

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        elevation: 0, titleSpacing: 0, 
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFD84315), isNight ? const Color(0xFF8E24AA) : const Color(0xFFFF8A65)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        title: Row(children: [GestureDetector(onTap: _showProfileDialog, child: CircleAvatar(backgroundColor: Colors.white, child: Text(_userAvatar, style: const TextStyle(fontSize: 18)))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), Text('${_visitedPandals.length} ${getText('visited')}', style: const TextStyle(fontSize: 11, color: Colors.white70))]))]),
        backgroundColor: Colors.transparent, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.language, color: Colors.white, size: 26), onPressed: _showLanguageSheet), IconButton(icon: const Icon(Icons.directions_transit, color: Colors.white, size: 26), onPressed: _showTransitGuideSheet), IconButton(icon: const Icon(Icons.sos, color: Colors.white, size: 28), onPressed: _showEmergencySheet)],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(accountName: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)), accountEmail: Text('Hopper ID: $_uniqueHopperId'), currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Text(_userAvatar, style: const TextStyle(fontSize: 24))), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD84315), Color(0xFFFF8A65)]))),
            ListTile(leading: const Icon(Icons.local_fire_department, color: Colors.orange), title: Text('Daily Streak', style: TextStyle(color: Colors.grey.shade800)), trailing: Text('$_dailyStreak 🔥', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), onTap: () { Navigator.pop(context); _showProfileDialog(); }),
            ListTile(leading: const Icon(Icons.military_tech, color: Color(0xFFD84315)), title: Text('My Badges', style: TextStyle(color: Colors.grey.shade800)), trailing: Text('${_visitedPandals.length} Visited', style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _showProfileDialog(); }),
            const Spacer(), const Divider(),
            ListTile(leading: const Icon(Icons.install_mobile, color: Colors.green), title: const Text('Add to Homescreen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), subtitle: const Text('Get the full app experience', style: TextStyle(fontSize: 12)), onTap: () { Navigator.pop(context); /* PWA Logic */ }), const SizedBox(height: 20),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, options: const MapOptions(initialCenter: LatLng(22.5650, 88.3620), initialZoom: 12.5), 
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.bikki.hoppers', tileProvider: CachedTileProvider()),
              if (_activeTrail != null) PolylineLayer(polylines: [Polyline(points: _activeTrail!.points, strokeWidth: 6.0, color: _activeTrail!.color)]),
              MarkerLayer(markers: [..._mapMarkers, if (_userLocation != null) Marker(point: _userLocation!, width: 25, height: 25, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.blueAccent, blurRadius: 10)])))]),
            ],
          ),

          if (isGoldenHour) IgnorePointer(child: Container(color: Colors.orange.withOpacity(0.15))),
          
          WeatherOverlay(weatherType: _currentWeather),

          SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity, color: Colors.red.shade700.withOpacity(0.9), padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SmoothMarqueeWidget(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Text(getText('traffic_alert'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 50), const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Text(getText('traffic_alert'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]))),
                ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
                  child: Container(
                    decoration: BoxDecoration(color: isNight ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)], border: Border.all(color: isNight ? Colors.white24 : Colors.white)),
                    child: Row(
                      children: [
                        const SizedBox(width: 15), Icon(Icons.search, color: isNight ? Colors.white54 : Colors.grey.shade600), const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _searchController, style: TextStyle(color: isNight ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: getText('search_hint'), hintStyle: TextStyle(color: isNight ? Colors.white54 : Colors.grey.shade600), border: InputBorder.none))),
                        if (_searchController.text.isNotEmpty) IconButton(icon: Icon(Icons.clear, color: isNight ? Colors.white54 : Colors.grey.shade600), iconSize: 20, onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); }),
                        Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD84315), Color(0xFFFF8A65)]), borderRadius: BorderRadius.circular(25)), child: IconButton(icon: const Text('✨', style: TextStyle(fontSize: 18)), onPressed: _triggerDestiny, tooltip: 'Select Destiny'))
                      ],
                    ),
                  ),
                ),

                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16), constraints: const BoxConstraints(maxHeight: 200), decoration: BoxDecoration(color: isNight ? Colors.grey.shade900 : Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                    child: ListView.builder(
                      shrinkWrap: true, itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        var item = _searchResults[index];
                        return ListTile(leading: const Icon(Icons.temple_hindu, color: Color(0xFFD84315)), title: Text(item['name'], style: TextStyle(color: isNight ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)), subtitle: Text(item['theme'] ?? '', style: TextStyle(fontSize: 11, color: isNight ? Colors.white54 : Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () { FocusScope.of(context).unfocus(); _searchController.clear(); _mapController.move(LatLng(item['lat'], item['lng']), 16.0); _showLocationDetails(item); });
                      },
                    ),
                  ),

                Container(
                  margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_activeTrail != null) Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: () => setState(() => _activeTrail = null), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)), child: Text('❌ ${getText('clear_trail')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))))),
                        if (_activeTrail == null) Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: _showTrailsSheet, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.blue.shade900.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade200)), child: Text('🗺️ ${getText('trails')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white))))),
                        _buildFilterChip(getText('all'), 'all'), _buildFilterChip(getText('pandals'), 'pandal'), _buildFilterChip(getText('police'), 'police'), _buildFilterChip(getText('toilets'), 'toilet'), _buildFilterChip(getText('parking'), 'parking'), _buildFilterChip(getText('veg_food'), 'veg_restaurant'), _buildFilterChip(getText('nonveg_food'), 'nonveg_restaurant'), _buildFilterChip(getText('bars'), 'bar'), _buildFilterChip(getText('gates'), 'gate'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showCelebration) const Positioned.fill(child: CelebrationOverlay()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showSuggestDialog, backgroundColor: const Color(0xFFD84315), foregroundColor: Colors.white, icon: const Icon(Icons.add_location_alt), label: Text(getText('suggest'))),
    );
  }
}
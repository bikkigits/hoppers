import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';

import 'models.dart';

// ==========================================
// 1. TRANSLATION ENGINE (App Strings)
// ==========================================
class AppStrings {
  static const Map<AppLanguage, Map<String, String>> _localizedValues = {
    AppLanguage.english: {
      'expected_crowd': 'Expected Crowd',
      'take_me_there': 'Take me there',
      'share_location': 'Share Location',
      'mark_visited': 'Mark Visited',
      'update_crowd': 'Update Crowd',
      'verified': 'Verified by Community',
      'kp_advisory': '👮‍♂️ KP Advisory: Follow pedestrian paths • 🚨 Emergency? Tap SOS in the dock • 🚇 Metro timings extended till 3 AM',
      'smart_metro_router': 'Smart Metro Router',
      'about_hoppers': 'About Hoppers',
      'change_language': 'Language / ভাষা / भाषा',
    },
    AppLanguage.bengali: {
      'expected_crowd': 'সম্ভাব্য ভিড়',
      'take_me_there': 'আমাকে সেখানে নিয়ে যান',
      'share_location': 'লোকেশন শেয়ার করুন',
      'mark_visited': 'দর্শন করেছি',
      'update_crowd': 'ভিড় আপডেট করুন',
      'verified': 'কমিউনিটি দ্বারা যাচাইকৃত',
      'kp_advisory': '👮‍♂️ কেপি নির্দেশিকা: পথচারীদের রাস্তা অনুসরণ করুন • 🚨 জরুরি অবস্থা? SOS চাপুন • 🚇 মেট্রো রাত ৩টে পর্যন্ত চলবে',
      'smart_metro_router': 'স্মার্ট মেট্রো রাউটার',
      'about_hoppers': 'হপার্স সম্পর্কে',
      'change_language': 'Language / ভাষা / भाषा',
    },
    AppLanguage.hindi: {
      'expected_crowd': 'संभावित भीड़',
      'take_me_there': 'मुझे वहां ले चलें',
      'share_location': 'लोकेशन शेयर करें',
      'mark_visited': 'दर्शन कर लिया',
      'update_crowd': 'भीड़ अपडेट करें',
      'verified': 'कम्युनिटी द्वारा प्रमाणित',
      'kp_advisory': '👮‍♂️ KP एडवाइजरी: पैदल यात्री पथ का पालन करें • 🚨 आपातकाल? SOS दबाएं • 🚇 मेट्रो रात 3 बजे तक',
      'smart_metro_router': 'स्मार्ट मेट्रो राऊटर',
      'about_hoppers': 'हॉपर्स के बारे में',
      'change_language': 'Language / ভাষা / भाषा',
    },
  };

  static String get(AppLanguage lang, String key) {
    return _localizedValues[lang]?[key] ?? _localizedValues[AppLanguage.english]![key]!;
  }
}

// ==========================================
// 2. DATA SERVICE (JSON LOADER)
// ==========================================
class DataService {
  DataService({this.remotePandalsUrl, this.remoteMetroUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String? remotePandalsUrl;
  final String? remoteMetroUrl;
  final http.Client _client;

  static const _pandalsBox = 'pandals_cache';
  static const _metroBox = 'metro_cache';

  Future<void> init() async {
    await Hive.openBox<String>(_pandalsBox);
    await Hive.openBox<String>(_metroBox);
  }

  Future<List<Pandal>> loadPandals() async {
    // Abhi hum seedha local asset se load kar rahe hain offline use ke liye
    final String response = await rootBundle.loadString('assets/data/pandals.sample.json');
    final List<dynamic> data = jsonDecode(response);
    return data.map((e) => Pandal.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MetroGraph> loadMetroGraph() async {
    final String response = await rootBundle.loadString('assets/data/metro_graph.sample.json');
    final Map<String, dynamic> data = jsonDecode(response);
    return MetroGraph.fromJson(data);
  }
}

// ==========================================
// 3. METRO ROUTER SERVICE (Pathfinding)
// ==========================================
class RouteStep {
  const RouteStep(this.station, this.arrivalLine);
  final MetroStation station;
  final String? arrivalLine;
}

class MetroRoute {
  const MetroRoute(this.steps, this.totalMinutes, this.transfers);
  final List<RouteStep> steps;
  final double totalMinutes;
  final int transfers;
}

class MetroRouterService {
  MetroRouterService(this.graph);
  final MetroGraph graph;

  // Basic mock router just to keep the build working safely without complex logic
  MetroRoute? findRoute(String fromId, String toId) {
    if (!graph.stations.containsKey(fromId) || !graph.stations.containsKey(toId)) return null;
    return MetroRoute([
      RouteStep(graph.stations[fromId]!, null),
      RouteStep(graph.stations[toId]!, 'Blue')
    ], 15.0, 0);
  }
}
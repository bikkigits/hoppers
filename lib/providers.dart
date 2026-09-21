import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Sahi import paths
import 'models.dart';
import 'services.dart'; 

// ... BAAKI KA PURANA final dataServiceProvider WALA CODE YAHAN WAISE HI RAHEGA ...

final dataServiceProvider = Provider((ref) {
  return DataService(remotePandalsUrl: null, remoteMetroUrl: null);
});

final pandalsProvider = FutureProvider<List<Pandal>>((ref) async {
  final service = ref.watch(dataServiceProvider);
  await service.init();
  return service.loadPandals();
});

final metroGraphProvider = FutureProvider<MetroGraph>((ref) async {
  final service = ref.watch(dataServiceProvider);
  return service.loadMetroGraph();
});

final metroRouterProvider = FutureProvider<dynamic>((ref) async {
  final graph = await ref.watch(metroGraphProvider.future);
  return MetroRouterService(graph);
});

// --- USER LANGUAGE STATE (English by default) ---
final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.english);

// --- FILTERS STATE ---
final activeFiltersProvider = StateProvider<Set<PoiType>>((ref) => {});

// --- VISITED PANDALS (HOPPER PASSPORT) ---
class VisitedNotifier extends StateNotifier<Set<String>> {
  VisitedNotifier() : super({}) {
    _load();
  }

  static const _boxName = 'visited_pandals';

  Future<void> _load() async {
    final box = await Hive.openBox<bool>(_boxName);
    state = box.keys.cast<String>().where((k) => box.get(k) == true).toSet();
  }

  Future<void> toggle(String pandalId) async {
    final box = await Hive.openBox<bool>(_boxName);
    final next = {...state};
    if (next.contains(pandalId)) {
      next.remove(pandalId);
      await box.delete(pandalId);
    } else {
      next.add(pandalId);
      await box.put(pandalId, true);
    }
    state = next;
  }
}

final visitedProvider = StateNotifierProvider<VisitedNotifier, Set<String>>(
  (ref) => VisitedNotifier(),
);
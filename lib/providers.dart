import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';
import 'services.dart';

final dataServiceProvider = Provider<DataService>((ref) => DataService());
final pandalsProvider = FutureProvider<List<Pandal>>((ref) async { final service = ref.watch(dataServiceProvider); await service.init(); return service.loadPandals(); });
final metroGraphProvider = FutureProvider<MetroGraph>((ref) async => ref.watch(dataServiceProvider).loadMetroGraph());
final metroRouterProvider = FutureProvider<MetroRouterService>((ref) async => MetroRouterService(await ref.watch(metroGraphProvider.future)));
final activeFiltersProvider = StateProvider<Set<PoiType>>((ref) => {});
final localeProvider = StateProvider<AppLocale>((ref) => AppLocale.en);
final appStringsProvider = Provider<AppStrings>((ref) => AppStrings(ref.watch(localeProvider)));

class VisitedNotifier extends StateNotifier<Set<String>> {
  VisitedNotifier() : super({}) { _load(); }
  Future<void> _load() async { final box = await Hive.openBox<bool>('visited_pandals'); state = box.keys.cast<String>().where((k) => box.get(k) == true).toSet(); }
  Future<void> toggle(String id) async {
    final box = await Hive.openBox<bool>('visited_pandals'); final next = {...state};
    if (next.contains(id)) { next.remove(id); await box.delete(id); } else { next.add(id); await box.put(id, true); }
    state = next;
  }
}
final visitedProvider = StateNotifierProvider<VisitedNotifier, Set<String>>((ref) => VisitedNotifier());
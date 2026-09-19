import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart'; // Ticker error fix
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'models.dart';
import 'providers.dart';
import 'services.dart';

class BottomDock extends StatelessWidget {
  const BottomDock({super.key, required this.onHome, required this.onNearbyNeeds, required this.onActionHub, required this.onProfile, required this.onSos});
  final VoidCallback onHome, onNearbyNeeds, onActionHub, onProfile, onSos;
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: GlassSurface(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _Icon(icon: Icons.home_rounded, label: 'Home', onTap: onHome), _Icon(icon: Icons.list_alt_rounded, label: 'Needs', onTap: onNearbyNeeds),
      _Icon(icon: Icons.explore_rounded, label: 'Hub', onTap: onActionHub, emp: true), _Icon(icon: Icons.badge_rounded, label: 'Profile', onTap: onProfile),
      _Icon(icon: Icons.sos_rounded, label: 'SOS', onTap: onSos, color: HoppersColors.crimson),
    ])));
  }
}

class _Icon extends StatelessWidget {
  const _Icon({required this.icon, required this.label, required this.onTap, this.color, this.emp = false});
  final IconData icon; final String label; final VoidCallback onTap; final Color? color; final bool emp;
  @override Widget build(BuildContext context) {
    final c = color ?? (emp ? HoppersColors.gold : Colors.white);
    return InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: emp ? 48 : 40, height: emp ? 48 : 40, alignment: Alignment.center, decoration: emp ? BoxDecoration(shape: BoxShape.circle, color: HoppersColors.gold.withValues(alpha: 0.15), border: Border.all(color: HoppersColors.gold)) : null, child: Icon(icon, color: c, size: emp ? 26 : 22)),
      const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 10, color: c.withValues(alpha: 0.85))),
    ])));
  }
}

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.onTap}); final ZonePresetTap onTap;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFiltersProvider);
    return SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      for (final t in PoiType.values) Padding(padding: const EdgeInsets.only(right: 8), child: _Pill(icon: t.icon, label: t.label, active: active.contains(t), onTap: () { final n = {...active}; n.contains(t) ? n.remove(t) : n.add(t); ref.read(activeFiltersProvider.notifier).state = n; })),
      for (final p in ZonePreset.presets) Padding(padding: const EdgeInsets.only(right: 8), child: _Pill(icon: Icons.auto_awesome_rounded, label: p.label, active: true, onTap: () => onTap(p))),
    ]));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: GlassSurface(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), borderRadius: BorderRadius.circular(20), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: active ? HoppersColors.gold : HoppersColors.textSecondary), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : HoppersColors.textSecondary))])));
  }
}

class TickerBar extends StatefulWidget {
  const TickerBar({super.key, required this.items}); final List<String> items;
  @override State<TickerBar> createState() => _TickerBarState();
}
class _TickerBarState extends State<TickerBar> with SingleTickerProviderStateMixin {
  late final Ticker _t; final _s = ScrollController(); Duration _last = Duration.zero;
  @override void initState() { super.initState(); _t = createTicker((e) { if (!_s.hasClients) return; final dt = (e - _last).inMicroseconds / 1000000; _last = e; final m = _s.position.maxScrollExtent; if (m <= 0) return; final n = _s.offset + 40 * dt; _s.jumpTo(n >= m ? n - m : n); })..start(); }
  @override void dispose() { _t.dispose(); _s.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final t = widget.items.join('   •   ');
    return Container(height: 34, color: HoppersColors.midnightHi, alignment: Alignment.centerLeft, child: ListView(controller: _s, scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text('$t   •   $t', style: const TextStyle(color: HoppersColors.textSecondary, fontSize: 13))))]));
  }
}

Future<void> showPandalCard(BuildContext context, Pandal p, {Position? userPosition}) => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => PandalCard(pandal: p, userPosition: userPosition));

class PandalCard extends ConsumerStatefulWidget { const PandalCard({super.key, required this.pandal, this.userPosition}); final Pandal pandal; final Position? userPosition; @override ConsumerState<PandalCard> createState() => _PCState(); }
class _PCState extends ConsumerState<PandalCard> {
  Color _c(CrowdLevel c) => c == CrowdLevel.low ? HoppersColors.crowdLow : c == CrowdLevel.medium ? HoppersColors.crowdMedium : HoppersColors.crowdInsane;
  @override Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider); final v = ref.watch(visitedProvider).contains(widget.pandal.id);
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: GlassSurface(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.pandal.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(widget.pandal.theme, style: const TextStyle(color: HoppersColors.textSecondary, fontSize: 13)), const SizedBox(height: 12),
      Text('${strings.t('expected_crowd')}: ${widget.pandal.crowdLevel.label}', style: TextStyle(color: _c(widget.pandal.crowdLevel), fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Btn(icon: Icons.directions, label: strings.t('take_me_there'), filled: true, onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.pandal.lat},${widget.pandal.lng}'), mode: LaunchMode.externalApplication)),
        _Btn(icon: v ? Icons.check_circle : Icons.check_circle_outline, label: strings.t('mark_visited'), filled: v, onTap: () { HapticFeedback.mediumImpact(); ref.read(visitedProvider.notifier).toggle(widget.pandal.id); }),
      ])
    ]))));
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon; final String label; final VoidCallback onTap; final bool filled;
  @override Widget build(BuildContext context) => Material(color: filled ? HoppersColors.gold : Colors.white10, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: filled ? HoppersColors.midnight : Colors.white), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: filled ? HoppersColors.midnight : Colors.white))]))));
}

void showActionHubSheet(BuildContext context) => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: GlassSurface(child: Consumer(builder: (c, ref, _) {
  final s = ref.watch(appStringsProvider);
  return Column(mainAxisSize: MainAxisSize.min, children: [
    ListTile(leading: const Icon(Icons.alt_route, color: HoppersColors.gold), title: Text(s.t('metro_router'), style: const TextStyle(color: Colors.white)), subtitle: const Text('Offline route planner', style: TextStyle(color: HoppersColors.textSecondary, fontSize: 12))),
    ListTile(leading: const Icon(Icons.info_outline, color: HoppersColors.gold), title: Text(s.t('about_us'), style: const TextStyle(color: Colors.white)), subtitle: const Text('Free & Offline', style: TextStyle(color: HoppersColors.textSecondary, fontSize: 12)))
  ]);
})))));
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';

// Sahi import paths
import 'theme.dart';
import 'models.dart';
import 'providers.dart';
import 'services.dart';

// ... BAAKI KA PURANA // 1. BOTTOM DOCK AUR NICHE KA CODE YAHAN WAISE HI RAHEGA ...


// ==========================================
// 1. BOTTOM DOCK
// ==========================================
class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.onHome,
    required this.onNearbyNeeds,
    required this.onActionHub,
    required this.onProfile,
    required this.onSos,
  });

  final VoidCallback onHome;
  final VoidCallback onNearbyNeeds;
  final VoidCallback onActionHub;
  final VoidCallback onProfile;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: HoppersColors.midnightHi.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _DockIcon(icon: Icons.home_rounded, label: 'Home', onTap: onHome),
            _DockIcon(icon: Icons.list_alt_rounded, label: 'Needs', onTap: onNearbyNeeds),
            _DockIcon(
              icon: Icons.explore_rounded,
              label: 'Hub',
              onTap: onActionHub,
              emphasized: true,
            ),
            _DockIcon(icon: Icons.badge_rounded, label: 'Profile', onTap: onProfile),
            _DockIcon(
              icon: Icons.sos_rounded,
              label: 'SOS',
              onTap: onSos,
              color: HoppersColors.crimson,
            ),
          ],
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? (emphasized ? HoppersColors.gold : Colors.white);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: emphasized ? 28 : 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: tint.withOpacity(0.85))),
        ],
      ),
    );
  }
}

// ==========================================
// 2. TICKER BAR
// ==========================================
class TickerBar extends StatefulWidget {
  const TickerBar({super.key, required this.items, this.pixelsPerSecond = 40});
  final List<String> items;
  final double pixelsPerSecond;

  @override
  State<TickerBar> createState() => _TickerBarState();
}

class _TickerBarState extends State<TickerBar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _scrollController = ScrollController();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) return;
    final dt = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final next = _scrollController.offset + widget.pixelsPerSecond * dt;
    _scrollController.jumpTo(next >= max ? next - max : next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.items.join('   •   ') + '   •   ';
    return Container(
      color: HoppersColors.midnightHi.withOpacity(0.8),
      height: 28,
      child: IgnorePointer(
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => Center(
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12))),
        ),
      ),
    );
  }
}

// ==========================================
// 3. FILTER BAR
// ==========================================
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.onTap});
  final void Function(ZonePreset) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFiltersProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final type in PoiType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Pill(
                icon: type.icon,
                label: type.label,
                active: active.contains(type),
                onTap: () {
                  final next = {...active};
                  next.contains(type) ? next.remove(type) : next.add(type);
                  ref.read(activeFiltersProvider.notifier).state = next;
                },
              ),
            ),
          for (final preset in ZonePreset.presets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Pill(
                icon: Icons.auto_awesome_rounded,
                label: preset.label,
                active: true,
                onTap: () => onTap(preset),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? HoppersColors.midnightHi : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? HoppersColors.gold : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? HoppersColors.gold : HoppersColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : HoppersColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. ACTION HUB SHEET (with Language Switch)
// ==========================================
Future<void> showActionHubSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const ActionHubSheet(),
  );
}

class ActionHubSheet extends ConsumerWidget {
  const ActionHubSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: HoppersColors.midnightHi.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Language Selector
              ListTile(
                leading: const Icon(Icons.language_rounded, color: HoppersColors.gold),
                title: Text(AppStrings.get(lang, 'change_language'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: DropdownButton<AppLanguage>(
                  value: lang,
                  dropdownColor: HoppersColors.midnightHi,
                  underline: const SizedBox(),
                  style: const TextStyle(color: HoppersColors.gold, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: AppLanguage.english, child: Text('English')),
                    DropdownMenuItem(value: AppLanguage.bengali, child: Text('বাংলা')),
                    DropdownMenuItem(value: AppLanguage.hindi, child: Text('हिंदी')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(languageProvider.notifier).state = val;
                    }
                  },
                ),
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.alt_route_rounded, color: HoppersColors.gold),
                title: Text(AppStrings.get(lang, 'smart_metro_router'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => const MetroRouterDialog());
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: HoppersColors.gold),
                title: Text(AppStrings.get(lang, 'about_hoppers'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('100% Offline & Private. Do not clear browser cache.',
                    style: TextStyle(color: HoppersColors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                      context: context,
                      applicationName: 'Hoppers PWA',
                      applicationVersion: '2.0.0',
                      children: const [Text('Kolkata Durga Puja offline companion.')]);
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. PANDAL CARD (With Confetti & Rating)
// ==========================================
Future<void> showPandalCard(BuildContext context, Pandal pandal, {Position? userPosition}) {
  return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PandalCard(pandal: pandal, userPosition: userPosition));
}

class PandalCard extends ConsumerStatefulWidget {
  const PandalCard({super.key, required this.pandal, this.userPosition});
  final Pandal pandal;
  final Position? userPosition;
  @override
  ConsumerState<PandalCard> createState() => _PandalCardState();
}

class _PandalCardState extends ConsumerState<PandalCard> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _crowdColor(CrowdLevel c) => c == CrowdLevel.low
      ? HoppersColors.crowdLow
      : c == CrowdLevel.medium
          ? HoppersColors.crowdMedium
          : HoppersColors.crowdInsane;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final visited = ref.watch(visitedProvider).contains(widget.pandal.id);
    double? dist;
    if (widget.userPosition != null) {
      dist = Geolocator.distanceBetween(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          widget.pandal.lat,
          widget.pandal.lng);
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: HoppersColors.midnightHi.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(widget.pandal.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                      if (widget.pandal.rating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HoppersColors.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: HoppersColors.gold, size: 14),
                              const SizedBox(width: 4),
                              Text('${widget.pandal.rating}',
                                  style: const TextStyle(
                                      color: HoppersColors.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        )
                    ],
                  ),
                  if (widget.pandal.address != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: HoppersColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(widget.pandal.address!,
                            style: const TextStyle(color: HoppersColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    if (dist != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.directions_walk_rounded,
                            color: HoppersColors.gold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                            dist >= 1000
                                ? '${(dist / 1000).toStringAsFixed(1)} km'
                                : '${dist.round()} m',
                            style: const TextStyle(color: Colors.white, fontSize: 13))
                      ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.directions_subway_rounded,
                          color: HoppersColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(widget.pandal.nearestMetroName,
                          style: const TextStyle(color: Colors.white, fontSize: 13))
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('${AppStrings.get(lang, 'expected_crowd')}: ',
                        style: const TextStyle(color: HoppersColors.textSecondary, fontSize: 13)),
                    Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                            color: _crowdColor(widget.pandal.crowdLevel), shape: BoxShape.circle)),
                    Text(widget.pandal.crowdLevel.name.toUpperCase(),
                        style: TextStyle(
                            color: _crowdColor(widget.pandal.crowdLevel),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 24),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _ActionButton(
                        icon: Icons.directions_rounded,
                        label: AppStrings.get(lang, 'take_me_there'),
                        filled: true,
                        onTap: () => launchUrl(Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=${widget.pandal.lat},${widget.pandal.lng}'))),
                    _ActionButton(
                      icon: Icons.share_rounded,
                      label: AppStrings.get(lang, 'share_location'),
                      onTap: () {
                        // Language based sharing!
                        String msg = lang == AppLanguage.bengali
                            ? "আমি হপার্স অ্যাপে ${widget.pandal.name} দর্শন করেছি! আপনিও আসুন: https://bikkigits.github.io/hoppers"
                            : lang == AppLanguage.hindi
                                ? "मैंने हॉपर्स ऐप पर ${widget.pandal.name} दर्शन कर लिया है! आप भी आएं: https://bikkigits.github.io/hoppers"
                                : "I'm heading to ${widget.pandal.name} for Durga Puja! Join me via Hoppers: https://bikkigits.github.io/hoppers";
                        
                        final text = Uri.encodeComponent(msg);
                        final uri = Uri.parse('https://wa.me/?text=$text');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                    _ActionButton(
                        icon: visited ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                        label: AppStrings.get(lang, 'mark_visited'),
                        filled: visited,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(visitedProvider.notifier).toggle(widget.pandal.id);
                          if (!visited) {
                            _confettiController.play(); // Pop the confetti!
                          }
                        }),
                  ]),
                ],
              ),
            ),
          ),
        ),
        // The Confetti Widget overlayed on top of the card
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [HoppersColors.gold, HoppersColors.crimson, Colors.white],
          gravity: 0.2,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? HoppersColors.gold : Colors.white10,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: filled ? HoppersColors.midnight : Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: filled ? HoppersColors.midnight : Colors.white)),
          ]),
        ),
      ),
    );
  }
}

// (DUMMY CLASSES FOR NOW SO NO ERRORS THROW - TO BE IMPLEMENTED IF NEEDED LATER)
class MetroRouterDialog extends StatelessWidget {
  const MetroRouterDialog({super.key});
  @override Widget build(BuildContext context) => const AlertDialog(title: Text('Metro Router Coming Soon'));
}
class HopperPassportSheet extends StatelessWidget {
  const HopperPassportSheet({super.key});
  @override Widget build(BuildContext context) => const AlertDialog(title: Text('Passport'));
}
Future<void> showHopperPassportSheet(BuildContext context) async { showDialog(context: context, builder: (_) => const HopperPassportSheet()); }
Future<void> showSosSheet(BuildContext context) async { /* implementation */ }
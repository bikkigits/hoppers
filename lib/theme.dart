import 'dart:ui';
import 'package:flutter/material.dart';

class HoppersColors {
  HoppersColors._();
  static const Color midnight = Color(0xFF0B0F19);
  static const Color midnightHi = Color(0xFF121729);
  static const Color crimson = Color(0xFFE53935);
  static const Color gold = Color(0xFFFFB300);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFC7CCD9);
  static const Color crowdLow = Color(0xFF43A047);
  static const Color crowdMedium = Color(0xFFFFB300);
  static const Color crowdInsane = Color(0xFFE53935);
}

class HoppersGlass {
  HoppersGlass._();
  static const double blurSigma = 18;
  static final Color fill = Colors.black.withOpacity(0.6);
  static final Color border = Colors.white.withOpacity(0.12);
  static const double borderWidth = 1;
  static const double radius = 24;
}

ThemeData buildHoppersTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: HoppersColors.midnight,
    colorScheme: base.colorScheme.copyWith(surface: HoppersColors.midnight, primary: HoppersColors.gold, secondary: HoppersColors.crimson),
    textTheme: base.textTheme.apply(bodyColor: HoppersColors.textPrimary, displayColor: HoppersColors.textPrimary),
    iconTheme: const IconThemeData(color: HoppersColors.textPrimary),
  );
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.borderRadius, this.padding = const EdgeInsets.all(16)});
  final Widget child; final BorderRadius? borderRadius; final EdgeInsetsGeometry padding;
  @override Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(HoppersGlass.radius);
    return Container(
      clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: HoppersGlass.blurSigma, sigmaY: HoppersGlass.blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: HoppersGlass.fill, borderRadius: radius, border: Border.all(color: HoppersGlass.border, width: HoppersGlass.borderWidth)),
          child: child,
        ),
      ),
    );
  }
}
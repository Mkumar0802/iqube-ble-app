import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tier 1: raw colours, named by what they are. Only this file holds colour
/// literals; widgets read the semantic slots in [AppColors].
abstract final class Primitives {
  // Night blues (dark surfaces and the hero card in both themes).
  static const night04 = Color(0xFF060A13);
  static const night08 = Color(0xFF0C1322);
  static const night12 = Color(0xFF131C30);
  static const night18 = Color(0xFF1B2640);
  static const night22 = Color(0xFF202D4A);
  static const night26 = Color(0xFF28365A);

  // Paper (light surfaces).
  static const paper100 = Color(0xFFFFFFFF);
  static const paper96 = Color(0xFFF2F5FA);
  static const paper92 = Color(0xFFE7ECF5);
  static const paper86 = Color(0xFFD7DEEB);

  // Ink and mist (text).
  static const ink10 = Color(0xFF0B1220);
  static const ink40 = Color(0xFF56627A);
  static const mist96 = Color(0xFFF3F6FB);
  static const mist66 = Color(0xFF94A2BC);

  // Accents.
  static const blue60 = Color(0xFF4C86FF);
  static const blue45 = Color(0xFF1F5BE0);
  static const mint70 = Color(0xFF2DE6A6);
  static const mint40 = Color(0xFF0A8F62);
  static const amber65 = Color(0xFFFFB020);
  static const amber45 = Color(0xFFB36B00);
  static const red60 = Color(0xFFFF5263);
  static const red45 = Color(0xFFD42B3C);

  // EV electric teal/cyan.
  static const electricDark = Color(0xFF00E5CC);
  static const electricLight = Color(0xFF00B8A3);

  // Neon blue.
  static const neon = Color(0xFF00D4FF);

  // Purple for gradients.
  static const purple60 = Color(0xFF7C5CFC);

  // Glass / glassmorphism base.
  static const glassDark = Color(0xFF1A2540);
  static const glassLight = Color(0xFFE8EDF6);
}

/// Tier 2: colours by role.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.brand,
    required this.onBrand,
    required this.energy,
    required this.warning,
    required this.danger,
    required this.heroTop,
    required this.heroBottom,
    required this.heroGlow,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroTrack,
    required this.heroEnergy,
    required this.heroWarning,
    required this.heroDanger,
    required this.electric,
    required this.glass,
    required this.shimmer,
    required this.gradientStart,
    required this.gradientEnd,
    required this.heroElectric,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color hairline;
  final Color onSurface;
  final Color onSurfaceMuted;

  /// Main accent: buttons, selected tab, links.
  final Color brand;
  final Color onBrand;

  /// Good battery / charging / connected.
  final Color energy;
  final Color warning;
  final Color danger;

  /// The hero card is dark in both themes, so it has its own set.
  final Color heroTop;
  final Color heroBottom;
  final Color heroGlow;
  final Color onHero;
  final Color onHeroMuted;
  final Color heroTrack;
  final Color heroEnergy;
  final Color heroWarning;
  final Color heroDanger;

  /// EV accent colour (teal / cyan).
  final Color electric;

  /// Glassmorphism surface colour.
  final Color glass;

  /// Shimmer highlight colour.
  final Color shimmer;

  /// Animated gradient border start.
  final Color gradientStart;

  /// Animated gradient border end.
  final Color gradientEnd;

  /// Electric accent on hero card.
  final Color heroElectric;

  static const dark = AppColors(
    background: Primitives.night04,
    surface: Primitives.night08,
    surfaceHigh: Primitives.night12,
    hairline: Primitives.night18,
    onSurface: Primitives.mist96,
    onSurfaceMuted: Primitives.mist66,
    brand: Primitives.blue60,
    onBrand: Primitives.night04,
    energy: Primitives.mint70,
    warning: Primitives.amber65,
    danger: Primitives.red60,
    heroTop: Primitives.night18,
    heroBottom: Primitives.night08,
    heroGlow: Primitives.blue60,
    onHero: Primitives.mist96,
    onHeroMuted: Primitives.mist66,
    heroTrack: Primitives.night26,
    heroEnergy: Primitives.mint70,
    heroWarning: Primitives.amber65,
    heroDanger: Primitives.red60,
    electric: Primitives.electricDark,
    glass: Primitives.glassDark,
    shimmer: Primitives.neon,
    gradientStart: Primitives.electricDark,
    gradientEnd: Primitives.purple60,
    heroElectric: Primitives.electricDark,
  );

  static const light = AppColors(
    background: Primitives.paper96,
    surface: Primitives.paper100,
    surfaceHigh: Primitives.paper92,
    hairline: Primitives.paper86,
    onSurface: Primitives.ink10,
    onSurfaceMuted: Primitives.ink40,
    brand: Primitives.blue45,
    onBrand: Primitives.paper100,
    energy: Primitives.mint40,
    warning: Primitives.amber45,
    danger: Primitives.red45,
    heroTop: Primitives.night18,
    heroBottom: Primitives.night04,
    heroGlow: Primitives.blue60,
    onHero: Primitives.mist96,
    onHeroMuted: Primitives.mist66,
    heroTrack: Primitives.night26,
    heroEnergy: Primitives.mint70,
    heroWarning: Primitives.amber65,
    heroDanger: Primitives.red60,
    electric: Primitives.electricLight,
    glass: Primitives.glassLight,
    shimmer: Primitives.blue60,
    gradientStart: Primitives.electricLight,
    gradientEnd: Primitives.purple60,
    heroElectric: Primitives.electricLight,
  );

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColors>();
    assert(ext != null, 'AppColors missing. Build ThemeData via buildAppTheme().');
    return ext!;
  }

  /// Battery level colour on normal surfaces. The level is always shown as
  /// a number too, so colour is never the only signal.
  Color level(int percent) =>
      percent <= 15 ? danger : (percent <= 35 ? warning : energy);

  /// Battery level colour on the dark hero card.
  Color heroLevel(int percent) =>
      percent <= 15 ? heroDanger : (percent <= 35 ? heroWarning : heroEnergy);

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? hairline,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? brand,
    Color? onBrand,
    Color? energy,
    Color? warning,
    Color? danger,
    Color? heroTop,
    Color? heroBottom,
    Color? heroGlow,
    Color? onHero,
    Color? onHeroMuted,
    Color? heroTrack,
    Color? heroEnergy,
    Color? heroWarning,
    Color? heroDanger,
    Color? electric,
    Color? glass,
    Color? shimmer,
    Color? gradientStart,
    Color? gradientEnd,
    Color? heroElectric,
  }) =>
      AppColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        hairline: hairline ?? this.hairline,
        onSurface: onSurface ?? this.onSurface,
        onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
        brand: brand ?? this.brand,
        onBrand: onBrand ?? this.onBrand,
        energy: energy ?? this.energy,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        heroTop: heroTop ?? this.heroTop,
        heroBottom: heroBottom ?? this.heroBottom,
        heroGlow: heroGlow ?? this.heroGlow,
        onHero: onHero ?? this.onHero,
        onHeroMuted: onHeroMuted ?? this.onHeroMuted,
        heroTrack: heroTrack ?? this.heroTrack,
        heroEnergy: heroEnergy ?? this.heroEnergy,
        heroWarning: heroWarning ?? this.heroWarning,
        heroDanger: heroDanger ?? this.heroDanger,
        electric: electric ?? this.electric,
        glass: glass ?? this.glass,
        shimmer: shimmer ?? this.shimmer,
        gradientStart: gradientStart ?? this.gradientStart,
        gradientEnd: gradientEnd ?? this.gradientEnd,
        heroElectric: heroElectric ?? this.heroElectric,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      hairline: c(hairline, other.hairline),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceMuted: c(onSurfaceMuted, other.onSurfaceMuted),
      brand: c(brand, other.brand),
      onBrand: c(onBrand, other.onBrand),
      energy: c(energy, other.energy),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      heroTop: c(heroTop, other.heroTop),
      heroBottom: c(heroBottom, other.heroBottom),
      heroGlow: c(heroGlow, other.heroGlow),
      onHero: c(onHero, other.onHero),
      onHeroMuted: c(onHeroMuted, other.onHeroMuted),
      heroTrack: c(heroTrack, other.heroTrack),
      heroEnergy: c(heroEnergy, other.heroEnergy),
      heroWarning: c(heroWarning, other.heroWarning),
      heroDanger: c(heroDanger, other.heroDanger),
      electric: c(electric, other.electric),
      glass: c(glass, other.glass),
      shimmer: c(shimmer, other.shimmer),
      gradientStart: c(gradientStart, other.gradientStart),
      gradientEnd: c(gradientEnd, other.gradientEnd),
      heroElectric: c(heroElectric, other.heroElectric),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColors &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          surface == other.surface &&
          surfaceHigh == other.surfaceHigh &&
          hairline == other.hairline &&
          onSurface == other.onSurface &&
          onSurfaceMuted == other.onSurfaceMuted &&
          brand == other.brand &&
          onBrand == other.onBrand &&
          energy == other.energy &&
          warning == other.warning &&
          danger == other.danger &&
          heroTop == other.heroTop &&
          heroBottom == other.heroBottom &&
          heroGlow == other.heroGlow &&
          onHero == other.onHero &&
          onHeroMuted == other.onHeroMuted &&
          heroTrack == other.heroTrack &&
          heroEnergy == other.heroEnergy &&
          heroWarning == other.heroWarning &&
          heroDanger == other.heroDanger &&
          electric == other.electric &&
          glass == other.glass &&
          shimmer == other.shimmer &&
          gradientStart == other.gradientStart &&
          gradientEnd == other.gradientEnd &&
          heroElectric == other.heroElectric;

  @override
  int get hashCode => Object.hashAll([
        background,
        surface,
        surfaceHigh,
        hairline,
        onSurface,
        onSurfaceMuted,
        brand,
        onBrand,
        energy,
        warning,
        danger,
        heroTop,
        heroBottom,
        heroGlow,
        onHero,
        onHeroMuted,
        heroTrack,
        heroEnergy,
        heroWarning,
        heroDanger,
        electric,
        glass,
        shimmer,
        gradientStart,
        gradientEnd,
        heroElectric,
      ]);
}

/// Durations and curves by role.
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion();

  /// Press and toggle feedback.
  Duration get fast => const Duration(milliseconds: 160);

  /// Cards and content changing in place.
  Duration get medium => const Duration(milliseconds: 320);

  /// Screen content entering.
  Duration get slow => const Duration(milliseconds: 520);

  /// Numbers counting up and the battery filling.
  Duration get fill => const Duration(milliseconds: 1100);

  /// Delay between items entering one after another.
  Duration get stagger => const Duration(milliseconds: 70);

  /// One loop of the liquid wave.
  Duration get wave => const Duration(milliseconds: 3200);

  /// One loop of a status pulse.
  Duration get pulse => const Duration(milliseconds: 1600);

  Curve get enter => Curves.easeOutCubic;
  Curve get emphasized => Curves.easeInOutCubic;

  /// Page transition duration.
  Duration get pageTransition => const Duration(milliseconds: 400);

  /// Shimmer animation loop.
  Duration get shimmer => const Duration(milliseconds: 1800);

  /// Gradient rotation animation loop.
  Duration get gradientRotation => const Duration(milliseconds: 3000);

  /// Breathe / glow animation loop.
  Duration get breathe => const Duration(milliseconds: 2400);

  /// Radar sweep animation loop.
  Duration get radar => const Duration(milliseconds: 2000);

  /// Count-up animation.
  Duration get countUp => const Duration(milliseconds: 900);

  /// Spring curve for bouncy entrances.
  Curve get spring => Curves.elasticOut;

  /// Decelerate curve for natural stops.
  Curve get decelerate => Curves.decelerate;

  static AppMotion of(BuildContext context) {
    final ext = Theme.of(context).extension<AppMotion>();
    assert(ext != null, 'AppMotion missing. Build ThemeData via buildAppTheme().');
    return ext!;
  }

  @override
  AppMotion copyWith() => this;

  // Nothing to interpolate: the values are the same in both themes.
  @override
  AppMotion lerp(AppMotion? other, double t) => this;
}

/// Zero when the user has turned animations off in the system settings.
Duration resolveMotion(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;

/// Corner radii and spacing.
abstract final class AppShape {
  static const double cardRadius = 26;
  static const double innerRadius = 16;
  static const double pillRadius = 999;
  static const double glassRadius = 20;
  static const double gap = 12;
  static const double page = 16;

  static const card = BorderRadius.all(Radius.circular(cardRadius));
  static const inner = BorderRadius.all(Radius.circular(innerRadius));
  static const pill = BorderRadius.all(Radius.circular(pillRadius));
  static const glass = BorderRadius.all(Radius.circular(glassRadius));
}

/// Number styles: tabular digits so counting numbers don't jitter.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  static final hero = GoogleFonts.outfit(
    fontSize: 64,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
    fontFeatures: _tabular,
  );

  static final heroSmall = GoogleFonts.outfit(
    fontSize: 44,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );

  static final metric = GoogleFonts.outfit(
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  static final gauge = GoogleFonts.outfit(
    fontSize: 32,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );

  static final unit = GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static final caption = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static final overline = GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final c = dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.surfaceHigh,
    onPrimaryContainer: c.onSurface,
    secondary: c.energy,
    onSecondary: c.onBrand,
    secondaryContainer: c.surfaceHigh,
    onSecondaryContainer: c.onSurface,
    tertiary: c.warning,
    onTertiary: c.onBrand,
    error: c.danger,
    onError: c.onBrand,
    surface: c.surface,
    onSurface: c.onSurface,
    onSurfaceVariant: c.onSurfaceMuted,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceHigh,
    surfaceContainerHighest: c.surfaceHigh,
    surfaceTint: Colors.transparent,
    outline: c.onSurfaceMuted,
    outlineVariant: c.hairline,
    shadow: Primitives.night04,
    scrim: Primitives.night04,
    inverseSurface: c.onSurface,
    onInverseSurface: c.surface,
    inversePrimary: c.brand,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    extensions: [c, const AppMotion()],
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
  final text = GoogleFonts.outfitTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: text.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodySmall: text.bodySmall?.copyWith(color: c.onSurfaceMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // The size is stated here: the theme's text styles carry no sizes
      // until a widget reads them through Theme.of.
      titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: c.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.card,
        side: BorderSide(color: c.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: c.onSurfaceMuted,
      subtitleTextStyle: text.bodySmall?.copyWith(color: c.onSurfaceMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.brand.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          AppText.unit.copyWith(
              fontSize: 12,
              color: states.contains(WidgetState.selected)
                  ? c.onSurface
                  : c.onSurfaceMuted)),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.brand
              : c.onSurfaceMuted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: const StadiumBorder(),
        side: BorderSide(color: c.hairline),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? c.onBrand : c.onSurfaceMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? c.brand : c.surfaceHigh),
      trackOutlineColor: WidgetStatePropertyAll(c.hairline),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppShape.cardRadius))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppShape.card),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.onSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.surface),
      shape: const RoundedRectangleBorder(borderRadius: AppShape.inner),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.brand,
      linearTrackColor: c.surfaceHigh,
      circularTrackColor: c.surfaceHigh,
    ),
  );
}

/// Linear interpolation helper for painters.
double lerpD(double a, double b, double t) => lerpDouble(a, b, t)!;

/// Glassmorphism container used across the app.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.borderRadius});
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppShape.glass,
        color: c.glass.withValues(alpha: 0.7),
        border: Border.all(color: c.hairline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: c.background.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

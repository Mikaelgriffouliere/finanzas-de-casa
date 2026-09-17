import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palettes.dart';

class ThemeNotifier {
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );
  final ValueNotifier<AppPalette> palette = ValueNotifier<AppPalette>(
    AppPalettes.profesional,
  );

  void setLight() => mode.value = ThemeMode.light;
  void setDark() => mode.value = ThemeMode.dark;
  void setSystem() => mode.value = ThemeMode.system;

  void selectPalette(AppPalette value) {
    AppColors.use(value);
    palette.value = value;
  }
}

/// Preferencia de colores dinámicos del sistema (Android 12+).
class DynamicColorSettings {
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
}

/// Transición de pantalla por defecto: fade + deslizamiento vertical sutil.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Sora';

  static final ThemeNotifier notifier = ThemeNotifier();

  static ThemeData light() {
    AppColors.use(AppTheme.notifier.palette.value);
    final scheme = _scheme(isDark: false);
    return _build(scheme, isDark: false);
  }

  static ThemeData dark() {
    AppColors.use(AppTheme.notifier.palette.value);
    final scheme = _scheme(isDark: true);
    return _build(scheme, isDark: true);
  }

  static ColorScheme _scheme({required bool isDark}) {
    final seed = AppTheme.notifier.palette.value.primary;
    final scheme = DynamicColorSettings.enabled.value
        ? ColorScheme.fromSeed(
            seedColor: seed,
            brightness: isDark ? Brightness.dark : Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          )
        : ColorScheme.fromSeed(
            seedColor: seed,
            brightness: isDark ? Brightness.dark : Brightness.light,
          );
    return _inkShell(scheme, isDark);
  }

  /// Superficies "tinta" nítidas y profesionales: fondo y tarjetas en blanco
  /// con grises azulados limpios en claro, y azul marino profundo en noche.
  /// Textos de alto contraste y bordes finos. El azul semilla queda como
  /// acento de marca.
  static ColorScheme _inkShell(ColorScheme s, bool isDark) {
    if (isDark) {
      return s.copyWith(
        surface: const Color(0xFF131B30),
        surfaceBright: const Color(0xFF1A2540),
        surfaceDim: const Color(0xFF0D1426),
        surfaceContainerLowest: const Color(0xFF0A0F1F),
        surfaceContainerLow: const Color(0xFF10182B),
        surfaceContainer: const Color(0xFF141E38),
        surfaceContainerHigh: const Color(0xFF1A2542),
        surfaceContainerHighest: const Color(0xFF21304F),
        onSurface: const Color(0xFFE9EFFB),
        onSurfaceVariant: const Color(0xFF94A4C6),
        outline: const Color(0xFF5D6E93),
        outlineVariant: const Color(0xFF2A3656),
      );
    }
    return s.copyWith(
      surface: Colors.white,
      surfaceBright: Colors.white,
      surfaceDim: const Color(0xFFE4E9F2),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F7FB),
      surfaceContainer: const Color(0xFFF0F3F9),
      surfaceContainerHigh: const Color(0xFFEAF0F7),
      surfaceContainerHighest: const Color(0xFFE4EAF3),
      onSurface: const Color(0xFF0E1626),
      onSurfaceVariant: const Color(0xFF5B6B84),
      outline: const Color(0xFF98A7BF),
      outlineVariant: const Color(0xFFE3E9F4),
    );
  }

  static ThemeData _build(ColorScheme scheme, {required bool isDark}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTheme.fontFamily,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    final radius = 20.0;
    const radiusSm = 14.0;

    final tt = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: isDark
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      textTheme: tt.copyWith(
        displaySmall: tt.displaySmall?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.15,
        ),
        headlineMedium: tt.headlineMedium?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.15,
        ),
        headlineSmall: tt.headlineSmall?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleLarge: tt.titleLarge?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: tt.titleMedium?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: tt.titleSmall?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: tt.bodyLarge?.copyWith(height: 1.3, letterSpacing: 0.1),
        bodyMedium: tt.bodyMedium?.copyWith(height: 1.35, letterSpacing: 0.1),
        labelLarge: tt.labelLarge?.copyWith(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelMedium: tt.labelMedium?.copyWith(letterSpacing: 0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: isDark ? scheme.surfaceContainerLow : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.5 : 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: isDark
                ? scheme.outlineVariant.withValues(alpha: 0.7)
                : scheme.outlineVariant,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontFamily: AppTheme.fontFamily,
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: isDark ? scheme.surfaceContainerLow : scheme.surface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant;
          return tt.labelMedium?.copyWith(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: color,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: tt.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: tt.labelLarge?.copyWith(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        circularTrackColor: scheme.surfaceContainerHighest.withValues(
          alpha: 0.7,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.surface;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
        },
      ),
    );
  }
}

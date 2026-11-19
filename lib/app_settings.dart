import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paleta de colores disponible para toda la aplicación.
class AppPalette {
  const AppPalette({
    required this.name,
    required this.description,
    required this.seed,
    required this.accent,
  });

  final String name;
  final String description;
  final Color seed;
  final Color accent;
}

AppPalette paletteFor(int index) =>
    appPalettes[index >= 0 && index < appPalettes.length ? index : 0];

const appPalettes = <AppPalette>[
  AppPalette(
    name: 'Verde Cuentas',
    description: 'El look original de Cuentas Claras',
    seed: Color(0xFF155C4B),
    accent: Color(0xFF2E7D5B),
  ),
  AppPalette(
    name: 'Azul tranquilo',
    description: 'Tonos fríos y sobrios',
    seed: Color(0xFF2E5A88),
    accent: Color(0xFF4F78A1),
  ),
  AppPalette(
    name: 'Vino cálido',
    description: 'Tonos tierra y bordó',
    seed: Color(0xFF8A3B4C),
    accent: Color(0xFFB36A8C),
  ),
  AppPalette(
    name: 'Morado',
    description: 'Una opción moderna y bien diferenciada',
    seed: Color(0xFF5E4B8A),
    accent: Color(0xFF8A6C9D),
  ),
];

/// Logos disponibles. Se guarda la clave, no el ícono, para que los cambios
/// de versión de Flutter no rompan la preferencia elegida.
class LogoOption {
  const LogoOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const logoOptions = <LogoOption>[
  LogoOption(key: 'savings', label: 'Ahorro', icon: Icons.savings_rounded),
  LogoOption(
    key: 'wallet',
    label: 'Billetera',
    icon: Icons.account_balance_wallet_rounded,
  ),
  LogoOption(
    key: 'family',
    label: 'Familia',
    icon: Icons.family_restroom_rounded,
  ),
  LogoOption(key: 'chart', label: 'Análisis', icon: Icons.analytics_rounded),
  LogoOption(key: 'home', label: 'Hogar', icon: Icons.home_rounded),
  LogoOption(key: 'nest', label: 'Cuentas', icon: Icons.eco_rounded),
];

IconData logoIcon(String key) {
  for (final option in logoOptions) {
    if (option.key == key) return option.icon;
  }
  return Icons.savings_rounded;
}

class AppSettingsData {
  const AppSettingsData({
    this.paletteIndex = 0,
    this.logoKey = 'savings',
    this.username = '',
    this.password = '',
    this.onboardingCompleted = false,
    this.registrationCompleted = false,
  });

  final int paletteIndex;
  final String logoKey;
  final String username;
  final String password;

  /// La introducción animada se muestra solo en el primer ingreso.
  final bool onboardingCompleted;

  /// Los usuarios nuevos crean sus credenciales después del onboarding.
  final bool registrationCompleted;

  /// No hay credenciales prefijadas: mientras estén vacías, la app debe
  /// llevar al registro antes de mostrar el login.
  bool get hasCredentials => username.isNotEmpty && password.isNotEmpty;

  /// Las credenciales históricas `admin` / `admin123` no cuentan como un
  /// registro real. Solo se aceptan si el usuario las eligió explícitamente
  /// después de este cambio (flag `registration_completed` en `true`).
  bool get usesLegacyDefaultCredentials =>
      username.toLowerCase() == 'admin' && password == 'admin123';

  AppSettingsData copyWith({
    int? paletteIndex,
    String? logoKey,
    String? username,
    String? password,
    bool? onboardingCompleted,
    bool? registrationCompleted,
  }) {
    return AppSettingsData(
      paletteIndex: paletteIndex ?? this.paletteIndex,
      logoKey: logoKey ?? this.logoKey,
      username: username ?? this.username,
      password: password ?? this.password,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      registrationCompleted:
          registrationCompleted ?? this.registrationCompleted,
    );
  }
}

/// Configuración global de la app, persistida con SharedPreferences.
class AppSettings {
  AppSettings._();

  static final instance = AppSettings._();

  final ValueNotifier<AppSettingsData> values = ValueNotifier(
    const AppSettingsData(),
  );

  SharedPreferences? _preferences;

  AppSettingsData get current => values.value;

  AppPalette get palette => paletteFor(current.paletteIndex);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    // Clave nueva, con respaldo de la vieja para no repetir la introducción
    // a quien ya la vio en una versión anterior.
    final onboardingCompleted =
        preferences.getBool(_Keys.onboardingCompleted) ??
        preferences.getBool(_Keys.legacyIntroCompleted) ??
        false;
    final username = preferences.getString(_Keys.username) ?? '';
    final password = preferences.getString(_Keys.password) ?? '';
    final data = AppSettingsData(
      paletteIndex: preferences.getInt(_Keys.palette) ?? 0,
      logoKey: preferences.getString(_Keys.logo) ?? 'savings',
      username: username,
      password: password,
      onboardingCompleted: onboardingCompleted,
      registrationCompleted:
          preferences.getBool(_Keys.registrationCompleted) ?? false,
    );
    // Un arranque fresco no tiene credenciales. Tampoco se considera
    // registrado a un perfil anterior que solo guardó los valores de ejemplo
    // `admin` / `admin123`: deben elegir los suyos.
    final needsRegistration =
        !data.hasCredentials ||
        (data.usesLegacyDefaultCredentials && !data.registrationCompleted);
    values.value = data.copyWith(
      registrationCompleted: needsRegistration
          ? false
          : data.registrationCompleted,
    );
  }

  /// Marca la introducción como vista (o saltada) y la persiste.
  Future<void> markOnboardingCompleted() =>
      update(current.copyWith(onboardingCompleted: true));

  /// Guarda las credenciales creadas por un usuario nuevo.
  Future<void> completeRegistration({
    required String username,
    required String password,
  }) => update(
    current.copyWith(
      username: username,
      password: password,
      registrationCompleted: true,
    ),
  );

  /// Restablece solo las credenciales cuando el usuario las olvidó.
  ///
  /// Conserva la base de datos y el onboarding: se vuelve al registro, no a
  /// la introducción ni a una pantalla de login sin credenciales válidas.
  Future<void> resetCredentials() => update(
    current.copyWith(username: '', password: '', registrationCompleted: false),
  );

  /// Permite volver a ver la introducción desde Configuración.
  Future<void> resetOnboarding() =>
      update(current.copyWith(onboardingCompleted: false));

  Future<void> update(AppSettingsData data) async {
    values.value = data;
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setInt(_Keys.palette, data.paletteIndex);
    await preferences.setString(_Keys.logo, data.logoKey);
    await preferences.setString(_Keys.username, data.username);
    await preferences.setString(_Keys.password, data.password);
    await preferences.setBool(
      _Keys.onboardingCompleted,
      data.onboardingCompleted,
    );
    await preferences.setBool(
      _Keys.registrationCompleted,
      data.registrationCompleted,
    );
  }
}

abstract final class _Keys {
  static const palette = 'settings_palette';
  static const logo = 'settings_logo';
  static const username = 'settings_username';
  static const password = 'settings_password';
  static const onboardingCompleted = 'onboarding_completed';
  static const registrationCompleted = 'registration_completed';
  static const legacyIntroCompleted = 'settings_intro_completed';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:finanzas_personales/amount_parser.dart';
import 'package:finanzas_personales/app_settings.dart';
import 'package:finanzas_personales/category_visuals.dart';
import 'package:finanzas_personales/finance_database.dart';
import 'package:finanzas_personales/pdf_saver.dart';
import 'package:finanzas_personales/onboarding/onboarding.dart';
import 'package:finanzas_personales/register_screen.dart';
import 'package:finanzas_personales/settings_screen.dart';

/// SQLite por FFI depende de una biblioteca nativa que solo está disponible en
/// escritorio. En Android/iOS se usa el plugin `sqflite`, y en web el factory
/// WASM; forzar FFI allí hace que la base nunca abra y la app quede cargando.
bool _shouldUseFfi() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR', 'AR');
  if (_shouldUseFfi()) {
    FinanceDatabase.initializeFfi(noIsolate: true);
  }
  await AppSettings.instance.load();
  runApp(const FinanceApp());
}

final _money = NumberFormat.currency(
  locale: 'es_AR',
  symbol: r'$',
  decimalDigits: 2,
);
final _day = DateFormat('d MMM yyyy', 'es_AR');

String formatMoney(double value) => _money.format(value);
String formatDay(DateTime date) => _day.format(date);

/// Las transacciones guardan el *nombre* de la categoría, pero los íconos se
/// definen por su clave (`comida`, `transporte`, ...). Resuelve el estilo
/// buscando la categoría en la base y usa un fallback legible si ya no existe.
CategoryStyle _styleForEntry(
  FinanceEntry entry,
  List<FinanceCategory> categories,
) {
  final category = categories.firstWhere(
    (item) => item.name.toLowerCase() == entry.category.toLowerCase(),
    orElse: () => FinanceCategory(
      name: entry.category,
      isIncome: entry.isIncome,
      icon: entry.category.toLowerCase().replaceAll(' ', '_'),
      color: entry.isIncome ? 0xFF155C4B : 0xFFCC6E3D,
    ),
  );
  return CategoryStyle.from(category);
}

/// Devuelve cuánto aportó cada integrante en un movimiento.
/// Si es compartido, usa los montos guardados para cada uno; si no, usa el
/// integrante asignado como pago completo.
List<({String name, double amount})> _memberShares(
  FinanceEntry entry,
  Map<int, FinanceMember> byId,
) {
  if (entry.isShared && entry.shares.isNotEmpty) {
    return [
      for (final share in entry.shares)
        (
          name: byId[share.memberId]?.name ?? 'Sin asignar',
          amount: share.amount,
        ),
    ];
  }
  final name = entry.memberId == null
      ? 'Sin asignar'
      : byId[entry.memberId]?.name ?? 'Sin asignar';
  return [(name: name, amount: entry.amount)];
}

String _sharesLabel(List<({String name, double amount})> shares) => shares
    .map((share) => '${share.name} ${formatMoney(share.amount)}')
    .join(' · ');

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key});

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  bool _loggedIn = false;

  void _doLogin() => setState(() => _loggedIn = true);
  void _doLogout() => setState(() => _loggedIn = false);

  /// Sin credenciales guardadas no existe un login por defecto: se obliga a
  /// pasar por el registro, incluso si la introducción ya se vio.
  bool _needsRegistration(AppSettingsData settings) =>
      !settings.registrationCompleted || !settings.hasCredentials;

  void _finishIntro() => AppSettings.instance.markOnboardingCompleted();

  Future<void> _finishRegistration(String username, String password) async {
    await AppSettings.instance.completeRegistration(
      username: username,
      password: password,
    );
    if (mounted) setState(() => _loggedIn = true);
  }

  /// Recuperación local: borra solo credenciales y vuelve al registro.
  Future<void> _resetCredentials() async {
    await AppSettings.instance.resetCredentials();
    if (mounted) setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppSettingsData>(
    valueListenable: AppSettings.instance.values,
    builder: (context, settings, _) {
      final palette = paletteFor(settings.paletteIndex);
      return MaterialApp(
        title: 'Cuentas Claras',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: palette.seed,
          appBarTheme: AppBarTheme(
            backgroundColor: palette.seed,
            foregroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: palette.seed),
        themeMode: ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'AR'),
          Locale('es'),
          Locale('en'),
        ],
        locale: const Locale('es', 'AR'),
        home: _needsRegistration(settings)
            ? (!settings.onboardingCompleted
                  ? OnboardingScreen(onFinished: _finishIntro)
                  : RegisterScreen(onRegistered: _finishRegistration))
            : (_loggedIn
                  ? (!settings.onboardingCompleted
                        ? OnboardingScreen(onFinished: _finishIntro)
                        : FinanceHome(onLogout: _doLogout))
                  : LoginScreen(
                      onLoggedIn: _doLogin,
                      onForgotCredentials: _resetCredentials,
                    )),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.onLoggedIn, this.onForgotCredentials, super.key});

  final VoidCallback? onLoggedIn;
  final Future<void> Function()? onForgotCredentials;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final settings = AppSettings.instance.current;
    final userMatches =
        _user.text.trim().toLowerCase() == settings.username.toLowerCase();
    if (userMatches && _password.text == settings.password) {
      widget.onLoggedIn?.call();
      return;
    }
    setState(() => _error = 'Usuario o contraseña incorrectos.');
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Restablecer credenciales?'),
        content: const Text(
          'Se borrarán solo el usuario y la contraseña. Tus movimientos, '
          'categorías e integrantes se conservan. Después deberás crear unos '
          'nuevos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onForgotCredentials?.call();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<AppSettingsData>(
                    valueListenable: AppSettings.instance.values,
                    builder: (context, settings, _) {
                      return Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: paletteFor(settings.paletteIndex).accent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            logoIcon(settings.logoKey),
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Cuentas Claras',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tu dinero, en orden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF757575), fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ingresá a tu cuenta',
                          style: TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _user,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Ingresá tu usuario'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.isEmpty ?? true)
                              ? 'Ingresá tu contraseña'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFCF6679),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFCF6679),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _submit,
                            child: const Text('Iniciar sesión'),
                          ),
                        ),
                        if (widget.onForgotCredentials != null) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _confirmReset,
                            child: const Text('¿Olvidaste tus credenciales?'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Navegación principal
// ---------------------------------------------------------------------------

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  final ValueNotifier<int> _refresh = ValueNotifier<int>(0);
  int _currentPage = 0;
  String? _message;
  Timer? _messageTimer;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _refresh.dispose();
    super.dispose();
  }

  void _navigateTo(int page) => setState(() => _currentPage = page);

  void _reload() => _refresh.value++;

  void _showMessage(String message) {
    setState(() => _message = message);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  Future<void> _openEntryForm({FinanceEntry? entry}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => EntryFormScreen(entry: entry)),
    );
    if (saved == true && mounted) {
      _reload();
      _showMessage(
        entry == null ? 'Movimiento guardado' : 'Movimiento actualizado',
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(onReplayIntro: _replayIntro),
      ),
    );
    if (mounted) _reload();
  }

  /// Vuelve a mostrar la introducción sin cambiar el flag persistido: es una
  /// repetición voluntaria, no un primer inicio.
  Future<void> _replayIntro() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => OnboardingScreen(onFinished: () => navigator.pop(true)),
      ),
    );
  }

  Widget get _currentScreen => switch (_currentPage) {
    0 => DashboardScreen(
      refresh: _refresh,
      onEdit: _openEntryForm,
      onOpenAnalysis: () => _navigateTo(1),
      onOpenActivity: () => _navigateTo(2),
    ),
    1 => AnalysisScreen(refresh: _refresh),
    2 => ActivityScreen(refresh: _refresh, onEdit: _openEntryForm),
    3 => FamilyScreen(refresh: _refresh),
    _ => CategoriesScreen(refresh: _refresh),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: ValueListenableBuilder<AppSettingsData>(
        valueListenable: AppSettings.instance.values,
        builder: (context, settings, _) => Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: paletteFor(settings.paletteIndex).accent,
            child: Icon(
              logoIcon(settings.logoKey),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
      title: const Text('Cuentas Claras'),
      actions: [
        IconButton(
          tooltip: 'Configuración',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
        ),
        IconButton(
          tooltip: 'Informes',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          ),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
      ],
    ),
    body: Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_currentPage),
            child: _currentScreen,
          ),
        ),
        if (_message != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF155C4B),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentPage,
      onTap: _navigateTo,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF155C4B),
      unselectedItemColor: Colors.grey.shade600,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          label: 'Análisis',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_rounded),
          label: 'Actividad',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.family_restroom_rounded),
          label: 'Familia',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.category_outlined),
          label: 'Categorías',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openEntryForm(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuevo movimiento'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Pantalla de inicio / panel
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.refresh,
    required this.onEdit,
    required this.onOpenAnalysis,
    required this.onOpenActivity,
    super.key,
  });

  final ValueNotifier<int> refresh;
  final Future<void> Function({FinanceEntry? entry}) onEdit;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onOpenActivity;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ValueNotifier<int> _refresh;
  List<FinanceEntry> _entries = [];
  List<FinanceMember> _members = [];
  List<FinanceCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh = widget.refresh;
    _refresh.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    try {
      final database = FinanceDatabase.instance;
      final entries = await database.getEntries();
      final members = await database.getMembers();
      final categories = await database.getCategories();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _members = members;
        _categories = categories;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Map<int, FinanceMember> get _memberById => {
    for (final member in _members)
      if (member.id != null) member.id!: member,
  };

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Color(0xFFCF6679),
              ),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar la información',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final incomes = _entries
        .where((entry) => entry.isIncome)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final expenses = _entries
        .where((entry) => !entry.isIncome)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final balance = incomes - expenses;
    final total = incomes + expenses;
    final incomeShare = total > 0 ? incomes / total : 0.0;
    final recent = _entries.take(5).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text(
            'Tu dinero, en orden.',
            style: TextStyle(color: Color(0xFF757575), fontSize: 14),
          ),
          const SizedBox(height: 4),
          _AnimatedEntrance(
            interval: const Interval(0.0, 0.4, curve: Curves.easeOut),
            child: const Text(
              'Resumen de tus finanzas',
              style: TextStyle(
                color: Color(0xFF212121),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AnimatedEntrance(
            interval: const Interval(0.15, 0.8, curve: Curves.easeOut),
            child: Card(
              elevation: 0,
              color: const Color(0xFF155C4B),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance total',
                      style: TextStyle(color: Color(0xFFD7E8E1), fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    _CountUpText(
                      value: balance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceTile(
                            label: 'Ingresos',
                            value: incomes,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BalanceTile(
                            label: 'Gastos',
                            value: expenses,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: incomeShare),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, share, _) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 8,
                                  child: Stack(
                                    children: [
                                      Container(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: constraints.maxWidth * share,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ingresos ${(incomeShare * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFFD7E8E1),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Gastos ${((1 - incomeShare) * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFFD7E8E1),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Actividad reciente',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: widget.onOpenActivity,
                child: const Text('Ver todo'),
              ),
            ],
          ),
          if (recent.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Todavía no cargaste movimientos.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final entry in recent)
                    _EntryTile(
                      entry: entry,
                      style: _styleForEntry(entry, _categories),
                      member: entry.memberId == null
                          ? null
                          : _memberById[entry.memberId],
                      shares: _memberShares(entry, _memberById),
                      onTap: () => widget.onEdit(entry: entry),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF155C4B),
              ),
              title: const Text(
                'Ver análisis',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Por categoría e integrante'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenAnalysis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFFD7E8E1))),
          ],
        ),
        const SizedBox(height: 6),
        _CountUpText(
          value: value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

/// Entrada escalonada: aparece con fade y un pequeño deslizamiento vertical.
class _AnimatedEntrance extends StatelessWidget {
  const _AnimatedEntrance({required this.interval, required this.child});

  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: const Duration(milliseconds: 650),
    curve: interval,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

/// Número que se cuenta desde cero (o desde el valor anterior al cambiar).
class _CountUpText extends StatelessWidget {
  const _CountUpText({required this.value, required this.style});

  final double value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: value),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, animated, _) =>
        Text(formatMoney(animated), style: style),
  );
}

// ---------------------------------------------------------------------------
// Fila reutilizable de movimiento
// ---------------------------------------------------------------------------

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.style,
    required this.onTap,
    this.member,
    this.shares = const <({String name, double amount})>[],
    this.onDismiss,
  });

  final FinanceEntry entry;
  final CategoryStyle style;
  final FinanceMember? member;
  final List<({String name, double amount})> shares;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: style.background,
        child: Icon(style.icon, color: style.color),
      ),
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatDay(entry.date)}'
            '${member == null ? '' : '  ·  ${member!.name}'}',
          ),
          if (entry.isShared && shares.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _sharesLabel(shares),
                style: const TextStyle(fontSize: 11, color: Color(0xFF155C4B)),
              ),
            ),
        ],
      ),
      trailing: Text(
        '${entry.isIncome ? '+' : '−'}${formatMoney(entry.amount)}',
        style: TextStyle(
          color: entry.isIncome
              ? const Color(0xFF155C4B)
              : Colors.grey.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onDismiss == null) return tile;
    return Dismissible(
      key: ValueKey(entry.id ?? entry.title),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => _confirmDelete(context),
      onDismissed: (_) => onDismiss!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFCF6679),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: tile,
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar movimiento?'),
      content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---------------------------------------------------------------------------
// Actividad con filtro por integrante
// ---------------------------------------------------------------------------

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.refresh,
    required this.onEdit,
    super.key,
  });

  final ValueNotifier<int> refresh;
  final Future<void> Function({FinanceEntry? entry}) onEdit;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ValueNotifier<int> _refresh;
  List<FinanceEntry> _entries = [];
  List<FinanceMember> _members = [];
  List<FinanceCategory> _categories = [];
  int? _memberFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh = widget.refresh;
    _refresh.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final database = FinanceDatabase.instance;
    final entries = await database.getEntries();
    final members = await database.getMembers();
    final categories = await database.getCategories();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _members = members;
      _categories = categories;
      _loading = false;
    });
  }

  Map<int, FinanceMember> get _memberById => {
    for (final member in _members)
      if (member.id != null) member.id!: member,
  };

  List<FinanceEntry> get _visible {
    if (_memberFilter == null) return _entries;
    if (_memberFilter == -1) {
      return _entries
          .where(
            (entry) => entry.memberId == null && entry.sharedMemberIds.isEmpty,
          )
          .toList();
    }
    return _entries
        .where(
          (entry) =>
              entry.memberId == _memberFilter ||
              entry.sharedMemberIds.contains(_memberFilter),
        )
        .toList();
  }

  Future<void> _delete(FinanceEntry entry) async {
    if (entry.id == null) return;
    await FinanceDatabase.instance.deleteEntry(entry.id!);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Movimiento eliminado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text(
            'Actividad',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _memberFilter == null,
                  onSelected: (_) => setState(() => _memberFilter = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Sin asignar'),
                  selected: _memberFilter == -1,
                  onSelected: (_) => setState(() => _memberFilter = -1),
                ),
                for (final member in _members) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(member.name),
                    selected: _memberFilter == member.id,
                    onSelected: (_) =>
                        setState(() => _memberFilter = member.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No hay movimientos para este filtro.'),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final entry in visible)
                    _EntryTile(
                      entry: entry,
                      style: _styleForEntry(entry, _categories),
                      member: entry.memberId == null
                          ? null
                          : _memberById[entry.memberId],
                      shares: _memberShares(entry, _memberById),
                      onTap: () => widget.onEdit(entry: entry),
                      onDismiss: () => _delete(entry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Análisis por categoría e integrante
// ---------------------------------------------------------------------------

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({required this.refresh, super.key});

  final ValueNotifier<int> refresh;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late final ValueNotifier<int> _refresh;
  List<FinanceEntry> _entries = [];
  List<FinanceCategory> _categories = [];
  List<FinanceMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh = widget.refresh;
    _refresh.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final database = FinanceDatabase.instance;
    final entries = await database.getEntries();
    final categories = await database.getCategories();
    final members = await database.getMembers();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _categories = categories;
      _members = members;
      _loading = false;
    });
  }

  List<_Breakdown> _breakdown({required bool isIncome}) {
    final totals = <String, double>{};
    for (final entry in _entries.where((e) => e.isIncome == isIncome)) {
      totals[entry.category] = (totals[entry.category] ?? 0) + entry.amount;
    }
    final rows = totals.entries.map((item) {
      final category = _categories.firstWhere(
        (c) => c.name.toLowerCase() == item.key.toLowerCase(),
        orElse: () => FinanceCategory(
          name: item.key,
          isIncome: isIncome,
          icon: 'otros',
          color: 0xFF62736A,
        ),
      );
      return _Breakdown(
        name: item.key,
        value: item.value,
        style: CategoryStyle.from(category),
      );
    }).toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  List<_Breakdown> _memberBreakdown() {
    final byId = {
      for (final m in _members)
        if (m.id != null) m.id!: m,
    };
    final totals = <String, double>{};
    for (final entry in _entries.where((e) => !e.isIncome)) {
      for (final share in _memberShares(entry, byId)) {
        totals[share.name] = (totals[share.name] ?? 0) + share.amount;
      }
    }
    final rows = totals.entries
        .map(
          (item) => _Breakdown(
            name: item.key,
            value: item.value,
            style: const CategoryStyle(
              icon: Icons.person_outline_rounded,
              color: Color(0xFF4F78A1),
              background: Color(0xFFE8EEF5),
            ),
          ),
        )
        .toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final expenses = _breakdown(isIncome: false);
    final incomes = _breakdown(isIncome: true);
    final members = _memberBreakdown();
    final totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.value);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text(
            'Análisis',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${_entries.length} movimientos registrados',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          _BreakdownCard(title: 'Gastos por categoría', rows: expenses),
          _BreakdownCard(title: 'Ingresos por categoría', rows: incomes),
          _BreakdownCard(
            title: 'Gastos por integrante',
            rows: members,
            note: 'Total analizado ${formatMoney(totalExpenses)}',
          ),
        ],
      ),
    );
  }
}

class _Breakdown {
  const _Breakdown({
    required this.name,
    required this.value,
    required this.style,
  });

  final String name;
  final double value;
  final CategoryStyle style;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.rows, this.note});

  final String title;
  final List<_Breakdown> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final max = rows.isEmpty ? 1.0 : rows.first.value;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note!, style: TextStyle(color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const Text('Sin datos para este período.')
            else
              for (final row in rows) ...[
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: row.style.background,
                      child: Icon(
                        row.style.icon,
                        size: 18,
                        color: row.style.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(row.name)),
                    Text(
                      formatMoney(row.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: row.value / max,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: row.style.color,
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Familia / integrantes
// ---------------------------------------------------------------------------

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({required this.refresh, super.key});

  final ValueNotifier<int> refresh;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late final ValueNotifier<int> _refresh;
  List<FinanceMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh = widget.refresh;
    _refresh.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final members = await FinanceDatabase.instance.getMembers();
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _newMember() async {
    final created = await showMemberDialog(context);
    if (created == null) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Integrante creado')));
    }
  }

  Future<void> _deleteMember(FinanceMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar integrante?'),
        content: Text('Se eliminará "${member.name}" de la familia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final deleted = await FinanceDatabase.instance.deleteMember(member);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Integrante eliminado'
                : 'No se puede eliminar: tiene movimientos asociados',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Familia',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              FilledButton.tonal(
                onPressed: _newMember,
                child: const Text('Nuevo integrante'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Asigná movimientos a cada integrante para ver el análisis.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (_members.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Todavía no hay integrantes.')),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final member in _members)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(member.color)
                            .withValues(alpha: 0.18),
                        child: Icon(
                          Icons.person_rounded,
                          color: Color(member.color),
                        ),
                      ),
                      title: Text(member.name),
                      trailing: IconButton(
                        tooltip: 'Eliminar integrante',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _deleteMember(member),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<FinanceMember?> showMemberDialog(BuildContext context) async {
  final controller = TextEditingController();
  return await showDialog<FinanceMember>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nuevo integrante'),
      content: TextFormField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nombre del integrante',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Ingresá un nombre' : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            try {
              final member = await FinanceDatabase.instance.insertMember(
                FinanceMember(
                  name: name,
                  color: const Color(0xFF4F78A1).toARGB32(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx, member);
            } on DuplicateMemberException catch (error) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(error.message)));
              }
            }
          },
          child: const Text('Guardar integrante'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Categorías
// ---------------------------------------------------------------------------

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.refresh, super.key});

  final ValueNotifier<int> refresh;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final ValueNotifier<int> _refresh;
  List<FinanceCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh = widget.refresh;
    _refresh.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    _refresh.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final categories = await FinanceDatabase.instance.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _newCategory() async {
    final created = await showCategoryDialog(context, isIncome: false);
    if (created == null) return;
    _refresh.value++;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoría "${created.name}" creada')),
      );
    }
  }

  Future<void> _deleteCategory(FinanceCategory category) async {
    final deleted = await FinanceDatabase.instance.deleteCategory(category);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? 'Categoría eliminada'
                : 'No se puede eliminar: está en uso',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categorías',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              FilledButton.tonal(
                onPressed: _newCategory,
                child: const Text('Nueva categoría'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final isIncome in [false, true]) ...[
            Text(
              isIncome ? 'Ingresos' : 'Gastos',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final category in _categories.where(
                    (c) => c.isIncome == isIncome,
                  ))
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: CategoryStyle.from(category)
                            .background,
                        child: Icon(
                          CategoryStyle.from(category).icon,
                          color: CategoryStyle.from(category).color,
                        ),
                      ),
                      title: Text(category.name),
                      trailing: IconButton(
                        tooltip: 'Eliminar categoría',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _deleteCategory(category),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

Future<FinanceCategory?> showCategoryDialog(
  BuildContext context, {
  required bool isIncome,
}) async {
  final controller = TextEditingController();
  var selectedIsIncome = isIncome;
  var icon = 'otros';
  var color = const Color(0xFF155C4B).toARGB32();
  String? error;
  return await showDialog<FinanceCategory>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Gasto')),
                  ButtonSegment(value: true, label: Text('Ingreso')),
                ],
                selected: {selectedIsIncome},
                onSelectionChanged: (values) =>
                    setState(() => selectedIsIncome = values.first),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in categoryIconOptions.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: IconButton(
                          tooltip: entry.key,
                          onPressed: () => setState(() => icon = entry.key),
                          icon: Icon(
                            entry.value,
                            color: icon == entry.key
                                ? Color(color)
                                : Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in categoryColorOptions)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => color = option.toARGB32()),
                          child: CircleAvatar(
                            backgroundColor: option,
                            radius: color == option.toARGB32() ? 16 : 13,
                            child: color == option.toARGB32()
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setState(() => error = 'Ingresá un nombre');
                return;
              }
              try {
                final category = await FinanceDatabase.instance.insertCategory(
                  FinanceCategory(
                    name: name,
                    isIncome: selectedIsIncome,
                    icon: icon,
                    color: color,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx, category);
              } on DuplicateCategoryException catch (e) {
                setState(() => error = e.message);
              }
            },
            child: const Text('Guardar categoría'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Formulario de movimiento (alta / edición)
// ---------------------------------------------------------------------------

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({this.entry, super.key});

  final FinanceEntry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();

  bool _isIncome = false;
  late String _category;
  int _memberId = -1;
  bool _isShared = false;

  /// Un controlador por integrante, con el monto que aporta cada uno.
  final Map<int, TextEditingController> _shareControllers =
      <int, TextEditingController>{};
  late DateTime _date;
  List<FinanceCategory> _categories = [];
  List<FinanceMember> _members = [];
  bool _loading = true;

  bool get _editing => widget.entry != null;

  List<int> get _sharedMemberIds => _shareControllers.keys.toList();

  /// Texto listo para cargar en un campo de importe.
  String _moneyInput(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  double get _sharesTotal => _shareControllers.values.fold<double>(
    0,
    (sum, controller) => sum + (parseAmount(controller.text) ?? 0),
  );

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _isIncome = entry?.isIncome ?? false;
    _category = entry?.category ?? 'Comida';
    _memberId = entry?.memberId ?? -1;
    _isShared = entry?.isShared ?? false;
    for (final share in entry?.shares ?? const <FinanceShare>[]) {
      _shareControllers[share.memberId] = TextEditingController(
        text: _moneyInput(share.amount),
      );
    }
    _date = entry?.date ?? DateTime.now();
    if (entry != null) {
      _title.text = entry.title;
      _amount.text = entry.amount.toStringAsFixed(2).replaceAll('.', ',');
    }
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    for (final controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final database = FinanceDatabase.instance;
    final categories = await database.getCategories(isIncome: _isIncome);
    final members = await database.getMembers();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _members = members;
      if (!categories.any((c) => c.name == _category)) {
        _category = categories.isNotEmpty ? categories.first.name : 'Otros';
      }
      _loading = false;
    });
  }

  Future<void> _changeType(bool isIncome) async {
    setState(() {
      _isIncome = isIncome;
      _category = isIncome ? 'Sueldo' : 'Comida';
      _loading = true;
    });
    await _load();
  }

  Future<void> _newCategory() async {
    final created = await showCategoryDialog(context, isIncome: _isIncome);
    if (created == null) return;
    await _load();
    if (mounted) {
      setState(() => _category = created.name);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'AR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Reparte el importe total en partes iguales entre los seleccionados.
  void _setEqualShares() {
    final total = parseAmount(_amount.text) ?? 0;
    if (_shareControllers.isEmpty || total <= 0) return;
    final part = total / _shareControllers.length;
    for (final controller in _shareControllers.values) {
      controller.text = _moneyInput(part);
    }
  }

  /// Al sumar un integrante le asigna lo que falta; al sacarlo deja los
  /// demás montos intactos para no perder lo que el usuario cargó a mano.
  void _toggleShare(int memberId, bool selected) {
    if (selected) {
      final total = parseAmount(_amount.text) ?? 0;
      final remaining = total - _sharesTotal;
      final amount = _shareControllers.isEmpty
          ? total
          : remaining > 0
          ? remaining
          : total / (_shareControllers.length + 1);
      _shareControllers[memberId] = TextEditingController(
        text: _moneyInput(amount),
      );
    } else {
      _shareControllers.remove(memberId)?.dispose();
    }
  }

  /// Si el usuario cambia el importe total mientras todos los aportes están
  /// parejos, recalcula las cuotas. Si cargó montos distintos, los respeta.
  void _onAmountChanged(String _) {
    if (_shareControllers.isEmpty) return;
    final total = parseAmount(_amount.text) ?? 0;
    final part = total / _shareControllers.length;
    final allEqual = _shareControllers.values.every((controller) {
      final value = parseAmount(controller.text);
      return value != null && (value - part).abs() < 0.01;
    });
    if (allEqual) setState(_setEqualShares);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un importe válido')),
      );
      return;
    }
    final shares = <FinanceShare>[];
    if (_isShared) {
      if (_shareControllers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elegí al menos un integrante para el reparto'),
          ),
        );
        return;
      }
      for (final item in _shareControllers.entries) {
        final value = parseAmount(item.value.text);
        if (value == null || value <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingresá un monto válido para cada integrante'),
            ),
          );
          return;
        }
        shares.add(FinanceShare(memberId: item.key, amount: value));
      }
      final totalShares = shares.fold<double>(
        0,
        (sum, share) => sum + share.amount,
      );
      if ((totalShares - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Los aportes suman ${formatMoney(totalShares)} pero el importe '
              'es ${formatMoney(amount)}',
            ),
          ),
        );
        return;
      }
    }
    final entry = FinanceEntry(
      id: widget.entry?.id,
      title: _title.text.trim(),
      amount: amount,
      category: _category,
      date: _date,
      isIncome: _isIncome,
      memberId: _memberId == -1 ? null : _memberId,
      isShared: _isShared,
      shares: _isShared ? shares : const <FinanceShare>[],
    );
    final database = FinanceDatabase.instance;
    if (_editing) {
      await database.updateEntry(entry);
    } else {
      await database.insertEntry(entry);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry?.id == null) return;
    final confirm = await _confirmDelete(context);
    if (!confirm) return;
    await FinanceDatabase.instance.deleteEntry(entry!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = parseAmount(_amount.text);
    final sharesTotal = _sharesTotal;
    final sharesMatch =
        parsedAmount != null && (sharesTotal - parsedAmount).abs() < 0.01;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar movimiento' : 'Nuevo movimiento'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_editing ? 'Guardar cambios' : 'Guardar movimiento'),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Ingresá una descripción'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Importe',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                          hintText: '1.500,50',
                        ),
                        validator: (value) => parseAmount(value ?? '') == null
                            ? 'Ingresá un importe válido'
                            : null,
                        onChanged: _onAmountChanged,
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Gasto')),
                          ButtonSegment(value: true, label: Text('Ingreso')),
                        ],
                        selected: {_isIncome},
                        onSelectionChanged: (values) =>
                            _changeType(values.first),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Categoría',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Nueva categoría',
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: _newCategory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final category in _categories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category.name),
                                  selected: category.name == _category,
                                  onSelected: (_) =>
                                      setState(() => _category = category.name),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      DropdownButtonFormField<int>(
                        initialValue: _memberId,
                        decoration: const InputDecoration(
                          labelText: 'Integrante',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: -1,
                            child: Text('Sin asignar'),
                          ),
                          for (final member in _members)
                            DropdownMenuItem<int>(
                              value: member.id ?? -1,
                              child: Text(member.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _memberId = value ?? -1),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isShared,
                        onChanged: (value) => setState(() {
                          _isShared = value;
                          if (value &&
                              _shareControllers.isEmpty &&
                              _memberId != -1) {
                            _toggleShare(_memberId, true);
                          }
                        }),
                        title: const Text('Pago compartido'),
                        subtitle: const Text('Cada integrante aporta un monto'),
                      ),
                      if (_isShared) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Elegí quiénes participan y cuánto aporta cada uno',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_members.isEmpty)
                          const Text(
                            'Creá integrantes en la pestaña Familia para repartir.',
                            style: TextStyle(fontSize: 12),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final member in _members)
                                FilterChip(
                                  label: Text(member.name),
                                  selected:
                                      member.id != null &&
                                      _shareControllers.containsKey(member.id),
                                  onSelected: (selected) => setState(() {
                                    if (member.id == null) return;
                                    _toggleShare(member.id!, selected);
                                  }),
                                ),
                            ],
                          ),
                        if (_shareControllers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Monto de cada integrante',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final member in _members)
                            if (member.id != null &&
                                _shareControllers.containsKey(member.id))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(member.name)),
                                    SizedBox(
                                      width: 130,
                                      child: TextFormField(
                                        controller:
                                            _shareControllers[member.id],
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.right,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixText: r'$ ',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(_setEqualShares),
                              icon: const Icon(
                                Icons.equalizer_rounded,
                                size: 18,
                              ),
                              label: const Text('Partes iguales'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (sharesMatch
                                        ? const Color(0xFF155C4B)
                                        : Colors.orange)
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _shareControllers.isEmpty
                                ? 'Elegí al menos un integrante para el reparto'
                                : '${_sharedMemberIds.length} ${_sharedMemberIds.length == 1 ? 'integrante' : 'integrantes'} · '
                                      'Aportes ${formatMoney(sharesTotal)} de '
                                      '${formatMoney(parsedAmount ?? 0)}'
                                      '${sharesMatch ? '' : ' · Ajustá los montos'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sharesMatch
                                  ? const Color(0xFF155C4B)
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: const Text('Fecha'),
                        subtitle: Text(formatDay(_date)),
                        trailing: const Icon(Icons.edit_calendar_rounded),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 28),
                      if (_editing) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _delete,
                          child: const Text('Eliminar movimiento'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Informes y exportación PDF
// ---------------------------------------------------------------------------

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  List<FinanceEntry> _entries = [];
  List<FinanceEntry> _allEntries = [];
  List<FinanceCategory> _categories = [];
  List<FinanceMember> _members = [];
  bool _loading = true;
  bool _saving = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final database = FinanceDatabase.instance;
    final entries = await database.getEntries();
    final categories = await database.getCategories();
    final members = await database.getMembers();
    if (!mounted) return;
    setState(() {
      _allEntries = entries;
      _categories = categories;
      _entries = entries
          .where(
            (entry) =>
                !entry.date.isBefore(_from) &&
                !entry.date.isAfter(_to.add(const Duration(days: 1))),
          )
          .toList();
      _members = members;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('es', 'AR'),
    );
    if (range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
      _loading = true;
      _savedPath = null;
    });
    await _load();
  }

  Map<String, double> _categoryTotals(bool isIncome) {
    final totals = <String, double>{};
    for (final entry in _entries.where((e) => e.isIncome == isIncome)) {
      totals[entry.category] = (totals[entry.category] ?? 0) + entry.amount;
    }
    return totals;
  }

  Map<String, double> _memberTotals() {
    final byId = {
      for (final m in _members)
        if (m.id != null) m.id!: m,
    };
    final totals = <String, double>{};
    for (final entry in _entries.where((e) => !e.isIncome)) {
      for (final share in _memberShares(entry, byId)) {
        totals[share.name] = (totals[share.name] ?? 0) + share.amount;
      }
    }
    return totals;
  }

  int get _days => _to.difference(_from).inDays + 1;

  ({
    double income,
    double expense,
    double balance,
    double savings,
    double daily,
    int count,
  })
  get _summary {
    final income = _entries
        .where((e) => e.isIncome)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final expense = _entries
        .where((e) => !e.isIncome)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final balance = income - expense;
    return (
      income: income,
      expense: expense,
      balance: balance,
      savings: income > 0 ? (balance / income) * 100 : 0,
      daily: _days > 0 ? expense / _days : 0,
      count: _entries.length,
    );
  }

  ({double income, double expense}) get _previous {
    final days = _days;
    final previousTo = _from.subtract(const Duration(days: 1));
    final previousFrom = previousTo.subtract(Duration(days: days - 1));
    final entries = _allEntries.where(
      (entry) =>
          !entry.date.isBefore(previousFrom) &&
          !entry.date.isAfter(previousTo.add(const Duration(days: 1))),
    );
    return (
      income: entries
          .where((e) => e.isIncome)
          .fold(0.0, (sum, entry) => sum + entry.amount),
      expense: entries
          .where((e) => !e.isIncome)
          .fold(0.0, (sum, entry) => sum + entry.amount),
    );
  }

  List<MapEntry<String, double>> _sorted(Map<String, double> totals) {
    final rows = totals.entries.toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows;
  }

  double _percent(double part, double total) =>
      total > 0 ? (part / total) * 100 : 0;

  List<String> get _insights {
    final summary = _summary;
    final insights = <String>[];

    insights.add(
      'Registraste ${summary.count} movimientos en $_days '
      '${_days == 1 ? 'día' : 'días'}: ${formatMoney(summary.income)} de ingresos '
      'y ${formatMoney(summary.expense)} de gastos.',
    );

    final shared = _entries.where((e) => e.isShared).length;
    if (shared > 0) {
      insights.add(
        '$shared ${shared == 1 ? 'movimiento compartido' : 'movimientos compartidos'}: '
        'cada integrante aportó un monto propio.',
      );
    }

    final categories = _sorted(_categoryTotals(false));
    if (categories.isNotEmpty) {
      final top = categories.first;
      insights.add(
        '${top.key} fue la categoría que más gastó: ${formatMoney(top.value)} '
        '(${_percent(top.value, summary.expense).toStringAsFixed(0)}% del total).',
      );
    }

    final members = _sorted(_memberTotals());
    if (members.isNotEmpty) {
      final top = members.first;
      insights.add(
        '${top.key} concentró el '
        '${_percent(top.value, summary.expense).toStringAsFixed(0)}% '
        'de los gastos (${formatMoney(top.value)}).',
      );
    }

    final previous = _previous;
    if (previous.expense > 0) {
      final change = summary.expense - previous.expense;
      final changePercent = (change / previous.expense) * 100;
      if (change.abs() >= 0.01) {
        insights.add(
          'Tus gastos ${change > 0 ? 'aumentaron' : 'bajaron'} '
          '${changePercent.abs().toStringAsFixed(0)}% respecto al período '
          'anterior (${formatMoney(previous.expense)}).',
        );
      } else {
        insights.add(
          'Tus gastos se mantuvieron igual que en el período anterior.',
        );
      }
    } else {
      insights.add(
        'No hay gastos registrados en el período anterior para comparar.',
      );
    }

    if (summary.income > 0) {
      insights.add(
        'Ahorraste ${summary.savings.toStringAsFixed(0)}% de tus ingresos '
        '(balance ${formatMoney(summary.balance)}).',
      );
    }
    return insights;
  }

  Future<void> _generatePdf() async {
    setState(() => _saving = true);
    final summary = _summary;
    final previous = _previous;
    final categories = _sorted(_categoryTotals(false));
    final incomeCategories = _sorted(_categoryTotals(true));
    final members = _sorted(_memberTotals());
    final byId = {
      for (final member in _members)
        if (member.id != null) member.id!: member,
    };

    String bar(double percent) {
      final steps = (percent / 5).round();
      final clamped = steps > 20 ? 20 : (steps < 0 ? 0 : steps);
      return '#' * clamped;
    }

    final byDay = <String, List<FinanceEntry>>{};
    for (final entry in _entries) {
      byDay.putIfAbsent(formatDay(entry.date), () => []).add(entry);
    }

    final titleStyle = pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.green900,
    );
    final sectionStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.green800,
    );
    final cellStyle = pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Cuentas Claras', style: titleStyle),
            pw.Text('Informe detallado de finanzas', style: sectionStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              'Período: ${formatDay(_from)} - ${formatDay(_to)}'
              '   |   Generado: ${formatDay(DateTime.now())}',
              style: cellStyle,
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Cuentas Claras - Informe privado', style: cellStyle),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: cellStyle,
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text('1. Resumen ejecutivo', style: sectionStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Indicador', 'Valor'],
            data: [
              ['Movimientos registrados', '${summary.count}'],
              ['Ingresos', formatMoney(summary.income)],
              ['Gastos', formatMoney(summary.expense)],
              ['Balance', formatMoney(summary.balance)],
              [
                'Porcentaje de ahorro',
                '${summary.savings.toStringAsFixed(1)}%',
              ],
              ['Promedio diario de gasto', formatMoney(summary.daily)],
              [
                'Gastos período anterior',
                previous.expense > 0
                    ? formatMoney(previous.expense)
                    : 'Sin datos',
              ],
            ],
            headerStyle: headerStyle,
            cellStyle: cellStyle,
          ),
          pw.SizedBox(height: 16),
          pw.Text('2. Lectura rápida', style: sectionStyle),
          pw.SizedBox(height: 6),
          ..._insights.map((text) => pw.Bullet(text: text, style: cellStyle)),
          pw.SizedBox(height: 16),
          pw.Text('3. ¿En qué se fue el dinero?', style: sectionStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Categoría', 'Importe', '%', 'Distribución'],
            data: categories
                .map(
                  (item) => [
                    item.key,
                    formatMoney(item.value),
                    '${_percent(item.value, summary.expense).toStringAsFixed(1)}%',
                    bar(_percent(item.value, summary.expense)),
                  ],
                )
                .toList(),
            headerStyle: headerStyle,
            cellStyle: cellStyle,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Ingresos por categoría', style: sectionStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Categoría', 'Importe', '%'],
            data: incomeCategories
                .map(
                  (item) => [
                    item.key,
                    formatMoney(item.value),
                    '${_percent(item.value, summary.income).toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
            headerStyle: headerStyle,
            cellStyle: cellStyle,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Gastos por integrante', style: sectionStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Integrante', 'Importe', '%', 'Distribución'],
            data: members
                .map(
                  (item) => [
                    item.key,
                    formatMoney(item.value),
                    '${_percent(item.value, summary.expense).toStringAsFixed(1)}%',
                    bar(_percent(item.value, summary.expense)),
                  ],
                )
                .toList(),
            headerStyle: headerStyle,
            cellStyle: cellStyle,
          ),
          pw.SizedBox(height: 16),
          pw.Text('4. Detalle de movimientos', style: sectionStyle),
          pw.SizedBox(height: 6),
          ...byDay.entries.expand(
            (day) => [
              pw.Text(day.key, style: headerStyle),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Descripción',
                  'Categoría',
                  'Integrante',
                  'Importe',
                ],
                data: day.value
                    .map(
                      (entry) => [
                        entry.title,
                        entry.category,
                        entry.isShared
                            ? _sharesLabel(_memberShares(entry, byId))
                            : entry.memberId == null
                            ? 'Sin asignar'
                            : byId[entry.memberId]?.name ?? 'Sin asignar',
                        '${entry.isIncome ? '+' : '-'} ${formatMoney(entry.amount)}',
                      ],
                    )
                    .toList(),
                headerStyle: headerStyle,
                cellStyle: cellStyle,
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );

    final bytes = await document.save();
    final fileName =
        'cuentas_claras_${_from.year}-${_from.month}-${_from.day}'
        '_${_to.year}-${_to.month}-${_to.day}.pdf';
    final path = await savePdfBytes(bytes, fileName);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedPath = path.isEmpty ? null : path;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Informes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _summary;
    final categories = _sorted(_categoryTotals(false));
    final incomes = _sorted(_categoryTotals(true));
    final members = _sorted(_memberTotals());
    final byDay = <String, List<FinanceEntry>>{};
    for (final entry in _entries) {
      byDay.putIfAbsent(formatDay(entry.date), () => []).add(entry);
    }
    final byId = {
      for (final member in _members)
        if (member.id != null) member.id!: member,
    };

    CategoryStyle styleForName(String name) {
      final category = _categories.firstWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
        orElse: () => FinanceCategory(
          name: name,
          isIncome: false,
          icon: 'otros',
          color: 0xFF62736A,
        ),
      );
      return CategoryStyle.from(category);
    }

    const memberStyle = CategoryStyle(
      icon: Icons.person_outline_rounded,
      color: Color(0xFF4F78A1),
      background: Color(0xFFE8EEF5),
    );
    const incomeStyle = CategoryStyle(
      icon: Icons.trending_up_rounded,
      color: Color(0xFF155C4B),
      background: Color(0xFFE3F1EA),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes'),
        actions: [
          IconButton(
            tooltip: 'Generar PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _saving ? null : _generatePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range_rounded),
                title: const Text('Período del informe'),
                subtitle: Text('${formatDay(_from)} — ${formatDay(_to)}'),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickRange,
              ),
            ),
            const SizedBox(height: 12),
            _ReportSection(
              title: '1. Resumen ejecutivo',
              icon: Icons.dashboard_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Ingresos',
                        value: formatMoney(summary.income),
                        color: const Color(0xFF155C4B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Gastos',
                        value: formatMoney(summary.expense),
                        color: const Color(0xFFC85F67),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Balance',
                        value: formatMoney(summary.balance),
                        color: const Color(0xFF4F78A1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Ahorro',
                        value: '${summary.savings.toStringAsFixed(0)}%',
                        color: const Color(0xFFB38723),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${summary.count} movimientos · $_days ${_days == 1 ? 'día' : 'días'} '
                  '· promedio diario de gasto ${formatMoney(summary.daily)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReportSection(
              title: '2. Lectura rápida',
              icon: Icons.lightbulb_outline_rounded,
              children: [
                for (final insight in _insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF155C4B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            insight,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ReportSection(
              title: '3. ¿En qué se fue el dinero?',
              icon: Icons.pie_chart_outline_rounded,
              children: [
                if (categories.isEmpty)
                  const Text('No hay gastos registrados en el período.'),
                for (final item in categories)
                  _DistributionRow(
                    label: item.key,
                    amount: formatMoney(item.value),
                    percent: _percent(item.value, summary.expense),
                    style: styleForName(item.key),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Ingresos por categoría',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (incomes.isEmpty)
                  const Text('No hay ingresos registrados en el período.'),
                for (final item in incomes)
                  _DistributionRow(
                    label: item.key,
                    amount: formatMoney(item.value),
                    percent: _percent(item.value, summary.income),
                    style: incomeStyle,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ReportSection(
              title: '4. Gastos por integrante',
              icon: Icons.people_outline_rounded,
              children: [
                if (members.isEmpty)
                  const Text('Ningún gasto está asignado a un integrante.'),
                for (final item in members)
                  _DistributionRow(
                    label: item.key,
                    amount: formatMoney(item.value),
                    percent: _percent(item.value, summary.expense),
                    style: memberStyle,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ReportSection(
              title: '5. Detalle de movimientos',
              icon: Icons.receipt_long_rounded,
              children: [
                if (byDay.isEmpty)
                  const Text('No hay movimientos en el período.'),
                for (final day in byDay.entries)
                  ExpansionTile(
                    title: Text(
                      day.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${day.value.length} movimientos'),
                    children: [
                      for (final entry in day.value)
                        _ReportEntryRow(
                          entry: entry,
                          memberName: entry.memberId == null
                              ? null
                              : byId[entry.memberId]?.name,
                          sharesText: entry.isShared
                              ? _sharesLabel(_memberShares(entry, byId))
                              : null,
                          style: styleForName(entry.category),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _generatePdf,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_saving ? 'Generando...' : 'Descargar informe PDF'),
            ),
            if (_savedPath != null) ...[
              const SizedBox(height: 10),
              Text(
                'Guardado en: $_savedPath',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF155C4B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.style,
  });

  final String label;
  final String amount;
  final double percent;
  final CategoryStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: style.background,
              child: Icon(style.icon, size: 18, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${percent.toStringAsFixed(0)}%  $amount',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            color: style.color,
          ),
        ),
      ],
    ),
  );
}

class _ReportEntryRow extends StatelessWidget {
  const _ReportEntryRow({
    required this.entry,
    required this.style,
    this.memberName,
    this.sharesText,
  });

  final FinanceEntry entry;
  final CategoryStyle style;
  final String? memberName;
  final String? sharesText;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: style.background,
      child: Icon(style.icon, size: 18, color: style.color),
    ),
    title: Text(entry.title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${entry.category}${memberName == null ? '' : '  ·  $memberName'}',
        ),
        if (sharesText != null)
          Text(
            sharesText!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF155C4B)),
          ),
      ],
    ),
    trailing: Text(
      '${entry.isIncome ? '+' : '−'} ${formatMoney(entry.amount)}',
      style: TextStyle(
        color: entry.isIncome ? const Color(0xFF155C4B) : Colors.grey.shade800,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

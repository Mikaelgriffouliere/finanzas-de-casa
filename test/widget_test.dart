import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_personales/app_settings.dart';
import 'package:finanzas_personales/finance_database.dart';
import 'package:finanzas_personales/main.dart';
import 'package:finanzas_personales/onboarding/onboarding.dart';

/// SQLite por FFI usa un isolate real, por eso hay que ceder el control al
/// event loop (runAsync) para que la app termine de cargar antes de verificar.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

Future<void> _startApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await FinanceDatabase.instance.database;
  });
  await tester.pumpWidget(const FinanceApp());
  await _settle(tester);
  await _login(tester);
}

Future<void> _login(
  WidgetTester tester, {
  String user = 'admin',
  String password = 'admin123',
  bool skipIntro = true,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), user);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await _settle(tester);

  // La intro aparece solo en el primer ingreso. El resto de los tests arranca
  // desde el panel principal, así que la omitimos de forma centralizada.
  if (skipIntro && find.byType(OnboardingScreen).evaluate().isNotEmpty) {
    await tester.tap(find.text('Saltar'));
    await _settle(tester);
  }
}

Future<void> _deleteEntriesStartingWith(String prefix) async {
  final database = FinanceDatabase.instance;
  for (final entry in await database.getEntries()) {
    if (entry.title.startsWith(prefix) && entry.id != null) {
      await database.deleteEntry(entry.id!);
    }
  }
}

void main() {
  setUpAll(() async {
    FinanceDatabase.initializeFfi(noIsolate: true);
    await initializeDateFormatting('es_AR');
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('inicia y cierra sesión', (tester) async {
    await tester.runAsync(() async {
      await FinanceDatabase.instance.database;
    });
    await tester.pumpWidget(const FinanceApp());
    await _settle(tester);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Balance total'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá tu usuario'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña'), findsOneWidget);

    await _login(tester, password: 'incorrecta');
    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Balance total'), findsNothing);

    await _login(tester);
    expect(find.text('Balance total'), findsOneWidget);

    await tester.tap(find.text('Familia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Balance total'), findsNothing);
  });

  testWidgets('muestra el panel financiero y la navegación', (tester) async {
    await _startApp(tester);

    expect(find.text('Tu dinero, en orden.'), findsOneWidget);
    expect(find.text('Balance total'), findsOneWidget);
    expect(find.text('Actividad reciente'), findsOneWidget);
    expect(find.text('Análisis'), findsOneWidget);
  });

  testWidgets('guarda y elimina un movimiento', (tester) async {
    await tester.runAsync(() => _deleteEntriesStartingWith('Prueba E2E'));
    await _startApp(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Prueba E2E supermercado');
    await tester.enterText(fields.at(1), '1.500,50');
    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);

    expect(find.text('Prueba E2E supermercado'), findsOneWidget);

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Prueba E2E supermercado'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar movimiento?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await _settle(tester);

    expect(find.text('Prueba E2E supermercado'), findsNothing);
  });

  testWidgets('edita y elimina un movimiento desde la edición', (tester) async {
    const title = 'Prueba E2E edición';
    await tester.runAsync(() => _deleteEntriesStartingWith(title));
    await _startApp(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();
    var fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), title);
    await tester.enterText(fields.at(1), '100');
    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '250,50');
    await tester.tap(find.text('Guardar cambios'));
    await _settle(tester);

    expect(find.textContaining('250,50'), findsWidgets);
    expect(find.text('Movimiento actualizado'), findsOneWidget);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Eliminar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar movimiento'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar movimiento?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await _settle(tester);

    expect(find.text(title), findsNothing);
  });

  testWidgets('acepta importes con separador de miles', (tester) async {
    await tester.runAsync(() => _deleteEntriesStartingWith('Prueba formato'));
    await _startApp(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Prueba formato local');
    await tester.enterText(fields.at(1), '12.345,67');
    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);

    expect(find.text('Prueba formato local'), findsOneWidget);
    expect(find.text('Ingresá un importe válido'), findsNothing);

    await tester.runAsync(() => _deleteEntriesStartingWith('Prueba formato'));
  });

  testWidgets('cambia las categorías al pasar a ingreso', (tester) async {
    await _startApp(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Comida'), findsOneWidget);

    await tester.tap(find.text('Ingreso'));
    await _settle(tester);

    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text('Comida'), findsNothing);
  });

  testWidgets('crea una categoría personalizada desde la pestaña', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final category in await FinanceDatabase.instance.getCategories()) {
        if (category.name == 'Prueba categoria') {
          await FinanceDatabase.instance.deleteCategory(category);
        }
      }
    });
    await _startApp(tester);

    await tester.tap(find.byIcon(Icons.category_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Prueba categoria',
    );
    await tester.tap(find.text('Guardar categoría'));
    await _settle(tester);

    expect(find.text('Prueba categoria'), findsOneWidget);
    expect(find.text('Categoría "Prueba categoria" creada'), findsOneWidget);

    await tester.runAsync(() async {
      for (final category in await FinanceDatabase.instance.getCategories()) {
        if (category.name == 'Prueba categoria') {
          await FinanceDatabase.instance.deleteCategory(category);
        }
      }
    });
  });

  testWidgets('crea una categoría desde el formulario de movimiento', (
    tester,
  ) async {
    const name = 'Prueba desde formulario';
    await tester.runAsync(() async {
      for (final entry in await FinanceDatabase.instance.getEntries()) {
        if (entry.title == 'Prueba categoría custom') {
          await FinanceDatabase.instance.deleteEntry(entry.id!);
        }
      }
      for (final category in await FinanceDatabase.instance.getCategories()) {
        if (category.name == name) {
          await FinanceDatabase.instance.deleteCategory(category);
        }
      }
    });
    await _startApp(tester);

    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, name);
    await tester.tap(find.text('Guardar categoría'));
    await _settle(tester);

    expect(find.text('Guardar categoría'), findsNothing);
    expect(find.text(name), findsOneWidget);
    expect(find.text('Guardar movimiento'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Prueba categoría custom');
    await tester.enterText(fields.at(1), '250');
    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);

    expect(find.text('Prueba categoría custom'), findsOneWidget);

    await tester.runAsync(() async {
      for (final entry in await FinanceDatabase.instance.getEntries()) {
        if (entry.title == 'Prueba categoría custom') {
          await FinanceDatabase.instance.deleteEntry(entry.id!);
        }
      }
      for (final category in await FinanceDatabase.instance.getCategories()) {
        if (category.name == name) {
          await FinanceDatabase.instance.deleteCategory(category);
        }
      }
    });
  });

  test('incluye las categorías por defecto', () async {
    final database = FinanceDatabase.instance;
    final expenses = await database.getCategories(isIncome: false);
    final incomes = await database.getCategories(isIncome: true);

    expect(
      expenses.map((category) => category.name),
      containsAll([
        'Comida',
        'Transporte',
        'Hogar',
        'Salud',
        'Ocio',
        'Tarjeta de crédito',
        'Otros',
      ]),
    );
    expect(
      incomes.map((category) => category.name),
      containsAll(['Sueldo', 'Extra', 'Inversiones', 'Otros']),
    );
  });

  test('crea y elimina categorías personalizadas', () async {
    final database = FinanceDatabase.instance;
    const name = 'Prueba Mascotas';

    for (final category in await database.getCategories()) {
      if (category.name == name) await database.deleteCategory(category);
    }

    final category = await database.insertCategory(
      FinanceCategory(
        name: name,
        isIncome: false,
        icon: 'mascotas',
        color: 0xFF8A6C9D,
      ),
    );
    expect(category.id, isNotNull);
    expect(
      (await database.getCategories(isIncome: false))
          .any((item) => item.name == name),
      isTrue,
    );

    await expectLater(
      database.insertCategory(
        FinanceCategory(
          name: name,
          isIncome: false,
          icon: 'otros',
          color: 0xFF155C4B,
        ),
      ),
      throwsA(isA<DuplicateCategoryException>()),
    );

    final entryId = await database.insertEntry(
      FinanceEntry(
        title: 'Prueba categoría en uso',
        amount: 10,
        category: name,
        date: DateTime.now(),
        isIncome: false,
      ),
    );
    expect(await database.deleteCategory(category), isFalse);

    await database.deleteEntry(entryId);
    expect(await database.deleteCategory(category), isTrue);
  });

  testWidgets('crea un integrante y lo asigna a un movimiento', (tester) async {
    const memberName = 'Prueba Miembro';
    const title = 'Prueba E2E integrante';

    Future<void> cleanup() async {
      final database = FinanceDatabase.instance;
      await _deleteEntriesStartingWith(title);
      for (final member in await database.getMembers()) {
        if (member.name != memberName) continue;
        for (final entry in await database.getEntries()) {
          if (entry.memberId == member.id && entry.id != null) {
            await database.deleteEntry(entry.id!);
          }
        }
        await database.deleteMember(member);
      }
    }

    await tester.runAsync(cleanup);
    await _startApp(tester);

    await tester.tap(find.text('Familia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo integrante'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, memberName);
    await tester.tap(find.text('Guardar integrante'));
    await _settle(tester);

    expect(find.text(memberName), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), title);
    await tester.enterText(fields.at(1), '321');

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(memberName).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);

    // Un segundo movimiento, sin integrante asignado, para probar el filtro.
    await tester.tap(find.text('Nuevo movimiento'));
    await tester.pumpAndSettle();
    final secondFields = find.byType(TextFormField);
    await tester.enterText(secondFields.at(0), '$title sin asignar');
    await tester.enterText(secondFields.at(1), '25');
    await tester.tap(find.text('Guardar movimiento'));
    await _settle(tester);

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(find.textContaining(memberName), findsWidgets);

    await tester.tap(find.widgetWithText(ChoiceChip, memberName));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(find.text('$title sin asignar'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sin asignar'));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
    expect(find.text('$title sin asignar'), findsOneWidget);

    // Editar un movimiento existente tocándolo.
    await tester.tap(find.text('$title sin asignar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar movimiento'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(memberName).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await _settle(tester);
    expect(find.text('$title sin asignar'), findsNothing);
    expect(find.text('Movimiento actualizado'), findsOneWidget);

    await tester.runAsync(cleanup);
  });

  test('crea y elimina integrantes', () async {
    final database = FinanceDatabase.instance;
    const name = 'Prueba Integrante';
    const title = 'Prueba integrante en uso';

    await _deleteEntriesStartingWith(title);
    for (final member in await database.getMembers()) {
      if (member.name == name) await database.deleteMember(member);
    }

    final member = await database.insertMember(
      FinanceMember(name: name, color: 0xFF4F78A1),
    );
    expect(member.id, isNotNull);
    expect(
      (await database.getMembers()).any((item) => item.name == name),
      isTrue,
    );

    await expectLater(
      database.insertMember(FinanceMember(name: name, color: 0xFF155C4B)),
      throwsA(isA<DuplicateMemberException>()),
    );

    final entryId = await database.insertEntry(
      FinanceEntry(
        title: title,
        amount: 10,
        category: 'Comida',
        date: DateTime.now(),
        isIncome: false,
        memberId: member.id,
      ),
    );
    final saved = (await database.getEntries()).firstWhere(
      (entry) => entry.id == entryId,
    );
    expect(saved.memberId, member.id);
    expect(await database.deleteMember(member), isFalse);

    await database.deleteEntry(entryId);
    expect(await database.deleteMember(member), isTrue);
  });

  test('SQLite guarda y elimina un movimiento', () async {
    final database = FinanceDatabase.instance;
    final id = await database.insertEntry(
      FinanceEntry(
        title: 'Prueba SQLite',
        amount: 1250.5,
        category: 'Comida',
        date: DateTime.now(),
        isIncome: false,
      ),
    );

    expect(
      (await database.getEntries()).any((entry) => entry.id == id),
      isTrue,
    );

    final saved = (await database.getEntries()).firstWhere(
      (entry) => entry.id == id,
    );
    expect(saved.amount, 1250.5);
    expect(saved.isIncome, isFalse);

    await database.deleteEntry(id);
    expect(
      (await database.getEntries()).any((entry) => entry.id == id),
      isFalse,
    );
  });

  testWidgets('guarda aportes distintos y valida la suma', (tester) async {
    final database = FinanceDatabase.instance;
    const title = 'Prueba aportes distintos';
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final memberA = await database.insertMember(
      FinanceMember(name: 'Aportes AAA $suffix', color: 0xFF4F78A1),
    );
    final memberB = await database.insertMember(
      FinanceMember(name: 'Aportes BBB $suffix', color: 0xFF8A6C9D),
    );

    await tester.pumpWidget(const MaterialApp(home: EntryFormScreen()));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), title);
    await tester.enterText(find.byType(TextFormField).at(1), '100,00');
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilterChip, memberA.name));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, memberA.name));
    await tester.ensureVisible(find.widgetWithText(FilterChip, memberB.name));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, memberB.name));
    await tester.pumpAndSettle();

    // Suma incorrecta: no debe guardar.
    await tester.enterText(find.byType(TextFormField).at(2), '70,00');
    await tester.enterText(find.byType(TextFormField).at(3), '20,00');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar movimiento'));
    await _settle(tester);
    expect(find.textContaining('Los aportes suman'), findsOneWidget);

    // Suma correcta: 70 + 30 = 100.
    await tester.enterText(find.byType(TextFormField).at(3), '30,00');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar movimiento'));
    await _settle(tester);

    final saved = (await database.getEntries()).firstWhere(
      (entry) => entry.title == title,
    );
    expect(saved.isShared, isTrue);
    expect(saved.shares.length, 2);
    final amounts = {
      for (final share in saved.shares) share.memberId: share.amount,
    };
    expect(amounts[memberA.id], 70);
    expect(amounts[memberB.id], 30);

    await _deleteEntriesStartingWith(title);
    await database.deleteMember(memberA);
    await database.deleteMember(memberB);
  });

  testWidgets(
    'el onboarding aparece solo la primera vez y persiste onboarding_completed',
    (tester) async {
      await AppSettings.instance.resetOnboarding();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('onboarding_completed'), isFalse);

      await _startFreshApp(tester);
      await _login(tester, skipIntro: false);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Bienvenido a tus finanzas'), findsOneWidget);
      expect(
        find.text(
          'Organizá tu dinero y tomá el control de tus finanzas desde un solo lugar',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Todo tu dinero organizado'), findsOneWidget);
      expect(
        find.text('Registrá tus ingresos, gastos y transferencias fácilmente'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Controlá tus gastos'), findsOneWidget);
      expect(
        find.text('Creá presupuestos y conocé cuánto podés gastar'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Alcanzá tus objetivos'), findsOneWidget);
      expect(
        find.text('Planificá tus ahorros y seguí tu progreso'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Comenzar'), findsOneWidget);

      await tester.tap(find.text('Comenzar'));
      await _settle(tester);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(AppSettings.instance.current.onboardingCompleted, isTrue);
      expect(preferences.getBool('onboarding_completed'), isTrue);

      // Al volver a ingresar, la introducción ya no se muestra.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _startFreshApp(tester);
      await _login(tester, skipIntro: false);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets('Anterior retrocede y Saltar guarda la finalización', (
    tester,
  ) async {
    await AppSettings.instance.resetOnboarding();
    await _startFreshApp(tester);
    await _login(tester, skipIntro: false);

    await tester.tap(find.widgetWithText(FilledButton, 'Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Todo tu dinero organizado'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Anterior'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a tus finanzas'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Anterior'), findsNothing);

    await tester.tap(find.text('Saltar'));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('Configuración permite volver a ver la introducción', (
    tester,
  ) async {
    await AppSettings.instance.markOnboardingCompleted();
    await _startApp(tester);

    await tester.tap(find.byTooltip('Configuración'));
    await _settle(tester);
    expect(find.text('Volver a ver la introducción'), findsOneWidget);
    await tester.ensureVisible(find.text('Volver a ver la introducción'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a ver la introducción'));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Bienvenido a tus finanzas'), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await _settle(tester);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Volver a ver la introducción'), findsOneWidget);
    expect(AppSettings.instance.current.onboardingCompleted, isTrue);
  });
}

/// Igual que [_startApp] pero sin iniciar sesión: lo hacen los tests que
/// necesitan observar el onboarding posterior al login.
Future<void> _startFreshApp(WidgetTester tester) async {
  await tester.runAsync(() async {
    await FinanceDatabase.instance.database;
  });
  await tester.pumpWidget(const FinanceApp());
  await _settle(tester);
}

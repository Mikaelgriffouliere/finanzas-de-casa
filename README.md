# Cuentas Claras

Aplicación personal de finanzas hecha con Flutter, Dart, Material 3 y SQLite.
Permite registrar ingresos y gastos, consultar el balance, revisar la actividad
y ver los gastos agrupados por categoría e integrante de la familia. Los datos
se guardan localmente en el dispositivo.

## Funcionalidad

- Inicio de sesión local **sin usuario ni contraseña por defecto**. En la
  primera apertura se muestra la introducción y se obliga a crear el usuario y
  la contraseña; recién después aparece el login. Las credenciales son
  modificables desde Configuración. Si se olvidan, el login ofrece
  **¿Olvidaste tus credenciales?**: borra solo usuario y contraseña, conserva
  la base de datos y vuelve al registro sin repetir la introducción. Los
  perfiles anteriores que solo tenían las credenciales de ejemplo `admin` /
  `admin123` también deben registrarse.
- Introducción animada de cuatro pasos (bienvenida, movimientos, presupuestos y
  metas de ahorro) que se muestra automáticamente después del primer ingreso.
  Se recorre con "Siguiente"/"Anterior" o se sale con "Saltar"; el estado se
  guarda en `SharedPreferences` bajo la clave `onboarding_completed` (con
  migración de la clave anterior `settings_intro_completed`). Al terminar, el
  usuario pasa por el registro antes de entrar al panel; se guarda con la clave
  `registration_completed`. La introducción se puede volver a ver desde
  Configuración → "Volver a ver la introducción". Las ilustraciones usan
  animaciones nativas de Flutter, sin dependencias extra, y respetan la
  preferencia de reducción de movimiento del sistema.
- Balance total y resumen del mes (ingresos y gastos), con animación de
  entrada, importes que se cuentan y barra animada de proporción ingresos/gastos.
- Alta de movimientos con descripción, importe, tipo, categoría y quién pagó.
- Integrantes de la familia con nombre y color, con pantalla de gestión.
- Pago compartido: marcar un movimiento y asignar un monto distinto a cada
  integrante (la suma debe igualar el importe total). Hay un botón
  "Partes iguales" para repartir automáticamente. Los aportes aparecen en
  actividad, análisis e informes.
- Filtro de actividad por integrante (incluye movimientos sin asignar).
- Reasignación del integrante tocando cualquier movimiento.
- Categorías personalizadas: nombre, ícono y color, con pantalla de gestión.
- Importes en formato local (`1.500,50`) o internacional (`1,500.50`).
- Actividad completa con eliminación mediante deslizamiento y confirmación.
- Análisis de gastos por categoría y por integrante.
- Informes detallados por período: resumen ejecutivo, lectura rápida con
  comparación contra el período anterior, desglose visual por categoría e
  integrante, detalle de movimientos y exportación PDF.
- Configuración: 4 paletas de colores, selector de logo (íconos prediseñados)
  y cambio de usuario y contraseña. Los ajustes se guardan automáticamente.

## Ejecutar

```bash
flutter pub get
flutter run -d linux          # escritorio
flutter run                   # Android / iOS
flutter run -d chrome         # web
```

### Linux

Requiere CMake, Ninja y un compilador de C++ funcional (`g++`). El proyecto
fuerza las rutas absolutas `/usr/bin/gcc` y `/usr/bin/g++` en
`linux/CMakeLists.txt` porque en algunos sistemas el `clang++` instalado no
encuentra los headers de C++ ni `libstdc++`, lo que hace fallar la generación de
archivos de build antes de compilar la app. Si cambiás de compilador, borrá
`build/linux/` para regenerar la caché de CMake.

### Web

SQLite en el navegador usa `sqlite3.wasm`. Los archivos necesarios ya están en
`web/`; si se borran o se actualiza `sqflite_common_ffi_web`, regenerarlos con:

```bash
dart run sqflite_common_ffi_web:setup
```

### Android / iOS

Instalá y configurá Android Studio y el Android SDK (o Xcode en macOS), luego
ejecutá `flutter run` con un dispositivo o emulador conectado.

Para generar el APK de release:

```bash
flutter build apk --release
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`. Requiere
JDK 17 y Android SDK con plataforma 36 y NDK 28.2.13676358. En este equipo el
toolchain se instaló sin sudo en `~/development/android-toolchain` (JDK) y
`~/development/android-sdk`, y Flutter ya está configurado con
`flutter config --android-sdk ~/development/android-sdk`. Si abrís otra
terminal, exportá `JAVA_HOME` apuntando al JDK antes de compilar.

El APK se firma con la configuración `debug` actual de
`android/app/build.gradle.kts`: sirve para instalarlo directamente, pero para
publicarlo en una tienda hay que generar una clave propia de release.

## Dónde se guardan los datos

- Android / iOS: en el almacenamiento privado de la app (sqflite).
- Linux / Windows / macOS: en la carpeta de soporte de la aplicación
  (`~/.local/share/com.example.finanzas_personales/nido_finanzas.db` en Linux).
  El identificador de paquete y el nombre del archivo de base se mantienen
  con el valor original a propósito: así al actualizar la app se siguen usando
  los datos existentes.
- Web: en el almacenamiento del navegador (Origin Private File System).
- Preferencias (paleta, logo y credenciales): en `SharedPreferences` de la
  plataforma correspondiente.

## Verificación

```bash
flutter analyze
flutter test
```

## Estructura

- `lib/main.dart`: interfaz Material 3 (inicio, actividad, análisis, categorías, familia e informes).
- `lib/app_settings.dart`: paletas, logos y persistencia de preferencias.
- `lib/settings_screen.dart`: pantalla de configuración.
- `lib/finance_database.dart`: modelos y acceso a SQLite.
- `lib/amount_parser.dart`: lectura de importes en formato local.
- `lib/category_visuals.dart`: íconos, colores y estilos de categorías.
- `lib/web_database_factory_*.dart`: inicialización de SQLite en web.
- `test/`: pruebas del parser, de la base de datos y de la interfaz.

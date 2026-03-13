// ARCHIVO MODIFICADO: main.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ntp/ntp.dart';

import 'ble_notifications_screen.dart';
import 'ble_repository.dart';
import 'bluetooth_screen.dart';
import 'inicio_saltos_multiples.dart';
import 'jump_data_processor.dart';
import 'file_manager_screen.dart';
import 'user_management_screen.dart';
import 'user_provider.dart';
import 'bluetooth_provider.dart';
import 'ble_status_indicator.dart';
import 'session_provider.dart';
import 'session_management_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- AÑADIR ESTA LÍNEA
import 'settings_provider.dart';
// --- IMPORTACIÓN NUEVA ---
import 'session_person_provider.dart';
import 'jump_storage_service.dart'; // <-- AÑADIR ESTA LÍNEA
// -------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
await initializeDateFormatting('es', null); // <-- AÑADIR ESTA LÍNEA
  final fechaDeCaducidad = DateTime(2026, 03, 21);
  DateTime fechaActual;

  try {
    fechaActual = await NTP.now();
    debugPrint('Verificación de fecha con hora de red exitosa.');
  } catch (e) {
    debugPrint('Fallo al obtener hora de red. Usando hora local. Error: $e');
    fechaActual = DateTime.now();
  }

  Widget appParaEjecutar;

  if (fechaActual.isAfter(fechaDeCaducidad)) {
    appParaEjecutar = const AppExpirada();
  } else {
    appParaEjecutar = MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleRepository()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        
        // --- NUEVO PROVIDER AÑADIDO ---
        ChangeNotifierProvider(create: (_) => SessionPersonProvider()),
        // -----------------------------
        // --- AÑADE ESTO ---
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        // -----------------

// --- AÑADE ESTO (Puede ser ChangeNotifierProvider si prefieres) ---
    Provider(create: (_) => JumpStorageService()),
    // -----------------------------------------------------------------

        ProxyProvider2<BleRepository, BluetoothProvider, BleMessageProcessor>(
          update: (_, bleRepo, bluetoothProvider, __) =>
              BleMessageProcessor(bleRepo, bluetoothProvider),
          lazy: false,
        ),
      ],
      child: const ChronoJumpApp(),
    );
  }

  runApp(appParaEjecutar);
}

// ... (El resto del archivo main.dart no necesita cambios)
// ... (Puedes dejarlo como estaba desde la línea de "class ChronoJumpApp")
class ChronoJumpApp extends StatelessWidget {
  const ChronoJumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Metri-x',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Positioned(
              top: 50.0,
              right: 80.0,
              child: BleStatusIndicator(),
            ),
          ],
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ConnectionPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const BluetoothScreen()));
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metri-x')),
 drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF3d5a80)), // Un azul más elegante
              child: Text(
                'Menú Principal',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('Gestión de Sesiones'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SessionManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Gestión de Personas'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Conexión',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: screenWidth,
              child: Image.asset(
                'assets/images/Metrix.png',
                fit: BoxFit.fitWidth,
              ),
            ),
            const Divider(color: Colors.white, thickness: 1, height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Plataforma de\n Contacto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Página de Conexión'));
  }
}

// En el archivo: lib/main.dart

// --- REEMPLAZA LA CLASE SettingsPage COMPLETA CON ESTE CÓDIGO ---
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Usamos un Consumer para que la UI se actualice automáticamente
    // cuando el usuario cambie la preferencia.
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Gestionar Archivos Guardados'),
              subtitle: const Text('Ver, compartir o eliminar registros'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FileManagerScreen(),
                  ),
                );
              },
            ),
            const Divider(),

            // --- SECCIÓN NUEVA AÑADIDA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Preferencias de Exportación',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            RadioListTile<ExportFormat>(
              title: const Text('Formato Latino'),
              subtitle: const Text('Separador de columna: ; (punto y coma)\nSeparador decimal: , (coma)'),
              value: ExportFormat.LATIN,
              groupValue: settings.exportFormat,
              onChanged: (ExportFormat? value) {
                if (value != null) {
                  // Cuando el usuario selecciona una opción, llamamos al provider
                  // para que guarde el cambio.
                  settings.setExportFormat(value);
                }
              },
            ),
            RadioListTile<ExportFormat>(
              title: const Text('Formato No Latino (EE.UU.)'),
              subtitle: const Text('Separador de columna: , (coma)\nSeparador decimal: . (punto)'),
              value: ExportFormat.NON_LATIN,
              groupValue: settings.exportFormat,
              onChanged: (ExportFormat? value) {
                if (value != null) {
                  settings.setExportFormat(value);
                }
              },
            ),
            const Divider(),
            // --- FIN DE LA SECCIÓN NUEVA ---
          ],
        );
      },
    );
  }
}
// -----------------------------------------------------------------

class AppExpirada extends StatelessWidget {
  const AppExpirada({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Esta versión de la aplicación ha expirado. Por favor, contacta al proveedor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.red[700]),
            ),
          ),
        ),
      ),
    );
  }
}
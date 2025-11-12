import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iteracion6/ble_repository.dart'; // Asegúrate de que la ruta sea correcta
import 'package:provider/provider.dart'; // Añade esta importación si no la tienes

class BleConnectionScreen extends StatefulWidget {
  final BluetoothDevice device;

  const BleConnectionScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<BleConnectionScreen> createState() => _BleConnectionScreenState();
}

class _BleConnectionScreenState extends State<BleConnectionScreen> {
  // Ya no necesitas esta línea si usas Provider, pero la dejo por si la usas en otros sitios
  // final BleRepository _bleRepo = BleRepository();
  String _status = 'Iniciando conexión...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[BLE] InitState - Dispositivo: ${widget.device.remoteId}');

    // <--- CAMBIO INICIA ---
    // LÍNEA ORIGINAL (causa el error):
    // _initiateConnection();

    // CORRECCIÓN APLICADA:
    // Agendamos la conexión para que se ejecute después de que la pantalla
    // se haya construido por primera vez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initiateConnection();
      }
    });
    // <--- CAMBIO TERMINA ---
  }

  Future<void> _initiateConnection() async {
    // Es una buena práctica obtener el provider aquí, dentro de un método.
    final bleRepo = Provider.of<BleRepository>(context, listen: false);

    setState(() {
      _status = 'Conectando y descubriendo servicios...';
      _isLoading = true;
    });

    final success = await bleRepo.connectAndDiscoverServices(widget.device);

    if (mounted) {
      setState(() {
        if (success) {
          _status = 'Conectado a ${widget.device.platformName}\n'
              'Servicios encontrados: ${bleRepo.writeCharacteristics.length + bleRepo.notifyCharacteristics.length} (escritura/notificación)';
        } else {
          _status = 'Error al conectar/descubrir servicios.';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión BLE'),
        backgroundColor: const Color(0xFF3d5a80),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFee6c4d)),
                  const SizedBox(height: 20),
                  Text(_status,
                      style: const TextStyle(color: Color(0xFF293241))),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _status,
                    style: const TextStyle(
                        fontSize: 18, color: Color(0xFF293241)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF98c1d9),
                      foregroundColor: const Color(0xFF293241),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Volver al menú'),
                  ),
                ],
              ),
      ),
    );
  }
}
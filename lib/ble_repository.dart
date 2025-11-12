// ARCHIVO: ble_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert'; // Necesario para utf8.decode
 // <--- CAMBIO INICIA
// 1. Importamos el provider para poder usarlo.
import 'bluetooth_provider.dart';
// <--- CAMBIO TERMINA

class BleRepository extends ChangeNotifier {
// Patrón Singleton para asegurar una única instancia del repositorio BLE
static final BleRepository _instance = BleRepository._internal();
factory BleRepository() => _instance;
BleRepository._internal();

BluetoothDevice? _device;
final List<BluetoothCharacteristic> _writeChars = [];
final List<BluetoothCharacteristic> _notifyChars = [];
StreamSubscription<BluetoothConnectionState>? _connectionSub;

// StreamController para exponer los mensajes BLE decodificados
final StreamController<String> _messageController = StreamController<String>.broadcast();
StreamSubscription<List<int>>? _notificationDataSubscription; // Nueva suscripción para los datos recibidos

// Propiedades públicas para acceder al estado y características
BluetoothDevice? get connectedDevice => _device;
bool get isConnected => _device?.isConnected ?? false;
List<BluetoothCharacteristic> get writeCharacteristics => _writeChars;
List<BluetoothCharacteristic> get notifyCharacteristics => _notifyChars;

// Getter para el stream de notificaciones procesadas (Strings)
// Las pantallas de UI se suscribirán a este stream
Stream<String> get bleMessageStream => _messageController.stream;

// --- MÉTODOS PARA INTERACTUAR CON BLE ---

/// Conecta a un dispositivo BLE y descubre sus servicios.
/// Retorna `true` si la conexión y el descubrimiento son exitosos, `false` en caso contrario.
Future<bool> connectAndDiscoverServices(BluetoothDevice device) async {
try {
// Si ya estamos conectados al mismo dispositivo, no hacer nada
if (_device != null && _device?.remoteId == device.remoteId && _device!.isConnected) {
debugPrint('[BLE Repo] Ya conectado al dispositivo: ${device.platformName}');
  // <--- CAMBIO INICIA
        // 2. Aseguramos que el estado sea 'conectado' si ya lo estaba.
        BluetoothProvider().updateStatus(BleStatus.connected);
        // <--- CAMBIO TERMINA
// Asegurarse de que las notificaciones estén activas si ya estaba conectado
if (_notifyChars.isNotEmpty && _notifyChars.first.isNotifying) {
_startListeningToNotifications(); // Reiniciar la escucha si es necesario
}
return true;
}

// Limpia recursos de una conexión anterior si existiera
if (_device != null) {
await disconnect();
}

_device = device; // Asigna el nuevo dispositivo antes de intentar conectar
notifyListeners(); // Notifica a los listeners que se está iniciando una nueva conexión
// <--- CAMBIO INICIA
      // 3. Notificamos que el proceso de conexión ha comenzado.
      BluetoothProvider().updateStatus(BleStatus.connecting);
      // <--- CAMBIO TERMINA

// Intento de conexión
debugPrint('[BLE Repo] Iniciando conexión a ${device.platformName}...');
await device.connect(timeout: const Duration(seconds: 15));
debugPrint('[BLE Repo] Conexión establecida con ${device.platformName}.');

// Suscripción al estado de conexión del dispositivo
_connectionSub?.cancel(); // Cancela cualquier suscripción anterior
_connectionSub = device.connectionState.listen((state) {
debugPrint('[BLE Repo] Estado de conexión de ${device.platformName}: $state');
if (state == BluetoothConnectionState.disconnected) {
_clearResources(); // Limpia los recursos si el dispositivo se desconecta
}
notifyListeners(); // Notifica cambios en el estado de conexión
});

// Descubrimiento de servicios y características
debugPrint('[BLE Repo] Descubriendo servicios...');
final services = await device.discoverServices();
_writeChars.clear();
_notifyChars.clear(); // Limpiar listas antes de añadir nuevas características

int servicesFoundCount = 0;
int charsFoundCount = 0;

for (var service in services) {
final serviceUuid = service.uuid.toString().toLowerCase();
final shortServiceUuid = _getShortUuid(serviceUuid);

// Ignorar servicios BLE estándar conocidos (GAP y GATT)
if (shortServiceUuid == '1800' || shortServiceUuid == '1801') {
debugPrint('[BLE Repo] Servicio $shortServiceUuid ignorado (estándar)');
continue;
}
servicesFoundCount++;
debugPrint('[BLE Repo] Servicio UUID: $shortServiceUuid ($serviceUuid)');

for (var characteristic in service.characteristics) {
final charShortUuid = _getShortUuid(characteristic.uuid.toString());
debugPrint('[BLE Repo] Característica $charShortUuid | Propiedades: ${characteristic.properties}');
charsFoundCount++;

// Identificar y almacenar características de escritura
if (characteristic.properties.write) {
_writeChars.add(characteristic);
debugPrint('[BLE Repo] Característica de escritura añadida: $charShortUuid');
}
// Identificar y configurar características de notificación
if (characteristic.properties.notify) {
_notifyChars.add(characteristic); // Añadir primero a la lista
await characteristic.setNotifyValue(true); // Activar notificaciones
debugPrint('[BLE Repo] Característica de notificación activada: $charShortUuid');
}
}
}

// Una vez que se encuentran las características de notificación, iniciar la escucha
if (_notifyChars.isNotEmpty) {
_startListeningToNotifications();
} else {
debugPrint('[BLE Repo] No se encontraron características de notificación, no se iniciará la escucha.');
}
 // <--- CAMBIO INICIA
      // 4. Notificamos que la conexión y descubrimiento fueron exitosos.
      BluetoothProvider().updateStatus(BleStatus.connected);
      // <--- CAMBIO TERMINA
debugPrint('[BLE Repo] Resumen del descubrimiento: $servicesFoundCount servicios, $charsFoundCount características.');
notifyListeners(); // Notifica que las características han sido cargadas
return true;

} catch (e) {
debugPrint('[BLE Repo] Error en connectAndDiscoverServices: $e');
await disconnect(); // Asegura la limpieza si ocurre un error durante la conexión/descubrimiento
notifyListeners(); // Notifica el cambio de estado debido al error
return false;
}
}


/// Inicia la suscripción para escuchar los datos de notificación del BLE.
void _startListeningToNotifications() {
  _notificationDataSubscription?.cancel(); // Cancelar cualquier suscripción anterior de datos
  if (_notifyChars.isNotEmpty) {
    // Nos suscribimos a la primera característica de notificación encontrada
    _notificationDataSubscription = _notifyChars.first.onValueReceived.listen(
      (data) {
        
        // --- CAMBIO FINAL INICIA ---
        
        // 1. Decodifica el mensaje original (ej: "-1865090421")
        final originalMessage = utf8.decode(data).trim();
        debugPrint('[BLE Repo] Datos crudos recibidos: "$originalMessage"');

        String estado;
        String valorLimpio;

        // 2. Aplica la lógica de transformación
        if (originalMessage.startsWith('-')) {
          // Si es NEGATIVO (ej: "-1865090421")
          estado = '1'; // Se convierte en estado 0
          valorLimpio = originalMessage.substring(1); // Se quita el "-" (queda "1865090421")
        } else {
          // Si es POSITIVO (ej: "1900000000")
          estado = '0'; // Se convierte en estado 1
          valorLimpio = originalMessage; // Queda igual
        }

        // 3. Reconstruye el mensaje al formato "estado;valor" que espera el procesador
        final finalProcessedMessage = '$estado;$valorLimpio'; // <-- ¡EL CAMBIO CLAVE!
        
        debugPrint('[BLE Repo] Mensaje procesado enviado: "$finalProcessedMessage"');

        // 4. Envía el mensaje transformado al resto de la app
        _messageController.add(finalProcessedMessage);
        
        // --- CAMBIO FINAL TERMINA ---
      },
      onError: (error) {
        debugPrint('[BLE Repo] Error en el stream de datos de notificación: $error');
      },
      onDone: () {
        debugPrint('[BLE Repo] Stream de datos de notificación cerrado.');
        _notificationDataSubscription = null;
      },
    );
    debugPrint('[BLE Repo] Suscripción a notificaciones iniciada.');
  }
}
/// Desconecta el dispositivo BLE actual y limpia todos los recursos asociados.
Future<void> disconnect() async {
debugPrint('[BLE Repo] Desconectando...');
await _device?.disconnect(); // Intenta desconectar el dispositivo
_clearResources(); // Llama a la función interna para limpiar el estado
debugPrint('[BLE Repo] Desconexión completada y recursos limpiados.');
}

/// Escribe datos en la primera característica de escritura disponible.
Future<void> writeData(List<int> data) async {
if (!isConnected) {
throw Exception('No hay un dispositivo BLE conectado para escribir.');
}
if (_writeChars.isEmpty) {
throw Exception('No se encontraron características de escritura en el dispositivo conectado.');
}
// Escribe los datos en la primera característica de escritura
await _writeChars.first.write(data, withoutResponse: false); // Añadir withoutResponse si es apropiado
debugPrint('[BLE Repo] Datos escritos: $data');
}

// --- MÉTODOS INTERNOS DE APOYO ---

/// Extrae los últimos 4 caracteres de un UUID completo para una representación corta.
String _getShortUuid(String fullUuid) {
try {
final cleanUuid = fullUuid.toLowerCase()
.replaceAll('-', '')
.replaceAll('0000', '')
.replaceAll('00805f9b34fb', ''); // Limpia partes comunes de UUID base
return cleanUuid.length >= 4
? cleanUuid.substring(cleanUuid.length - 4) // Toma los últimos 4 si es lo suficientemente largo
: cleanUuid; // Si es más corto, usa todo el UUID
} catch (e) {
debugPrint('[BLE] Error al procesar UUID: $fullUuid');
return fullUuid; // Retorna el UUID original si hay un error
}
}

/// Limpia el estado interno del repositorio BLE.
void _clearResources() {
_device = null;
_writeChars.clear();
_notifyChars.clear();
_connectionSub?.cancel(); // Cancela la suscripción al estado de conexión
_connectionSub = null;
_notificationDataSubscription?.cancel(); // ¡Importante! Cancelar también esta suscripción
_notificationDataSubscription = null;
debugPrint('[BLE Repo] Recursos internos limpiados.');
// <--- CAMBIO INICIA
    // 5. Centralizamos la notificación de 'desconectado' aquí.
    //    Este método se llama tanto en `disconnect()` como cuando la conexión se pierde.
    BluetoothProvider().updateStatus(BleStatus.disconnected);
    // <--- CAMBIO TERMINA
notifyListeners(); // Notifica a los listeners que el estado ha cambiado (desconectado)
}

@override
void dispose() {
debugPrint('[BLE Repo] Dispose - Limpiando recursos finales del repositorio.');
_connectionSub?.cancel();
_notificationDataSubscription?.cancel(); // Asegura que se cancelen las suscripciones al desechar
_messageController.close(); // Cierra el StreamController
super.dispose();
}
}
// ARCHIVO MODIFICADO: lib/bluetooth_provider.dart

import 'package:flutter/material.dart';

enum BleStatus {
  disconnected,
  connecting,
  connected,
}

class BluetoothProvider extends ChangeNotifier {
  // <--- CAMBIO INICIA
  // 1. Añadimos el patrón Singleton para que sea consistente con tu BleRepository.
  static final BluetoothProvider _instance = BluetoothProvider._internal();
  factory BluetoothProvider() => _instance;
  BluetoothProvider._internal();
  // <--- CAMBIO TERMINA

  BleStatus _status = BleStatus.disconnected;
  BleStatus get status => _status;

 // --- LÍNEAS AÑADIDAS ---
  int _lastPinState = -1;
  int get lastPinState => _lastPinState;
  // --- FIN LÍNEAS AÑADIDAS ---

  void updateStatus(BleStatus newStatus) {
 debugPrint("--- CAMBIANDO ESTADO BLE A: $newStatus ---"); 
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }
// --- MÉTODO AÑADIDO ---
  void updatePinState(int newState) {
    if (_lastPinState != newState) {
      _lastPinState = newState;
      notifyListeners(); // Notifica a los widgets que el estado del pin cambió
    }
  }
  // --- FIN MÉTODO AÑADIDO ---
}
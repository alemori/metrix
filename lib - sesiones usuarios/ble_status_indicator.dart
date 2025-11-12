// ARCHIVO CORREGIDO: lib/ble_status_indicator.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'bluetooth_provider.dart';

class BleStatusIndicator extends StatelessWidget {
  const BleStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer se redibuja automáticamente cuando notifyListeners() es llamado
    return Consumer<BluetoothProvider>(
      builder: (context, bleProvider, child) {
        IconData icon;
        Color color;
        // String tooltip; // Ya no necesitamos el tooltip

        switch (bleProvider.status) {
          case BleStatus.connected:
            icon = Icons.bluetooth_connected;
            color = Colors.lightBlueAccent;
            // tooltip = 'Bluetooth Conectado';
            break;
          case BleStatus.connecting:
            icon = Icons.bluetooth_searching;
            color = Colors.grey;
            // tooltip = 'Conectando Bluetooth...';
            break;
          case BleStatus.disconnected:
          default:
            icon = Icons.bluetooth_disabled;
            color = Colors.redAccent;
            // tooltip = 'Bluetooth Desconectado';
            break;
        }

        // Devolvemos directamente el Icon, sin el Tooltip que causaba el error.
        return Icon(icon, color: color);
      },
    );
  }
}
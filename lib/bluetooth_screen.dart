import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_connection_screen.dart';

class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key}); // Usando super parameter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos BLE')),
      body: StreamBuilder<List<ScanResult>>(
        stream: FlutterBluePlus.scanResults,
        builder: (context, snapshot) {
          final results = snapshot.data ?? [];
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final device = results[index].device;
              return ListTile(
                title: Text(device.platformName.isNotEmpty 
                    ? device.platformName 
                    : 'Dispositivo Desconocido'),
                subtitle: Text(device.remoteId.toString()), // Usando remoteId
                onTap: () {
                  FlutterBluePlus.stopScan();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BleConnectionScreen(device: device),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: () => FlutterBluePlus.startScan(timeout: const Duration(seconds: 10)),
      ),
    );
  }
}
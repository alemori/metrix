import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'user_model.dart';
// En lib/export_service.dart
import 'settings_provider.dart';

class ExportService {
  // En el archivo: lib/export_service.dart

  // En el archivo: lib/export_service.dart

// En el archivo: lib/export_service.dart
// Reemplaza esta función completa:

Future<void> smartExportToChronojumpFormat({
  required File sourceFile,
  required List<User> allUsers,
  required BuildContext context,
  required ExportFormat format,
}) async {
  debugPrint("--- INICIANDO EXPORTACIÓN INTELIGENTE ---");
  try {
    final inputString = await sourceFile.readAsString();
    final List<List<dynamic>> rows = CsvToListConverter(eol: '\n').convert(inputString);

    if (rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo no contiene datos.')));
      return;
    }

    final header = rows.first;
    if (header.length < 5 || header[0] != 'SessionID' || header[2] != 'Jump Type') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este archivo no es un registro de saltos exportable.')));
      return;
    }

    List<List<dynamic>> simpleJumpsOutput = [];
    List<List<dynamic>> multiJumpsOutput = [];
    final validSimpleJumps = {'SJ', 'SJl', 'CMJ', 'ABK', 'DJ_EX', 'DJ_IN'};

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue;
      
      final jumpType = row[2].toString();
      if (validSimpleJumps.contains(jumpType)) {
        // --- CORRECCIÓN 1: Se pasa el parámetro 'format' ---
        simpleJumpsOutput.add(_processSimpleJumpRow(row, allUsers, format));
      } else if (jumpType.startsWith('RJ') && row.length >= 9) {
        // --- CORRECCIÓN 2: Se pasa el parámetro 'format' ---
        multiJumpsOutput.add(_processMultiJumpRow(row, allUsers, format));
      }
    }

    List<XFile> filesToShare = [];
    if (simpleJumpsOutput.isNotEmpty) {
      // --- CORRECCIÓN 3: Se pasa el parámetro 'format' ---
      final file = await _buildSimpleJumpFile(simpleJumpsOutput, sourceFile.path, format);
      filesToShare.add(XFile(file.path));
    }
    if (multiJumpsOutput.isNotEmpty) {
      // --- CORRECCIÓN 4: Se pasa el parámetro 'format' ---
      final file = await _buildMultiJumpFile(multiJumpsOutput, sourceFile.path, format);
      filesToShare.add(XFile(file.path));
    }

    if (filesToShare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontraron saltos con formato exportable en este archivo.')));
    } else {
      await Share.shareXFiles(filesToShare);
    }

  } catch (e, s) {
    debugPrint("!!! ERROR en smartExport: $e, $s");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar el archivo: $e')));
  }
}
  List<dynamic> _processSimpleJumpRow(
    List<dynamic> row,
    List<User> allUsers,
    ExportFormat format,
  ) {
    final userId = int.tryParse(row[1].toString());
    final jumpType = row[2].toString();
    final contactTimeMs = double.tryParse(row[3].toString()) ?? 0;
    final flightTimeMs = double.tryParse(row[4].toString()) ?? 0;
    User? user;
    try {
      user = allUsers.firstWhere((u) => u.uniqueID == userId);
    } catch (e) {
      user = User(
        uniqueID: 0,
        muuid: '',
        firstName: 'Desconocido',
        lastName: '',
      );
    }

    // Se preparan los valores en segundos
    String flightTimeSec = (flightTimeMs / 1000).toStringAsFixed(3);
    String contactTimeSec =
        (contactTimeMs == -1)
            ? '-1'
            : (contactTimeMs / 1000).toStringAsFixed(3);

    // --- CAMBIO: Se aplica la preferencia de formato decimal ---
    if (format == ExportFormat.LATIN) {
      flightTimeSec = flightTimeSec.replaceAll('.', ',');
      contactTimeSec = contactTimeSec.replaceAll('.', ',');
    }

    // --- CAMBIO: La función ahora devuelve solo 5 columnas ---
    return [
      user.firstName,
      user.lastName,
      jumpType,
      flightTimeSec,
      contactTimeSec,
    ];
  }

  Future<File> _buildSimpleJumpFile(
    List<List<dynamic>> rows,
    String sourcePath,
    ExportFormat format,
  ) async {
    // --- CAMBIO: El encabezado ahora solo tiene 5 columnas ---
    rows.insert(0, [
      'Nombre',
      'Apellido',
      'Tipo de Salto',
      'Tiempo de Vuelo (s)',
      'Tiempo de Contacto (s)',
    ]);

    // --- CAMBIO: El separador de columnas se decide según la preferencia ---
    final fieldDelimiter = (format == ExportFormat.LATIN) ? ';' : ',';
    final converter = ListToCsvConverter(fieldDelimiter: fieldDelimiter);

    final String csvString = converter.convert(rows);
    final tempDir = await getTemporaryDirectory();
    final String fileName = 'Export_Simple_${sourcePath.split('/').last}';
    final File tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(csvString);
    return tempFile;
  }
  // En el archivo: lib/export_service.dart

  // --- CAMBIO: La firma de la función ahora acepta el parámetro 'format' ---
  List<dynamic> _processMultiJumpRow(
    List<dynamic> row,
    List<User> allUsers,
    ExportFormat format,
  ) {
    final userId = int.tryParse(row[1].toString());
    final jumpType = row[2].toString();
    final allContactTimesStr = row[3].toString();
    final allFlightTimesStr = row[4].toString();
    final pesoPersona = double.tryParse(row[7].toString()) ?? 0.0;
    final alturaPersona = int.tryParse(row[8].toString()) ?? 0;
    User? user;
    try {
      user = allUsers.firstWhere((u) => u.uniqueID == userId);
    } catch (e) {
      user = User(
        uniqueID: 0,
        muuid: '',
        firstName: 'Desconocido',
        lastName: '',
      );
    }

    // --- CAMBIO: Se aplica la preferencia de formato al peso ---
    String pesoPersonaFormatted = pesoPersona.toStringAsFixed(2);
    if (format == ExportFormat.LATIN) {
      pesoPersonaFormatted = pesoPersonaFormatted.replaceAll('.', ',');
    }

    List<dynamic> newRow = [
      user.firstName,
      user.lastName,
      jumpType,
      alturaPersona,
      pesoPersonaFormatted,
    ];

    final contactTimes = allContactTimesStr.split('=');
    final flightTimes = allFlightTimesStr.split('=');
    int jumpCount =
        contactTimes.length < flightTimes.length
            ? contactTimes.length
            : flightTimes.length;

    for (int j = 0; j < jumpCount; j++) {
      final tcMs = double.tryParse(contactTimes[j]) ?? 0;
      final tfMs = double.tryParse(flightTimes[j]) ?? 0;

      String tcSec = (tcMs == -1) ? '-1' : (tcMs / 1000).toStringAsFixed(3);
      String tfSec = (tfMs / 1000).toStringAsFixed(3);

      // --- CAMBIO: Se aplica la preferencia de formato a los tiempos ---
      if (format == ExportFormat.LATIN) {
        tcSec = tcSec.replaceAll('.', ',');
        tfSec = tfSec.replaceAll('.', ',');
      }

newRow.add(tcSec);
newRow.add(tfSec);
    }
    return newRow;
  }

  Future<File> _buildMultiJumpFile(
    List<List<dynamic>> rows,
    String sourcePath,
    ExportFormat format,
  ) async {
    int maxJumps =
        rows.fold(0, (prev, row) => row.length > prev ? row.length : prev) - 5;
    List<String> header = [
      'Nombre',
      'Apellido',
      'Tipo de Salto',
      'Altura',
      'Peso',
    ];
    for (int k = 1; k <= maxJumps; k++) {
     header.add('TC$k (s)');
header.add('TF$k (s)');
    }
    rows.insert(0, header);

    // --- CAMBIO: El separador de columnas se decide según la preferencia ---
    final fieldDelimiter = (format == ExportFormat.LATIN) ? ';' : ',';
    final converter = ListToCsvConverter(fieldDelimiter: fieldDelimiter);

    final String csvString = converter.convert(rows);
    final tempDir = await getTemporaryDirectory();
    final String fileName = 'Export_MultiJump_${sourcePath.split('/').last}';
    final File tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(csvString);
    return tempFile;
  }
}

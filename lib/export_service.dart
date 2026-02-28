import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'user_model.dart';
import 'settings_provider.dart';

class ExportService {

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
   //   final validSimpleJumps = {'SJ', 'SJl', 'CMJ', 'ABK', 'DJ_EX', 'DJ_IN'};
      final validSimpleJumps = {'SJ', 'SJl', 'CMJ', 'ABK', 'DJ_EX', 'DJ_IN', 'DJna', 'DJa'};

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 6) continue;
        
        final jumpType = row[2].toString();
        if (validSimpleJumps.contains(jumpType)) {
          simpleJumpsOutput.add(_processSimpleJumpRow(row, allUsers, format));
        } else if (jumpType.startsWith('RJ') && row.length >= 9) {
          multiJumpsOutput.add(_processMultiJumpRow(row, allUsers, format));
        }
      }

      List<XFile> filesToShare = [];
      if (simpleJumpsOutput.isNotEmpty) {
        final file = await _buildSimpleJumpFile(simpleJumpsOutput, sourceFile.path, format);
        filesToShare.add(XFile(file.path));
      }
      if (multiJumpsOutput.isNotEmpty) {
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

    String flightTimeSec = (flightTimeMs / 1000).toStringAsFixed(3);
    String contactTimeSec =
        (contactTimeMs == -1)
            ? '-1'
            : (contactTimeMs / 1000).toStringAsFixed(3);

    if (format == ExportFormat.LATIN) {
      flightTimeSec = flightTimeSec.replaceAll('.', ',');
      contactTimeSec = contactTimeSec.replaceAll('.', ',');
    }

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
    rows.insert(0, [
      'Nombre',
      'Apellido',
      'Tipo de Salto',
      'Tiempo de Vuelo (s)',
      'Tiempo de Contacto (s)',
    ]);

    final fieldDelimiter = (format == ExportFormat.LATIN) ? ';' : ',';
    final converter = ListToCsvConverter(fieldDelimiter: fieldDelimiter);

    final String csvString = converter.convert(rows);
    final tempDir = await getTemporaryDirectory();
    final String fileName = 'Export_Simple_${sourcePath.split('/').last}';
    final File tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsString(csvString);
    return tempFile;
  }

  List<dynamic> _processMultiJumpRow(
    List<dynamic> row,
    List<User> allUsers,
    ExportFormat format,
  ) {
    final userId = int.tryParse(row[1].toString());
    String jumpType = row[2].toString(); 
    final allContactTimesStr = row[3].toString();
    final allFlightTimesStr = row[4].toString();
    

// --- CORRECCIÓN DE ÍNDICES ---
    // En tu DB, PesoPersona está en la 7 y AlturaCaida en la 6.
    final pesoExtra = double.tryParse(row[7].toString()) ?? 0.0; 
    double alturaCaida = double.tryParse(row[6].toString()) ?? 0.0; // ¡Cambiamos a 6!



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

    final contactTimes = allContactTimesStr.split('=');
    final flightTimes = allFlightTimesStr.split('=');

    // Validación del Inicio Interno
    bool startsInside = contactTimes.isNotEmpty && contactTimes.first.trim() == '-1';

    if (startsInside) {
      jumpType = "RJ(unlimited)"; 
      alturaCaida = 0.0;          
    }

    String pesoExtraFormatted = pesoExtra.toStringAsFixed(2);
    String alturaCaidaFormatted = alturaCaida.toStringAsFixed(0); 
    
    if (format == ExportFormat.LATIN) {
      pesoExtraFormatted = pesoExtraFormatted.replaceAll('.', ',');
      alturaCaidaFormatted = alturaCaidaFormatted.replaceAll('.', ',');
    }

    List<dynamic> newRow = [
      user.firstName,
      user.lastName,
      jumpType,             
      alturaCaidaFormatted, 
      pesoExtraFormatted,   
    ];

    int jumpCount = contactTimes.length < flightTimes.length
        ? contactTimes.length
        : flightTimes.length;

    for (int j = 0; j < jumpCount; j++) {
      final tcMs = double.tryParse(contactTimes[j]) ?? 0;
      final tfMs = double.tryParse(flightTimes[j]) ?? 0;

      String tcSec = (tcMs == -1) ? '-1' : (tcMs / 1000).toStringAsFixed(3);
      String tfSec = (tfMs / 1000).toStringAsFixed(3);

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
      'Caida (cm)',   
      'Peso (%)',     
    ];
    
    for (int k = 1; k <= maxJumps; k++) {
      header.add('TC$k (s)');
      header.add('TF$k (s)');
    }
    rows.insert(0, header);

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
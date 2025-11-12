// ARCHIVO NUEVO: lib/jump_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';

// Importamos los modelos de datos que necesita
import 'jump_data_processor.dart';
import 'user_model.dart';

class JumpStorageService {
  // --- LÓGICA DE RUTAS (Movida desde ble_notifications_screen) ---

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String dateStamp) async {
    final path = await _localPath;
    return File('$path/Chronojump_saltos_$dateStamp.csv');
  }

  // --- LÓGICA DE EXPORTACIÓN (Movida desde ble_notifications_screen) ---

  // Esta función era _saveChronojumpFormattedFile
  Future<void> _saveChronojumpFormattedFile({
    required List<JumpData> jumps,
    required User? person,
    required String jumpType,
  }) async {
    if (jumps.isEmpty || person == null) {
      return;
    }

    try {
      final path = await _localPath;
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStamp = dateFormat.format(DateTime.now());
      final file = File('$path/Chronojump_Export_Simple_$dateStamp.csv');

      List<List<dynamic>> rows = [];

      if (!await file.exists()) {
        rows.add([
          'Nombre',
          'Apellido',
          'Tipo de Salto',
          'Tiempo de Vuelo (s)',
          'Tiempo de Contacto (s)'
        ]);
      }

      for (final jump in jumps) {
        final tfEnSegundos = jump.flightTime / 1000;
        final tcEnSegundos =
            jump.contactTime == 0 ? -1 : jump.contactTime / 1000;

        final tfFormatted = tfEnSegundos.toStringAsFixed(3).replaceAll('.', ',');
        final tcFormatted = tcEnSegundos == -1
            ? '-1'
            : tcEnSegundos.toStringAsFixed(3).replaceAll('.', ',');

        rows.add([
          person.firstName,
          person.lastName,
          jumpType,
          tfFormatted,
          tcFormatted,
        ]);
      }

      final converter = ListToCsvConverter(fieldDelimiter: ';');
      final String csvContent = converter.convert(rows);

      final contentToWrite = (await file.exists())
          ? csvContent.substring(csvContent.indexOf('\n') + 1)
          : csvContent;

      await file.writeAsString(contentToWrite, mode: FileMode.append);
      debugPrint('Exportación formato Chronojump guardada en: ${file.path}');
    } catch (e) {
      debugPrint('Error al guardar el archivo en formato Chronojump: $e');
    }
  }

  // --- LÓGICA PRINCIPAL DE GUARDADO (Movida desde ble_notifications_screen) ---

  // Esta es la función pública que llamará la pantalla.
  // Reemplaza a _saveDataToFile
  Future<File?> saveData({
    required List<JumpData> jumpsToSave,
    required String jumpType,
    required User? person,
    required int? sessionID,
    required int limiteSaltos,
    required int limiteTiempo,
    required double alturaCaida,
    required double pesoPersona,
    required int alturaPersona,
  }) async {
    // La pantalla ya no debe llamar a este servicio si la lista está vacía,
    // pero mantenemos la comprobación por seguridad.
    if (jumpsToSave.isEmpty) {
      debugPrint(
          "[SAVE_SERVICE] Se llamó a saveData con 0 saltos. Saliendo.");
      return null;
    }

    debugPrint(
        "[SAVE_SERVICE] Se llamó a saveData con ${jumpsToSave.length} saltos.");

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStamp = dateFormat.format(DateTime.now());
      final file = await _localFile(dateStamp); // Pasa el dateStamp
      String csvContent = '';

      if (!await file.exists()) {
        debugPrint("[SAVE_SERVICE] El archivo no existe. Creando encabezado.");
        csvContent +=
            'SessionID,UserID,Jump Type,TC,TF,Timestamp,AlturaCaida(cm),PesoPersona(kg),AlturaPersona(cm)\n';
      }

      if (jumpType == 'MULTI' || jumpType == 'DJ_IN') {
        debugPrint("[SAVE_SERVICE] Detectado salto Múltiple/Complejo.");
        String jumpTypeString;
        if (jumpType == 'MULTI') {
          if (limiteSaltos > 0) {
            jumpTypeString = 'RJ(j)';
          } else if (limiteTiempo > 0) {
            jumpTypeString = 'RJ(t)';
          } else {
            jumpTypeString = 'RJ(unlimited)';
          }
        } else {
          jumpTypeString = jumpType;
        }
        debugPrint("[SAVE_SERVICE] Tipo de salto a guardar: $jumpTypeString");

        final String allContactTimes = jumpsToSave
            .map((j) => j.contactTime == 0 ? '-1' : j.contactTime.toStringAsFixed(2))
            .join('=');
        final String allFlightTimes =
            jumpsToSave.map((j) => j.flightTime.toStringAsFixed(2)).join('=');
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        final sID = sessionID ?? 0;
        final userID = person?.uniqueID.toString() ?? ''; // <-- USA EL CAMPO VACÍO
        final aCaida = alturaCaida.toStringAsFixed(2);
        final pPersona = pesoPersona.toStringAsFixed(2);
        final aPersona = alturaPersona.toString();

        csvContent +=
            '$sID,$userID,$jumpTypeString,$allContactTimes,$allFlightTimes,$timestamp,$aCaida,$pPersona,$aPersona\n';
      } else {
        debugPrint("[SAVE_SERVICE] Detectado salto Simple.");
        // Llama a la función de guardado secundario
        await _saveChronojumpFormattedFile(
          jumps: jumpsToSave,
          person: person,
          jumpType: jumpType,
        );

        for (final jump in jumpsToSave) {
          final tc =
              jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2);
          final tf = jump.flightTime.toStringAsFixed(2);
          final timestamp =
              DateFormat('yyyy-MM-dd HH:mm:ss').format(jump.timestamp);
          final sID = sessionID ?? 0;
          final userID = person?.uniqueID.toString() ?? ''; // <-- USA EL CAMPO VACÍO
          csvContent += '$sID,$userID,$jumpType,$tc,$tf,$timestamp,,,\n';
        }
      }

      debugPrint(
          "[SAVE_SERVICE] Contenido a escribir en el archivo: $csvContent");

      await file.writeAsString(csvContent, mode: FileMode.append);
      debugPrint("[SAVE_SERVICE] Escritura en archivo completada.");

      // Devuelve el archivo guardado para que la UI pueda usarlo
      return file;
    } catch (e) {
      debugPrint("!!! ERROR en JumpStorageService: $e !!!");
      // Lanza el error para que la UI pueda manejarlo (mostrar SnackBar)
      throw Exception('Error al guardar el archivo: $e');
    }
  }
}
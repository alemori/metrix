// ARCHIVO NUEVO: lib/jump_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

// Importamos los modelos de datos que necesita
import 'jump_data_processor.dart';
import 'user_model.dart';

class JumpStorageService {

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String dateStamp) async {
    final path = await _localPath;
    // Ahora el nombre base es "Metrix_Crudo" para evitar confusiones
    return File('$path/Metrix_Crudo_$dateStamp.csv');
  }

  // --- LÓGICA PRINCIPAL DE GUARDADO ---
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
    if (jumpsToSave.isEmpty) {
      debugPrint("[SAVE_SERVICE] Se llamó a saveData con 0 saltos. Saliendo.");
      return null;
    }

    try {
      // --- MAGIA AQUÍ: Fecha Y HORA EXACTA para un archivo único ---
      final exactTimeStamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final file = await _localFile(exactTimeStamp);
      
      String csvContent = 'SessionID,UserID,Jump Type,TC,TF,Timestamp,AlturaCaida(cm),PesoPersona(kg),AlturaPersona(cm)\n';

      if (jumpType == 'MULTI' || jumpType == 'DJ_IN') {
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

        final String allContactTimes = jumpsToSave.map((j) => j.contactTime == 0 ? '-1' : j.contactTime.toStringAsFixed(2)).join('=');
        final String allFlightTimes = jumpsToSave.map((j) => j.flightTime.toStringAsFixed(2)).join('=');
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        final sID = sessionID ?? 0;
        final userID = person?.uniqueID.toString() ?? ''; 
        final aCaida = alturaCaida.toStringAsFixed(2);
        final pPersona = pesoPersona.toStringAsFixed(2);
        final aPersona = alturaPersona.toString();

        csvContent += '$sID,$userID,$jumpTypeString,$allContactTimes,$allFlightTimes,$timestamp,$aCaida,$pPersona,$aPersona\n';
      } else {
        // Lógica para saltos simples (SJ, CMJ, etc.)
        for (final jump in jumpsToSave) {
          final tc = jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2);
          final tf = jump.flightTime.toStringAsFixed(2);
          final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(jump.timestamp);
          final sID = sessionID ?? 0;
          final userID = person?.uniqueID.toString() ?? ''; 
          csvContent += '$sID,$userID,$jumpType,$tc,$tf,$timestamp,,,\n';
        }
      }

      await file.writeAsString(csvContent); // Ya no usamos append, sobrescribimos todo
      debugPrint("[SAVE_SERVICE] Guardado exitoso: ${file.path}");
      return file;
    } catch (e) {
      debugPrint("!!! ERROR en JumpStorageService: $e !!!");
      throw Exception('Error al guardar el archivo: $e');
    }
  }
}
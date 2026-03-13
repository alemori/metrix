// ARCHIVO NUEVO: lib/audit_sync_service.dart

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'jump_data_processor.dart'; // Para conocer la estructura de JumpData
import 'user_model.dart';

class AuditSyncService {
  // Ruta al nuevo script PHP que recibirá el track de saltos
  
  static const String _auditUrl = 'https://www.4genapp.com.ar/descargas/metrix/track_salto.php';
  // Función fire-and-forget (no traba la pantalla)
  static Future<void> registrarSaltoSilencioso({
    required JumpData salto,
    required String tipoSalto,
    User? atleta,
    int? sessionID,
  }) async {
    try {
      // Disparamos la petición sin esperar la respuesta para no frenar la UI
      http.post(
        Uri.parse(_auditUrl),
        body: {
          'session_id': sessionID?.toString() ?? '0',
          // EL CAMBIO ESTÁ AQUÍ: Agregamos el .toString() al ID del atleta
          'atleta_id': atleta?.uniqueID?.toString() ?? 'SIN_ATLETA', 
          'atleta_nombre': atleta != null ? '${atleta.firstName} ${atleta.lastName}' : 'Desconocido',
          'tipo_salto': tipoSalto,
          'altura_cm': salto.height.toStringAsFixed(2),
          'vuelo_ms': salto.flightTime.toStringAsFixed(2),
          'contacto_ms': salto.contactTime.toStringAsFixed(2),
          'timestamp': salto.timestamp.toIso8601String(),
        },
      ).timeout(const Duration(seconds: 10)).then((response) {
        if (response.statusCode == 200) {
          debugPrint('Auditoría: Salto registrado en el servidor.');
        } else {
          debugPrint('Auditoría: Falló el registro (Código ${response.statusCode}).');
        }
      }).catchError((e) {
        debugPrint('Auditoría: Error de red silencioso: $e');
      });
    } catch (e) {
      debugPrint('Auditoría: Excepción general: $e');
    }
  }
}
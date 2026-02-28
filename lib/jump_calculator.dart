// ARCHIVO ACTUALIZADO: jump_calculator.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'jump_data_processor.dart';

// ----- CLASES HELPER PARA GESTIONAR EVENTOS -----
enum EventType { Despegue, Aterrizaje }

class JumpEvent {
  final EventType type;
  final double timestamp_ms;

  JumpEvent({required this.type, required this.timestamp_ms});

  @override
  String toString() => 'Evento: $type, Tiempo: $timestamp_ms';
}
// ------------------------------------------------

class JumpCalculator {
  static const double gravity = 9.81;

  /// Método principal que delega el cálculo según el tipo de salto.
  /// Ahora devuelve una LISTA de JumpData, ya que un tipo de salto (como DJ_IN) puede generar múltiples resultados.
  List<JumpData> calculateJumpFromRawData(Map<String, dynamic> rawCollection) {
    final String? jumpType = rawCollection['jumpType'];
    // final List<Map<String, String>> dataPoints = rawCollection['data'];
    final List<dynamic> rawDataPoints = rawCollection['data'] ?? [];
    final bool comienzaDesdeAdentro = rawCollection['comienzaDesdeAdentro'] ?? true; // <-- AÑADÍ ESTA LÍNEA
    final List<Map<String, String>> dataPoints = List<Map<String, String>>.from(
      rawDataPoints,
    );
    if (jumpType == null || dataPoints.isEmpty) return [];

    // FASE 1: Convertir datos crudos en una lista de eventos claros.
    final List<JumpEvent> eventos = _convertDataToEvents(dataPoints);
    debugPrint('[JumpCalculator] Eventos detectados: $eventos');

    // FASE 2: Aplicar la lógica de cálculo según el patrón de eventos y el tipo de salto.
    switch (jumpType) {
      case 'SJ':
        return _calculateSJ(eventos);
case 'SJl':
        return _calculateSJ(eventos);
case 'CMJ':
        return _calculateSJ(eventos);
case 'ABK':
        return _calculateSJ(eventos);
      case 'SS_EX':
        return _calculateSS_EX(eventos);
      case 'DJ_IN':
        return _calculateDJ_IN(eventos);
      case 'DJ_EX':
        return _calculateDJ_EX(eventos);
      case 'MULTI': // <-- CASO AÑADIDO
        return _calculateMulti(eventos, comienzaDesdeAdentro: comienzaDesdeAdentro); // <-- MODIFICÁ ESTA LÍNEA
      default:
        debugPrint(
          '[JumpCalculator] No hay lógica de cálculo para el tipo: $jumpType',
        );
        return [];
    }
  }

  // ----- FASE 1: Conversor de Datos a Eventos -----
  List<JumpEvent> _convertDataToEvents(List<Map<String, String>> dataPoints) {
    final List<JumpEvent> eventos = [];

    // Recorremos cada punto de dato individualmente
    for (var point in dataPoints) {
      try {
        final String estado = point['estado'] ?? '';
        final double timestamp = double.parse(point['tiempo'] ?? '0.0');

        // Cada trama es un evento en sí misma:
        // estado '1' es Despegue (fuera de la alfombra)
        // estado '0' es Aterrizaje (en la alfombra)
        if (estado == '1') {
          eventos.add(
            JumpEvent(type: EventType.Despegue, timestamp_ms: timestamp),
          );
        } else if (estado == '0') {
          eventos.add(
            JumpEvent(type: EventType.Aterrizaje, timestamp_ms: timestamp),
          );
        }
      } catch (e) {
        debugPrint('[JumpCalculator] Error parseando punto de dato: $e');
      }
    }
    return eventos;
  }

  // ----- FASE 2: Métodos de Cálculo por Tipo de Salto -----

  List<JumpData> _calculateSJ(List<JumpEvent> eventos) {
    // Patrón esperado: [Despegue, Aterrizaje]
    if (eventos.length >= 2 &&
        eventos[0].type == EventType.Despegue &&
        eventos[1].type == EventType.Aterrizaje) {
      final double flightTime_us =
          eventos[1].timestamp_ms - eventos[0].timestamp_ms;
      final double height = _calculateHeight(flightTime_us);

      final jump = JumpData(
        height: height,
        flightTime: flightTime_us / 1000,
        contactTime: 0,
        fallTime: 0,
        timestamp: DateTime.now(),
      );
      return [jump];
    }
    return [];
  }

  List<JumpData> _calculateSS_EX(List<JumpEvent> eventos) {
    // Patrón esperado para Salto Simple desde Fuera: [Aterrizaje, Despegue, Aterrizaje]
    if (eventos.length >= 3 &&
        eventos[0].type == EventType.Aterrizaje &&
        eventos[1].type == EventType.Despegue &&
        eventos[2].type == EventType.Aterrizaje) {
      final double contactTime_us =
          eventos[1].timestamp_ms - eventos[0].timestamp_ms;
      final double flightTime_us =
          eventos[2].timestamp_ms - eventos[1].timestamp_ms;
      final double height = _calculateHeight(flightTime_us);

      final jump = JumpData(
        height: height,
        flightTime: flightTime_us / 1000,
        contactTime: contactTime_us / 1000,
        fallTime: 0,
        timestamp: DateTime.now(),
      );
      return [jump];
    }
    return [];
  }

  List<JumpData> _calculateDJ_IN(List<JumpEvent> eventos) {
    // Patrón esperado: [Despegue, Aterrizaje, Despegue, Aterrizaje]
    if (eventos.length >= 4) {
      final double flightTime1_us =
          eventos[1].timestamp_ms - eventos[0].timestamp_ms;
      final double height1 = _calculateHeight(flightTime1_us);
      final jump1 = JumpData(
        height: height1,
        flightTime: flightTime1_us / 1000,
        contactTime: -1,
        fallTime: 0,
        timestamp: DateTime.now(),
      );

      final double contactTime_us =
          eventos[2].timestamp_ms - eventos[1].timestamp_ms;
      final double flightTime2_us =
          eventos[3].timestamp_ms - eventos[2].timestamp_ms;
      final double height2 = _calculateHeight(flightTime2_us);
      // La ALTURA de caída del 2do salto se calcula con el tiempo de vuelo del 1ro.
      final double alturaCaida_cm = _calculateHeight(flightTime1_us);
      final jump2 = JumpData(
        height: height2,
        flightTime: flightTime2_us / 1000,
        contactTime: contactTime_us / 1000,
        fallTime: alturaCaida_cm, // <-- Guarda la altura en cm
        timestamp: DateTime.now(),
      );

      return [jump1, jump2];
    }
    return [];
  }

  // --- MÉTODO PARA SALTO MÚLTIPLE (A DESARROLLAR) ---
 // En: jump_calculator.dart
// Dentro de la clase JumpCalculator

// --- MÉTODO PARA SALTO MÚLTIPLE (DESARROLLADO) ---
// En: jump_calculator.dart
// Dentro de la clase JumpCalculator

// --- MÉTODO PARA SALTO MÚLTIPLE (DESARROLLADO) ---
// Reemplazá la función _calculateMulti completa con esta:

// Reemplazá la función _calculateMulti completa con esta:

List<JumpData> _calculateMulti(List<JumpEvent> eventos, {required bool comienzaDesdeAdentro}) {
    final List<JumpData> saltosResultantes = [];

    // --- Bucle principal unificado para buscar saltos medibles (Despegue -> Aterrizaje) ---
    // Ya no forzamos un vuelo 0.0. El bucle empareja todo de forma natural.
    for (int i = 0; i < eventos.length - 1; i++) {
      if (eventos[i].type == EventType.Despegue && eventos[i + 1].type == EventType.Aterrizaje) {
        final despegue = eventos[i];
        final aterrizaje = eventos[i + 1];

        // 1. Tiempo de Vuelo y Altura
        final double flightTime_us = aterrizaje.timestamp_ms - despegue.timestamp_ms;
        final double height = _calculateHeight(flightTime_us);

        // 2. Tiempo de Contacto
        double contactTime_us = 0;
        // Si hay un aterrizaje previo, calculamos el contacto real. 
        // Si no lo hay (porque empezó adentro), el contacto queda en 0.
        if (i > 0 && eventos[i - 1].type == EventType.Aterrizaje) {
          final aterrizajeAnterior = eventos[i - 1];
          contactTime_us = despegue.timestamp_ms - aterrizajeAnterior.timestamp_ms;
        }

        // 3. Altura de Caída
        double alturaCaida_cm = 0;
        if (saltosResultantes.isNotEmpty) {
          final double prevFlightTime_us = saltosResultantes.last.flightTime * 1000;
          alturaCaida_cm = _calculateHeight(prevFlightTime_us);
        }

        final jump = JumpData(
          height: height,
          flightTime: flightTime_us / 1000,
          contactTime: contactTime_us / 1000,
          fallTime: alturaCaida_cm,
          timestamp: DateTime.now(),
        );
        saltosResultantes.add(jump);
      }
    }
    
    debugPrint('[JumpCalculator] >>> Proceso MULTI finalizado. Se encontraron ${saltosResultantes.length} registros reales.');
    return saltosResultantes;
  }List<JumpData> _calculateDJ_EX(List<JumpEvent> eventos) {
    // Patrón esperado: [Aterrizaje, Despegue, Aterrizaje]
    if (eventos.length >= 3 &&
        eventos[0].type == EventType.Aterrizaje &&
        eventos[1].type == EventType.Despegue &&
        eventos[2].type == EventType.Aterrizaje) {
      final double contactTime_us =
          eventos[1].timestamp_ms - eventos[0].timestamp_ms;
      final double flightTime_us =
          eventos[2].timestamp_ms - eventos[1].timestamp_ms;
      final double height = _calculateHeight(flightTime_us);

      // Para DJ_EX, el 'fallTime' no se puede medir solo con la alfombra. Se deja en 0.
      final jump = JumpData(
        height: height,
        flightTime: flightTime_us / 1000,
        contactTime: contactTime_us / 1000,
        fallTime: 0,
        timestamp: DateTime.now(),
      );
      return [jump];
    }
    return [];
  }

  // ----- MÉTODO HELPER DE CÁLCULO -----
double _calculateHeight(double flightTime_ms) { // Renombramos para mayor claridad
  if (flightTime_ms <= 0) return 0.0;
  // Convertimos de microsegundos a segundos dividiendo por 1000
  final double flightTime_s = flightTime_ms / 1000000.0; // <-- DIVISOR CORREGIDO
  return (gravity * pow(flightTime_s, 2)) / 8 * 100;
}}

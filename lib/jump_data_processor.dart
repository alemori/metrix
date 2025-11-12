// ARCHIVO CORREGIDO Y COMPLETO: jump_data_processor.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'ble_repository.dart';
import 'dart:convert';
import 'jump_calculator.dart';
import 'bluetooth_provider.dart';

// La clase JumpData no tiene cambios
class JumpData {
  final double height;
  final double flightTime;
  final double contactTime;
  final double? fallTime;
  final DateTime timestamp;

  JumpData({
    required this.height,
    required this.flightTime,
    required this.contactTime,
    this.fallTime,
    required this.timestamp,
  });

  factory JumpData.fromBleMessage(String message) {
    final parts = message.split(';');
    if (parts.length < 4) {
      throw FormatException(
        'Mensaje de salto malformado o incompleto: $message',
      );
    }
    final height = double.tryParse(parts[1].trim()) ?? 0.0;
    final flightTime = double.tryParse(parts[2].trim()) ?? 0.0;
    final contactTime = double.tryParse(parts[3].trim()) ?? 0.0;
    double? fallTime;
    if (parts.length >= 5) {
      fallTime = double.tryParse(parts[4].trim()) ?? 0.0;
    }
    return JumpData(
      height: height,
      flightTime: flightTime,
      contactTime: contactTime,
      fallTime: fallTime,
      timestamp: DateTime.now(),
    );
  }
}

enum CollectionState { Idle, FixedCycles, OpenEnded }

// Variables para la nueva lógica de estado
CollectionState _collectionState = CollectionState.Idle;
int _expectedCycles = 0;
String? _currentJumpType;

class BleMessageProcessor {
  final BleRepository _bleRepository;
  final BluetoothProvider _bluetoothProvider; // <-- AÑADIDO
  int _configuredLimiteSaltos = 0; // Para guardar el límite de la prueba MULTI
  Timer? _watchdogTimer;
  StreamSubscription<String>? _bleMessageSubscription;
  final JumpCalculator _jumpCalculator = JumpCalculator();

  final _pinStateController = StreamController<int>.broadcast();
  final _jumpDataController = StreamController<JumpData>.broadcast();
  final _seriesEndController = StreamController<bool>.broadcast();
  final _deviceResetController = StreamController<bool>.broadcast();
  final _unrecognizedMessageController = StreamController<String>.broadcast();

  static const Map<String, int> _jumpCyclesMap = {
    'SJ': 2,
    'SJl': 2,
    'CMJ': 2,
    'ABK': 2,
    'SS_EX': 4,
    'DJ_IN': 5,
    'DJ_EX': 4,
  };
  // --- AÑADIR ESTAS LÍNEAS ---
  int _configuredLimiteTiempo = 0;
  bool _comienzaDesdeAdentro = true;
  double? _timestampInicioSerie;
  double? _timestampUltimoAterrizaje;
  double? _timestampUltimoDespegue;
  // Constantes para el timeout por inactividad
  static const double tiempoPromedioEstimado_us = 75000;
  static const double multiplicadorTimeout = 3.0;
  // ---------------------------
  bool _isDataCollectionMode = false;
  String? _collectionJumpType;
  // int _expectedCycles = 0; // Ya estaba declarada arriba
  int _receivedCycles = 0;
  final List<Map<String, String>> _collectedData = [];

  Stream<int> get pinStateStream => _pinStateController.stream;
  Stream<JumpData> get jumpDataStream => _jumpDataController.stream;
  Stream<bool> get seriesEndStream => _seriesEndController.stream;
  Stream<bool> get deviceResetStream => _deviceResetController.stream;
  Stream<String> get unrecognizedMessageStream =>
      _unrecognizedMessageController.stream;

  BleMessageProcessor(this._bleRepository, this._bluetoothProvider) {
    // <-- AÑADIDO
    _initListener();
  }

void _initListener() {
    _bleMessageSubscription = _bleRepository.bleMessageStream.listen(
      (message) {
        final cleanMessage = message.replaceAll('"', '').trim();

        // ¡ELIMINAMOS EL WATCHDOG GENERAL DE AQUÍ!

        final parts = cleanMessage.split(';');
        if (parts.length == 2 && int.tryParse(parts[0].trim()) != null) {
          final int pinState = int.parse(parts[0].trim());

          final double timestampActual_us = double.parse(parts[1].trim());

          _pinStateController.add(pinState);
          _bluetoothProvider.updatePinState(pinState);

          if (_isDataCollectionMode) {
            
            // --- INICIO DE LA SOLUCIÓN (WATCHDOG INTELIGENTE) ---
            _watchdogTimer?.cancel(); // 1. Cancelamos el timer anterior CADA VEZ que llega un dato.

            if (pinState == 0) { 
              // 2. Si está EN LA ALFOMBRA (Estado 0), reiniciamos el watchdog.
              //    Si deja de enviar datos por 2s (estando en la alfombra), es un error.
              _watchdogTimer = Timer(const Duration(seconds: 2), () {
                debugPrint(
                  'WATCHDOG TIMEOUT: No se recibieron datos (estando en la alfombra). Finalizando prueba.',
                );
                _completeDataCollection();
              });
            } 
            // 3. Si el pinState es 1 (en el aire), NO reiniciamos el timer.
            //    Es normal no recibir datos en el aire. El timer queda cancelado.
            // --- FIN DE LA SOLUCIÓN ---


            _timestampInicioSerie ??= timestampActual_us;

            if (_configuredLimiteTiempo > 0) {
              final double tiempoTranscurrido_us =
                  timestampActual_us - _timestampInicioSerie!;
              final double limiteTiempo_us =
                  _configuredLimiteTiempo * 1000000.0;
              if (tiempoTranscurrido_us >= limiteTiempo_us) {
                debugPrint('LÍMITE DE TIEMPO ALCANZADO.');
                _completeDataCollection();
                return;
              }
            }

            if (_expectedCycles == 0 && _configuredLimiteTiempo == 0) {
              if (pinState == 0) {
                _timestampUltimoAterrizaje ??= timestampActual_us;
                _timestampUltimoDespegue = null;
                final double tiempoQuieto_us =
                    timestampActual_us - _timestampUltimoAterrizaje!;
                if (tiempoQuieto_us >
                    (tiempoPromedioEstimado_us * multiplicadorTimeout)) {
                  debugPrint('TIMEOUT: Atleta quieto en la alfombra.');
                  _completeDataCollection();
                  return;
                }
              } else {
                _timestampUltimoDespegue ??= timestampActual_us;
                _timestampUltimoAterrizaje = null;
                final double tiempoEnAire_us =
                    timestampActual_us - _timestampUltimoDespegue!;
                if (tiempoEnAire_us > 2000000) {
                  debugPrint('FIN DE SERIE: Atleta abandonó la alfombra.');
                  _completeDataCollection();
                  return;
                }
              }
            }
            _handleCollectionData(cleanMessage);
          }
        } else {
          if (cleanMessage.startsWith('boton,') &&
              cleanMessage.endsWith(',14')) {
            _deviceResetController.add(true);
          } else {
            if (!_isDataCollectionMode) {
              _unrecognizedMessageController.add(cleanMessage);
            }
          }
        }
      },
      onError: (error) {
        debugPrint('[Processor] ERROR en stream: $error');
      },
      onDone: () {
        debugPrint('[Processor] Stream cerrado.');
        dispose();
      },
    );
  }
  void iniciarRecoleccionManual(String jumpType) {
    _timestampInicioSerie = null;
    if (_isDataCollectionMode) {
      _resetCollectionMode(
        reason: 'Inicio manual forzado mientras ya estaba activo.',
      );
    }

    if (jumpType == 'MULTI') {
      _expectedCycles = _configuredLimiteSaltos * 2;
      _isDataCollectionMode = true;
      _collectionJumpType = jumpType;
      _receivedCycles = 0;
      _collectedData.clear();

      debugPrint(
        '[Processor] MODO RECOLECCIÓN (MULTI) activado. Esperando $_expectedCycles ciclos (0 = sin límite).',
      );

      _watchdogTimer?.cancel();
      _watchdogTimer = Timer(const Duration(seconds: 2), () {
        debugPrint(
          'WATCHDOG TIMEOUT: No se recibieron datos en 2s tras iniciar.',
        );
        _completeDataCollection();
      });
    } else if (_jumpCyclesMap.containsKey(jumpType)) {
      final cycles = _jumpCyclesMap[jumpType]!;
      _isDataCollectionMode = true;
      _collectionJumpType = jumpType;
      _expectedCycles = cycles;
      _receivedCycles = 0;
      _collectedData.clear();

      debugPrint(
        '[Processor] MODO RECOLECCIÓN (Simple) activado para $jumpType, esperando $cycles ciclos.',
      );
    } else {
      debugPrint(
        '[Processor] ADVERTENCIA: Se intentó iniciar recolección para un tipo de salto no configurado: $jumpType',
      );
    }
  }

  void configurarNuevaPrueba({
    required String jumpType,
    int limiteSaltos = 0,
    int limiteTiempo = 0,
    bool comienzaDesdeAdentro = true,
  }) {
    debugPrint('--- [Processor] Se llamó a configurarNuevaPrueba ---');
    debugPrint('Tipo de Salto recibido: $jumpType');
    debugPrint('Límite de Saltos recibido: $limiteSaltos');
    debugPrint('Límite de Tiempo recibido: $limiteTiempo');
    debugPrint('Comienza Desde Adentro recibido: $comienzaDesdeAdentro');
    debugPrint('----------------------------------------------------');
    _configuredLimiteSaltos = limiteSaltos;
    _configuredLimiteTiempo = limiteTiempo;
    _comienzaDesdeAdentro = comienzaDesdeAdentro; // <-- AÑADÍ ESTA LÍNEA
  }

  void _startDataCollection(String message) {
    debugPrint('[startDataCollection] $message');
    final parts = message.split(',');
    debugPrint('[final] $parts');

    if (parts.length == 2) {
      final jumpType = parts[1].trim();
      debugPrint('[jumpType] $jumpType');

      if (jumpType == 'MULTI') {
        _isDataCollectionMode = true;
        _collectionJumpType = jumpType;
        _expectedCycles = _configuredLimiteSaltos * 2;
        _receivedCycles = 0;
        debugPrint(
          '[Processor] Modo recolección MULTI activado, esperando $_configuredLimiteSaltos saltos.',
        );
      } else {
        if (_jumpCyclesMap.containsKey(jumpType)) {
          final cycles = _jumpCyclesMap[jumpType]!;
          _isDataCollectionMode = true;
          _collectionJumpType = jumpType;
          _expectedCycles = cycles;
          _receivedCycles = 0;
          _collectedData.clear();
          debugPrint(
            '[Processor] Modo recolección activado para $jumpType, esperando $cycles ciclos.',
          );
        }
      }
    }
  }

  void _handleCollectionData(String message) {
    final parts = message.split(';');
    if (parts.length == 2) {
      final state = parts[0].trim();
      final time = parts[1].trim();
      _collectedData.add({'estado': state, 'tiempo': time});
      _receivedCycles++;
      if (_expectedCycles > 0 && _receivedCycles >= _expectedCycles) {
        _completeDataCollection();
      }
    }
  }

  Future<void> _completeDataCollection() async {
    if (!_isDataCollectionMode) return;

    debugPrint(
      '[Processor] Recolección completada. Pasando datos al calculador...',
    );
    _watchdogTimer?.cancel();

    // --- INICIO DE LA SOLUCIÓN (ORDENAR EVENTOS) ---
    // Copiamos los datos recolectados
    final List<Map<String, String>> datosRecolectados = List.from(_collectedData);

    // Ordenamos la lista basándonos en el 'tiempo' (timestamp)
    // Convertimos el String 'tiempo' a double para una comparación numérica correcta.
    try {
      datosRecolectados.sort((a, b) {
        final double tiempoA = double.parse(a['tiempo']!);
        final double tiempoB = double.parse(b['tiempo']!);
        return tiempoA.compareTo(tiempoB);
      });
    } catch (e) {
      debugPrint('[Processor] ERROR: No se pudieron ordenar los datos. $e');
      // Continuar con los datos sin ordenar si falla el parseo
    }
    
    // Creamos el objeto para el calculador con la lista YA ORDENADA
    final collectionForCalculator = {
      'jumpType': _collectionJumpType,
      'data': datosRecolectados, // <-- Usamos la lista ordenada
      'comienzaDesdeAdentro': _comienzaDesdeAdentro,
    };
    // --- FIN DE LA SOLUCIÓN ---

    final List<JumpData> results = _jumpCalculator.calculateJumpFromRawData(
      collectionForCalculator,
    );

    if (results.isNotEmpty) {
      debugPrint(
        '[Processor] ¡Cálculo exitoso! Se obtuvieron ${results.length} resultados de salto.',
      );
      for (final jump in results) {
        _jumpDataController.add(jump);
      }
    } else {
      debugPrint('[Processor] El calculador no devolvió resultados.');
    }

    _resetCollectionMode(reason: 'Recolección completada');
    _seriesEndController.add(
      true,
    ); // <-- CAMBIO: Notificar a la UI que la sesión ha terminado.

    try {
      //  final command = '27,FIN';
      //  await _bleRepository.writeData(utf8.encode(command));
    } catch (e) {
      debugPrint('[Processor] Error al enviar el comando "27,FIN": $e');
    }
  }

  void _resetCollectionMode({required String reason}) {
    debugPrint('[Processor] Reseteando estado interno. Razón: $reason');
    _watchdogTimer?.cancel();
    _isDataCollectionMode = false;
    _collectionJumpType = null;
    _expectedCycles = 0;
    _receivedCycles = 0;
    _collectedData.clear();
  }

  void dispose() {
    _bleMessageSubscription?.cancel();
    _pinStateController.close();
    _jumpDataController.close();
    _seriesEndController.close();
    _deviceResetController.close();
    _unrecognizedMessageController.close();
  }
}

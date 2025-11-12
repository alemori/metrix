// ARCHIVO: ble_salto_multiple.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart'; // Importar provider

import 'ble_repository.dart'; // Necesario para la conexión BLE y enviar comandos
import 'jump_data_processor.dart'; // ¡NUEVA IMPORTACIÓN! Usaremos el JumpData y los streams de aquí.

// NOTA: La clase JumpData se ha movido a jump_data_processor.dart
// Elimina la definición de JumpData de este archivo si la tienes aquí.

// --- CLASE BleSaltoMultipleScreen (Widget principal de la pantalla de saltos múltiples) ---
class BleSaltoMultipleScreen extends StatefulWidget {
  final String jumpType; // Cadena completa de parámetros (ej: "MULTI_5_0_true_0.0_true")
  final int? limiteSaltos;
  final int? limiteTiempo;
  final bool comienzaDesdeAdentro;
  final double? pesoExtra;
  final bool ultimoSaltoCompleto;

  const BleSaltoMultipleScreen({
    super.key,
    required this.jumpType,
    this.limiteSaltos,
    this.limiteTiempo,
    required this.comienzaDesdeAdentro,
    this.pesoExtra,
    required this.ultimoSaltoCompleto,
  });

  @override
  State<BleSaltoMultipleScreen> createState() => _BleSaltoMultipleScreenState();
}

class _BleSaltoMultipleScreenState extends State<BleSaltoMultipleScreen>
    with SingleTickerProviderStateMixin {
  // Ahora obtendremos el BleRepository y el JumpDataProcessor del Provider
  late final BleRepository _bleRepo;
  late final BleMessageProcessor _messageProcessor;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Suscripciones a los streams del BleMessageProcessor
  StreamSubscription<int>? _pinStateSubscription;
  StreamSubscription<JumpData>? _jumpDataSubscription;
  StreamSubscription<bool>? _seriesEndSubscription;
  StreamSubscription<bool>? _deviceResetSubscription;
  StreamSubscription<String>? _unrecognizedMessageSubscription;

  int _lastPinState = -1; // -1: desconocido, 0: en alfombra, 1: fuera de alfombra
  bool _isSendingCommand = false; // Indica si se está enviando un comando BLE
  bool _isJumpInProgress = false; // Indica si una SERIE de saltos está en curso
  bool _isRecording = false; // Indica si se está grabando el historial en CSV
  late AnimationController _animationController;
  List<JumpData> _jumpHistory = []; // Historial de saltos individuales
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Obtener las instancias de BleRepository y BleMessageProcessor del Provider
    _bleRepo = Provider.of<BleRepository>(context, listen: false);
    _messageProcessor = Provider.of<BleMessageProcessor>(context, listen: false);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _setupBluetoothListeners(); // Cambiamos el nombre del método de escucha
    _sendInitialCommand(); // Enviar el comando 69MULTI_... al iniciar

    debugPrint('--- Parámetros recibidos en BleSaltoMultipleScreen ---');
    debugPrint('jumpType: ${widget.jumpType}');
    debugPrint('limiteSaltos: ${widget.limiteSaltos}');
    debugPrint('limiteTiempo: ${widget.limiteTiempo}');
    debugPrint('comienzaDesdeAdentro: ${widget.comienzaDesdeAdentro}');
    debugPrint('pesoExtra: ${widget.pesoExtra}');
    debugPrint('ultimoSaltoCompleto: ${widget.ultimoSaltoCompleto}');
    debugPrint('----------------------------------------------------');
  }

  // Ahora unificamos el método para configurar los listeners de Bluetooth
  void _setupBluetoothListeners() {
    // Escucha el estado del pin
    _pinStateSubscription = _messageProcessor.pinStateStream.listen((pinState) {
      debugPrint('[APP] Pin State (Multi) recibido: $pinState');
      final previousPinState = _lastPinState;
      if (mounted) {
        setState(() {
          _lastPinState = pinState;
        });
      }
      _controlAnimation();

      // Lógica para sonidos de posicionamiento antes de iniciar la serie
      if (!_isJumpInProgress) {
        if (widget.comienzaDesdeAdentro) {
          if (pinState == 0 && previousPinState != 0) _playSound('start.wav');
          else if (pinState == 1 && previousPinState != 1) _playSound('bad.wav');
        } else { // Si comienza desde afuera
          if (pinState == 1 && previousPinState != 1) _playSound('start.wav');
          else if (pinState == 0 && previousPinState != 0) _playSound('bad.wav');
        }
      }

      // Lógica para detectar el fin de serie por estado del pin
      // Si la serie está en curso y el pin pasa a 1 (fuera de alfombra)
      if (_isJumpInProgress && pinState == 1) {
        debugPrint('[APP] Detectado posible fin de serie (Multi): _isJumpInProgress es true y pinState es 1.');
        _resetToInitialStateForNewCycle();
        _playSound('end.wav');
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Serie de saltos finalizada por detección de salida de alfombra!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }, onError: (e) {
      debugPrint('[APP] Error en pinStateStream (Multi): $e');
    });

    // Escucha los datos de salto procesados
    _jumpDataSubscription = _messageProcessor.jumpDataStream.listen((newJump) {
      debugPrint('[APP] JumpData (Multi) recibido: ${newJump.height} cm');
      if (mounted) {
        setState(() {
          _jumpHistory.insert(0, newJump); // Añadir al principio de la lista
          _isJumpInProgress = true; // La serie sigue en curso
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Salto #${_jumpHistory.length} registrado! Altura: ${newJump.height.toStringAsFixed(2)} cm (Valor Caída: ${newJump.fallTime?.toStringAsFixed(2) ?? 'N/A'})'),
              duration: const Duration(milliseconds: 300),
            ),
          );
        });
        _playSound('start.wav'); // Sonido de salto exitoso

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }, onError: (e) {
      debugPrint('[APP] Error en jumpDataStream (Multi): $e');
      if (mounted) {
        setState(() {
          _isJumpInProgress = false;
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar datos de salto: $e')),
        );
      }
    });

    // Escucha el evento de fin de serie (explícito del ESP32)
    _seriesEndSubscription = _messageProcessor.seriesEndStream.listen((_) {
      debugPrint('[APP] Mensaje "SERIE_FINALIZADA" recibido.');
      _resetToInitialStateForNewCycle();
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Serie de saltos finalizada!'),
            duration: Duration(seconds: 2),
          ),
        );
        _playSound('end.wav');
      }
    }, onError: (e) {
      debugPrint('[APP] Error en seriesEndStream: $e');
    });

    // Escucha el evento de reinicio del dispositivo
    _deviceResetSubscription = _messageProcessor.deviceResetStream.listen((_) {
      debugPrint('[APP] Dispositivo BLE reiniciado (boton,14).');
      _resetToInitialStateForNewCycle();
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ciclo de salto reiniciado por el dispositivo.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }, onError: (e) {
      debugPrint('[APP] Error en deviceResetStream (Multi): $e');
    });

    // Escucha mensajes no reconocidos (opcional, para depuración o feedback al usuario)
    _unrecognizedMessageSubscription = _messageProcessor.unrecognizedMessageStream.listen((message) {
      debugPrint('[APP] Mensaje no reconocido del BLE (Multi): "$message"');
    }, onError: (e) {
      debugPrint('[APP] Error en unrecognizedMessageStream (Multi): $e');
    });
  }

  // --- Métodos de Sonido y Animación ---
  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      debugPrint('Sonido $soundFile reproducido correctamente');
    } catch (e) {
      debugPrint('Error al reproducir sonido $soundFile: $e');
      HapticFeedback.heavyImpact(); // Vibración si falla el sonido
    }
  }

  void _controlAnimation() {
    if (_isJumpInProgress) {
      _animationController.duration = const Duration(milliseconds: 700);
      if (!_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
      }
    } else {
      if (widget.comienzaDesdeAdentro) {
        if (_lastPinState == 0) {
          _animationController.duration = const Duration(milliseconds: 700);
          if (!_animationController.isAnimating) {
            _animationController.repeat(reverse: true);
          }
        } else {
          _animationController.duration = const Duration(milliseconds: 1000);
          if (_animationController.isAnimating) {
            _animationController.reset();
          }
        }
      } else {
        if (_lastPinState == 1 || _lastPinState == -1) {
          _animationController.duration = const Duration(milliseconds: 700);
          if (!_animationController.isAnimating) {
            _animationController.repeat(reverse: true);
          }
        } else {
          _animationController.duration = const Duration(milliseconds: 1000);
          if (_animationController.isAnimating) {
            _animationController.reset();
          }
        }
      }
    }
  }

  // --- Métodos de Estado y Comandos BLE ---
  Future<void> _sendInitialCommand() async {
    if (!_bleRepo.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay un dispositivo BLE conectado. Conéctese primero.')),
        );
      }
      return;
    }
    if (_bleRepo.writeCharacteristics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron características de escritura en el dispositivo.')),
        );
      }
      return;
    }

    try {
      final characteristic = _bleRepo.writeCharacteristics.first;
      final command = '69${widget.jumpType}';
      await characteristic.write(utf8.encode(command));
      debugPrint('[BLE] Comando inicial "MULTI" enviado: $command');

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo Saltos Múltiples activado. Por favor, colóquese en la alfombra.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('[BLE] Error enviando comando inicial "MULTI": $e');
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de configuración al enviar el comando inicial: $e')),
        );
      }
    }
  }

  void _resetToInitialStateForNewCycle() {
    debugPrint('[APP] Reiniciando estado para nuevo ciclo (Multi).');
    if (mounted) {
      setState(() {
        _isSendingCommand = false;
        _isJumpInProgress = false;
        _lastPinState = -1;
        _animationController.reset();
        _jumpHistory.clear(); // Limpiar historial para nueva serie
      });
      _sendInitialCommand();
    }
  }

  Future<void> _sendStartSeriesCommand() async {
    if (!_bleRepo.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay conexión BLE activa.')),
        );
      }
      return;
    }
    if (_bleRepo.writeCharacteristics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron características de escritura.')),
        );
      }
      return;
    }

    String feedbackMessage = '';
    String soundToPlay = '';
    bool canSendBluetoothCommand = false;

    if (widget.comienzaDesdeAdentro) {
      if (_lastPinState == 0) {
        canSendBluetoothCommand = true;
        feedbackMessage = 'Listo para iniciar. Esperando despegue...';
        soundToPlay = 'start.wav';
      } else {
        canSendBluetoothCommand = false;
        feedbackMessage = 'DEBE ESTAR EN LA ALFOMBRA PARA INICIAR.';
        soundToPlay = 'bad.wav';
      }
    } else {
      if (_lastPinState == 1 || _lastPinState == -1) {
        canSendBluetoothCommand = true;
        feedbackMessage = 'Listo para iniciar. Esperando contacto inicial.';
        soundToPlay = 'start.wav';
      } else {
        canSendBluetoothCommand = false;
        feedbackMessage = 'DEBE INICIAR FUERA DE LA ALFOMBRA.';
        soundToPlay = 'bad.wav';
      }
    }

    if (!canSendBluetoothCommand) {
      await _playSound(soundToPlay);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage, style: const TextStyle(fontSize: 16)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSendingCommand = true;
        _isJumpInProgress = false;
      });
    }

    try {
      final characteristic = _bleRepo.writeCharacteristics.first;
      final command = '99${widget.jumpType}';
      await characteristic.write(utf8.encode(command));
      debugPrint('[BLE] Comando de inicio de serie enviado: $command');

      await _playSound(soundToPlay);
      if (mounted) {
        setState(() {
          _isJumpInProgress = true;
        });
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage, style: const TextStyle(fontSize: 16)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al enviar comando de inicio de serie: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el comando de inicio de serie: $e')),
        );
      }
      if (mounted) {
        setState(() {
          _isJumpInProgress = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingCommand = false);
      }
    }
  }

  @override
  void dispose() {
    // Cancelar todas las suscripciones al procesador
    _pinStateSubscription?.cancel();
    _jumpDataSubscription?.cancel();
    _seriesEndSubscription?.cancel();
    _deviceResetSubscription?.cancel();
    _unrecognizedMessageSubscription?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Métodos de Grabación y Limpieza de Historial ---
  void _toggleRecording() async {
    if (_isRecording) {
      try {
        await _saveDataToFile();
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Datos guardados correctamente en un archivo CSV.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar los datos: $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => !_isRecording); // Corregido: setState para cambiar el estado de _isRecording
    }
  }

  void _clearJumpHistory() {
    if (mounted) {
      setState(() => _jumpHistory.clear());
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial de saltos borrado.')),
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    return File('$path/saltos_${widget.jumpType.split('_')[0]}_${dateFormat.format(DateTime.now())}.csv');
  }

  Future<void> _saveDataToFile() async {
    if (_jumpHistory.isEmpty) {
      debugPrint('No hay datos de salto para guardar.');
      return;
    }
    try {
      final file = await _localFile;
      // Encabezado del CSV con "Caída (valor)" y "Altura (cm)" invertidos
      String csvContent = 'N° Salto,Tipo Salto,Tiempo Vuelo (ms),Tiempo Contacto (ms),Caída (valor),Altura (cm),Fecha y Hora\n';

      for (int i = _jumpHistory.length - 1; i >= 0; i--) {
        final jump = _jumpHistory[i];
        // Exporta valores numéricos con dos decimales para Caída y Altura invertidos
        csvContent += '${_jumpHistory.length - i},${widget.jumpType},${jump.flightTime.toStringAsFixed(2)},${jump.contactTime.toStringAsFixed(2)},${jump.fallTime?.toStringAsFixed(2) ?? ''},${jump.height.toStringAsFixed(2)},${DateFormat('yyyy-MM-dd HH:mm:ss').format(jump.timestamp)}\n';
      }

      await file.writeAsString(csvContent);
      debugPrint('Datos guardados en: ${file.path}');
    } catch (e) {
      debugPrint('Error al guardar archivo: $e');
      throw Exception('No se pudo guardar el archivo: $e');
    }
  }

  void _removeJump(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Salto'),
        content: const Text('¿Estás seguro de que quieres eliminar este salto del historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _jumpHistory.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salto eliminado del historial.')),
        );
      }
    }
  }

  // --- Widgets de Interfaz de Usuario ---
  Widget _buildStatusMessage() {
    TextStyle messageStyle = const TextStyle(fontWeight: FontWeight.bold);
    if (_isJumpInProgress) {
      return Text(
        '¡SERIE DE SALTOS EN CURSO!',
        style: messageStyle.copyWith(fontSize: 18, color: Colors.orange),
        textAlign: TextAlign.center,
      );
    } else {
      if (widget.comienzaDesdeAdentro) {
        switch (_lastPinState) {
          case -1:
            return Text(
              'Esperando alfombra. Colóquese en ella.',
              style: messageStyle.copyWith(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            );
          case 0:
            return Text(
              '¡LISTO PARA SALTAR! En la alfombra.',
              style: messageStyle.copyWith(fontSize: 16, color: Colors.green),
              textAlign: TextAlign.center,
            );
          case 1:
            return Text(
              'DEBE ESTAR EN LA ALFOMBRA PARA INICIAR.',
              style: messageStyle.copyWith(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            );
          default:
            return Text(
              'Sensor desconocido: $_lastPinState',
              style: messageStyle.copyWith(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            );
        }
      } else { // Si la serie comienza desde afuera
        switch (_lastPinState) {
          case -1:
          case 1:
            return Text(
              '¡LISTO PARA SALTAR! Fuera de la alfombra.',
              style: messageStyle.copyWith(fontSize: 16, color: Colors.green),
              textAlign: TextAlign.center,
            );
          case 0:
            return Text(
              'DEBE ESTAR FUERA DE LA ALFOMBRA PARA INICIAR.',
              style: messageStyle.copyWith(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            );
          default:
            return Text(
              'Sensor desconocido: $_lastPinState',
              style: messageStyle.copyWith(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            );
        }
      }
    }
  }

  Widget _buildJumpHistoryList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial (${_jumpHistory.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.fiber_manual_record,
                      color: _isRecording ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: _toggleRecording,
                    tooltip: _isRecording ? 'Detener grabación' : 'Grabar datos',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    onPressed: _clearJumpHistory,
                    tooltip: 'Limpiar historial',
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    SizedBox(
                        width: 40,
                        child: Center(child: Text('N°', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                    SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            'TC\n(ms)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )),
                    SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            'TV\n(ms)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )),
                    SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            'Caída',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )),
                    SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            'Altura\n(cm)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )),
                    SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _jumpHistory.isEmpty
              ? const Center(
                  child: Text(
                    'Sin saltos registrados aún.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: _jumpHistory.length,
                  itemBuilder: (context, index) {
                    final jump = _jumpHistory[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: IntrinsicWidth(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: Text(
                                      '${_jumpHistory.length - index}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Center(
                                    child: Text(
                                      jump.contactTime.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Center(
                                    child: Text(
                                      jump.flightTime.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Center(
                                    child: Text(
                                      jump.fallTime?.toStringAsFixed(2) ?? '', // Mostrar 'N/A' o vacío si es nulo
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Center(
                                    child: Text(
                                      jump.height.toStringAsFixed(2),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () => _removeJump(index),
                                      tooltip: 'Eliminar',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String get _appBarTitle {
    String title = 'Serie';
    if (widget.limiteSaltos != null && widget.limiteSaltos! > 0) {
      title += ' (${widget.limiteSaltos} saltos';
      if (widget.limiteTiempo != null && widget.limiteTiempo! > 0) {
        title += ' / ${widget.limiteTiempo} seg)';
      } else {
        title += ')';
      }
    } else if (widget.limiteTiempo != null && widget.limiteTiempo! > 0) {
      title += ' (${widget.limiteTiempo} seg)';
    } else {
      title += ' (libre)'; // Si no hay límites definidos
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToInitialStateForNewCycle,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            height: 150,
            child: Lottie.asset(
              'assets/animations/Animationjump.json',
              controller: _animationController,
              fit: BoxFit.contain,
              animate: _lastPinState != -1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: _buildStatusMessage(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              icon: _isSendingCommand
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isSendingCommand
                    ? 'ENVIANDO...'
                    : 'INICIAR SERIE',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSendingCommand ? Colors.orange[300] : Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: (_isSendingCommand || !_bleRepo.isConnected || _isJumpInProgress)
                  ? null
                  : _sendStartSeriesCommand,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: _buildJumpHistoryList(),
            ),
          ),
        ],
      ),
    );
  }
}
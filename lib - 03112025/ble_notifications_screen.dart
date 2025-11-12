// ARCHIVO REFACTORIZADO: lib/ble_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// --- NUEVA IMPORTACIÓN DEL SERVICIO DE GUARDADO ---
import 'jump_storage_service.dart';
// ------------------------------------------------

import 'ble_repository.dart';
import 'jump_data_processor.dart';
import 'bluetooth_provider.dart';
import 'user_model.dart';

class BleNotificationsScreen extends StatefulWidget {
  final String jumpType;
  final int? sessionID;
  final User? person;
  final int limiteSaltos;
  final int limiteTiempo;
  final bool comienzaDesdeAdentro;
  final double pesoExtra;
  final bool ultimoSaltoCompleto;
  final double alturaCaida;
  final double pesoPersona;
  final int alturaPersona;

  const BleNotificationsScreen({
    super.key,
    required this.jumpType,
    this.sessionID,
    this.person,
    this.limiteSaltos = 0,
    this.limiteTiempo = 0,
    this.comienzaDesdeAdentro = true,
    this.pesoExtra = 0.0,
    this.ultimoSaltoCompleto = true,
    this.alturaCaida = 0.0,
    this.pesoPersona = 0.0,
    this.alturaPersona = 0,
  });

  @override
  State<BleNotificationsScreen> createState() => _BleNotificationsScreenState();
}

class _BleNotificationsScreenState extends State<BleNotificationsScreen> {
  late final BleRepository _bleRepo;
  late final BleMessageProcessor _messageProcessor;
  File? _lastSavedFile;

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<int>? _pinStateSubscription;
  StreamSubscription<JumpData>? _jumpDataSubscription;
  StreamSubscription<bool>? _seriesEndSubscription;
  StreamSubscription<bool>? _deviceResetSubscription;
  StreamSubscription<String>? _unrecognizedMessageSubscription;

  int _lastPinState = -1;
  bool _isSendingCommand = false;
  bool _isJumpInProgress = false;
 

  List<JumpData> _jumpHistory = [];
  List<JumpData> _unsavedJumps = [];

  final ScrollController _scrollController = ScrollController();
  String _tempFeedbackMessage = '';

  @override
  void initState() {
    super.initState();
    debugPrint('--- Pantalla de Medición Iniciada ---');
    debugPrint('Parámetro jumpType: ${widget.jumpType}');
    if (widget.jumpType.startsWith('MULTI')) {
      debugPrint('Límite de Saltos: ${widget.limiteSaltos}');
      debugPrint('Límite de Tiempo: ${widget.limiteTiempo}');
    }
    debugPrint('-------------------------------------');

    _bleRepo = Provider.of<BleRepository>(context, listen: false);
    _messageProcessor = Provider.of<BleMessageProcessor>(
      context,
      listen: false,
    );

    _messageProcessor.configurarNuevaPrueba(
      jumpType: widget.jumpType,
      limiteSaltos: widget.limiteSaltos,
      limiteTiempo: widget.limiteTiempo,
      comienzaDesdeAdentro: widget.comienzaDesdeAdentro,
    );
    _lastPinState = BluetoothProvider().lastPinState;
 
    _setupBluetoothListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendInitialCommand();
      }
    });
  }

  void _setupBluetoothListeners() {
    _pinStateSubscription = _messageProcessor.pinStateStream.listen(
      (pinState) {
        debugPrint('[APP] Pin State recibido: $pinState');
        final previousPinState = _lastPinState;
        if (mounted) {
          setState(() {
            _lastPinState = pinState;
            if (_isJumpInProgress || widget.jumpType != 'DJ_EX') {
              _tempFeedbackMessage = '';
            }
          });
        }
      
        if (widget.jumpType != 'DJ_EX' &&
            !_isJumpInProgress &&
            previousPinState != 0 &&
            pinState == 0) {
          _playSound('start.wav');
        }
        if (pinState == 1) {
          _deactivateJumpMode();
        }
      },
      onError: (e) => debugPrint('[APP] Error en pinStateStream: $e'),
    );

    _jumpDataSubscription = _messageProcessor.jumpDataStream.listen(
      (newJump) {
        debugPrint('[APP] JumpData recibido: ${newJump.height} cm');
        if (mounted) {
          setState(() {
            _jumpHistory.add(newJump);
            _unsavedJumps.add(newJump);
            _isJumpInProgress = false;
            _tempFeedbackMessage = '';
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡Salto registrado! Altura: ${newJump.height.toStringAsFixed(2)} cm'),
              ),
            );
          });
          _playSound('start.wav');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      onError: (e) {
        debugPrint('[APP] Error en jumpDataStream: $e');
        if (mounted) {
          setState(() {
            _isJumpInProgress = false;
            _tempFeedbackMessage = '';
          });
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar datos de salto: $e')),
          );
        }
      },
    );

    // --- LISTENER ACTUALIZADO ---
    _seriesEndSubscription = _messageProcessor.seriesEndStream.listen((_) {
      debugPrint('[APP] Fin de serie detectado. Guardando datos si es necesario...');
     Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _unsavedJumps.isNotEmpty) {
          debugPrint('[APP] Retraso completado. Guardando ${_unsavedJumps.length} saltos.');
          _triggerSaveData();
        } else if (mounted) {
           debugPrint('[APP] Retraso completado. No hay saltos sin guardar.');
        }
      });
      if (mounted && _unsavedJumps.isNotEmpty) {
        // Se llama a la nueva función que delega el guardado.
        _triggerSaveData();
      }
    }, onError: (e) {
      debugPrint('[APP] Error en seriesEndStream: $e');
    });
    // ----------------------------

    _deviceResetSubscription = _messageProcessor.deviceResetStream.listen(
      (_) {
        debugPrint('[APP] Dispositivo BLE reiniciado (boton,14).');
        _resetToInitialState();
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ciclo de salto reiniciado por el dispositivo.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onError: (e) => debugPrint('[APP] Error en deviceResetStream: $e'),
    );

    _unrecognizedMessageSubscription =
        _messageProcessor.unrecognizedMessageStream.listen(
      (message) => debugPrint('[APP] Mensaje no reconocido del BLE: "$message"'),
      onError: (e) => debugPrint('[APP] Error en unrecognizedMessageStream: $e'),
    );
  }

  // --- NUEVA FUNCIÓN QUE LLAMA AL SERVICIO DE GUARDADO ---
  Future<void> _triggerSaveData() async {
    debugPrint("[UI] Se llamó a _triggerSaveData con ${_unsavedJumps.length} saltos.");

    if (_unsavedJumps.isEmpty) {
      debugPrint('[UI] No hay nuevos saltos para guardar.');
      return;
    }

    // Se obtiene el servicio desde el provider.
    final storageService = context.read<JumpStorageService>();

    try {
      // Se llama al servicio con todos los datos necesarios.
      final savedFile = await storageService.saveData(
        jumpsToSave: List.from(_unsavedJumps), // Se pasa una copia de la lista
        jumpType: widget.jumpType,
        person: widget.person,
        sessionID: widget.sessionID,
        limiteSaltos: widget.limiteSaltos,
        limiteTiempo: widget.limiteTiempo,
        alturaCaida: widget.alturaCaida,
        pesoPersona: widget.pesoPersona,
        alturaPersona: widget.alturaPersona,
      );

      // Si el servicio tuvo éxito, se actualiza la UI.
      if (savedFile != null && mounted) {
        setState(() {
          _unsavedJumps.clear(); // Se limpia el búfer de saltos no guardados.
          _lastSavedFile = savedFile; // Se guarda la referencia para "Compartir".
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nuevos saltos guardados en: ${savedFile.path}')),
        );
      }
    } catch (e) {
      // Si el servicio falló, se muestra el error en la UI.
      debugPrint("!!! ERROR en _triggerSaveData (UI): $e !!!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el archivo: $e')),
        );
      }
    }
  }

  // --- EL RESTO DE FUNCIONES DE LA PANTALLA PERMANECEN IGUAL ---

  Future<void> _stopSeriesCommand() async {
    if (mounted) {
      setState(() => _isJumpInProgress = false);
      final command = utf8.encode('69');
      await _bleRepo.writeData(command);
      _playSound('end.wav');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serie de saltos finalizada.')),
      );
    }
  }

  Future<void> _shareDataFile() async {
    if (_lastSavedFile != null && await _lastSavedFile!.exists()) {
      try {
        final xFile = XFile(_lastSavedFile!.path);
        await Share.shareXFiles([xFile], text: 'Historial de Saltos');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al compartir el archivo: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un archivo guardado recientemente para compartir.')),
      );
    }
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint('Error al reproducir sonido $soundFile: $e');
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _sendInitialCommand() async {
    if (!_bleRepo.isConnected || _bleRepo.writeCharacteristics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo no conectado o no listo.')),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comando enviado. Por favor, colóquese en la alfombra.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

 

void _resetToInitialState() {
  debugPrint('[APP] Reiniciando estado general.');
  if (mounted) {
    setState(() {
      _isSendingCommand = false;
      _isJumpInProgress = false;
      _lastPinState = -1;
      // _animationController.reset(); // <--- LÍNEA ELIMINADA
      _tempFeedbackMessage = '';
    });
  }
  _sendInitialCommand();
}

void _deactivateJumpMode() {
  if (mounted) {
    setState(() {
      _lastPinState = 1;
      _isJumpInProgress = false;
      _tempFeedbackMessage = '';
    });
  }
  // _controlAnimation(); // <--- LÍNEA ELIMINADA
}

  Future<void> _sendJumpCommand() async {
    if (!_bleRepo.isConnected || _bleRepo.writeCharacteristics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay conexión BLE activa.')),
        );
      }
      return;
    }

    String feedbackMessage = '';
    String soundToPlay = '';
    bool canSendBluetoothCommand = false;

    bool debeComenzarAfuera = (widget.jumpType == 'DJ_EX') ? true : !widget.comienzaDesdeAdentro;

    if (debeComenzarAfuera) {
      if (_lastPinState == 1 || _lastPinState == -1) {
        canSendBluetoothCommand = true;
        feedbackMessage = '¡Listo! Inicie desde FUERA de la alfombra.';
        soundToPlay = 'start.wav';
      } else {
        feedbackMessage = 'ERROR: DEBE INICIAR FUERA DE LA ALFOMBRA.';
        soundToPlay = 'bad.wav';
      }
    } else {
      if (_lastPinState == 0) {
        canSendBluetoothCommand = true;
        feedbackMessage = '¡Listo! Inicie desde DENTRO de la alfombra.';
        soundToPlay = 'start.wav';
      } else {
        feedbackMessage = 'ERROR: DEBE ESTAR SOBRE LA ALFOMBRA PARA INICIAR.';
        soundToPlay = 'bad.wav';
      }
    }

    if (!canSendBluetoothCommand) {
      await _playSound(soundToPlay);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(feedbackMessage), duration: const Duration(seconds: 3)),
        );
        setState(() => _tempFeedbackMessage = feedbackMessage);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _tempFeedbackMessage = '');
        });
      }
      return;
    }

    _messageProcessor.iniciarRecoleccionManual(widget.jumpType);

    if (mounted) {
      setState(() {
        _isSendingCommand = true;
        _isJumpInProgress = true;
        _tempFeedbackMessage = '';
      });
    }

    try {
      await _playSound(soundToPlay);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(feedbackMessage), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      debugPrint('Error al enviar comando de salto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el comando de salto: $e')),
        );
        setState(() => _isJumpInProgress = false);
      }
    } finally {
      if (mounted) setState(() => _isSendingCommand = false);
    }
  }

  void _clearJumpHistory() {
    if (mounted) {
      setState(() {
        _jumpHistory.clear();
        _unsavedJumps.clear();
      });
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial de saltos borrado.')),
      );
    }
  }

  void _removeJump(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Salto'),
        content:
            const Text('¿Estás seguro de que quieres eliminar este salto del historial?'),
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
      // NOTA: Aquí aún existe la inconsistencia que discutimos.
      // Se arreglará en un paso posterior.
      final jumpToRemove = _jumpHistory[index];
      setState(() {
        _jumpHistory.removeAt(index);
        _unsavedJumps.remove(jumpToRemove); // <-- ARREGLO TEMPORAL DE CONSISTENCIA
      });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salto eliminado del historial.')),
        );
      }
    }
  }

  Widget _buildStatusMessage() {
    if (_isJumpInProgress) {
      return const Text(
        '¡SERIE DE SALTOS EN CURSO!',
        style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      );
    }
    if (_tempFeedbackMessage.isNotEmpty) {
      return Text(
        _tempFeedbackMessage,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
        textAlign: TextAlign.center,
      );
    }
    final bool debeComenzarAdentro = (widget.jumpType == 'DJ_EX') ? false : widget.comienzaDesdeAdentro;
    if (debeComenzarAdentro) {
      switch (_lastPinState) {
        case -1: return const Text('Esperando estado de la plataforma...', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center);
        case 0: return const Text('¡LISTO PARA SALTAR! Estás en la alfombra.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center);
        case 1: return const Text('DEBE ESTAR EN LA ALFOMBRA PARA INICIAR.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.red), textAlign: TextAlign.center);
      }
    } else {
      switch (_lastPinState) {
        case -1:
        case 1: return const Text('¡LISTO PARA SALTAR! Estás fuera de la alfombra.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center);
        case 0: return const Text('DEBE ESTAR FUERA DE LA ALFOMBRA PARA INICIAR.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.red), textAlign: TextAlign.center);
      }
    }
    return Text('Estado de sensor desconocido: $_lastPinState', style: const TextStyle(fontSize: 16, color: Colors.red), textAlign: TextAlign.center);
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
                'Historial de Saltos (${_jumpHistory.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    onPressed: _shareDataFile,
                    tooltip: 'Compartir archivo CSV',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _clearJumpHistory,
                    tooltip: 'Limpiar todo el historial',
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4.0)),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            children: const [
              SizedBox(width: 40, child: Center(child: Text('N°', style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 2, child: Center(child: Text('Altura (cm)', style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 2, child: Center(child: Text('Vuelo (ms)', style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 2, child: Center(child: Text('Contacto (ms)', style: TextStyle(fontWeight: FontWeight.bold)))),
              SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: _jumpHistory.isEmpty
              ? const Center(
                  child: Text(
                    'Los saltos registrados aparecerán aquí.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _jumpHistory.length,
                  itemBuilder: (context, index) {
                    final jump = _jumpHistory[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Center(child: Text('${index + 1}'))),
                            Expanded(flex: 2, child: Center(child: Text(jump.height.toStringAsFixed(2)))),
                            Expanded(flex: 2, child: Center(child: Text(jump.flightTime.toStringAsFixed(2)))),
                            Expanded(flex: 2, child: Center(child: Text(jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2)))),
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _removeJump(index),
                                tooltip: 'Eliminar este salto',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


@override
void dispose() {
  _audioPlayer.dispose();
  _pinStateSubscription?.cancel();
  _jumpDataSubscription?.cancel();
  _seriesEndSubscription?.cancel();
  _deviceResetSubscription?.cancel();
  _unrecognizedMessageSubscription?.cancel();
  // _animationController.dispose(); // <--- LÍNEA ELIMINADA
  _scrollController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
       // --- CAMBIO AQUÍ ---
        centerTitle: true,
        title: Text(
          'Medición de \nSalto ${widget.jumpType}', // Añade '\n'
          textAlign: TextAlign.center, // Opcional: Centra el texto de dos líneas
style: TextStyle(
            fontSize: 18.0, // <-- Ajusta este valor como necesites
          ),
        ),
        // -------------------
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToInitialState,
            tooltip: 'Reiniciar la medición',
          ),
        ],
      ),
      body: Column(
        children: [
// --- INICIO DE LA MODIFICACIÓN ---
          // Combinamos la imagen y el texto en una sola fila (Row)
          Padding(
            // Mantenemos el padding original para alinear con el resto
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Centra ícono y texto verticalmente
              children: [
                // 1. La imagen (ahora pequeña)
                SizedBox(
                  height: 40, // <-- Altura de ícono
                  width: 40,  // <-- Ancho de ícono
                  child: Image.asset(
                    _lastPinState == 0
                        ? 'assets/images/pisando.png'
                        : 'assets/images/libre.png',
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 12), // Espacio entre ícono y texto

                // 2. El texto de estado (envuelto en Expanded)
                // Expanded hace que ocupe el resto del espacio disponible en la fila
                Expanded(
                  child: _buildStatusMessage(),
                ),
              ],
            ),
          ),
          // --- FIN DE LA MODIFICACIÓN ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Tooltip(
              message: 'Inicia o detiene la serie de saltos.',
              child: ElevatedButton.icon(
                icon: _isJumpInProgress
                    ? const Icon(Icons.stop, color: Colors.white)
                    : (_isSendingCommand
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.play_arrow, color: Colors.white)),
                label: Text(
                  _isJumpInProgress
                      ? 'Detener la Captura'
                      : (_isSendingCommand ? 'ENVIANDO...' : 'Capturar'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isJumpInProgress ? Colors.red : Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: (_isSendingCommand || !_bleRepo.isConnected)
                    ? null
                    : () {
                        if (_isJumpInProgress) _stopSeriesCommand();
                        else _sendJumpCommand();
                      },
              ),
            ),
          ),
          Expanded(child: _buildJumpHistoryList()),
        ],
      ),
    );
  }
}
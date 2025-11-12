// ARCHIVO MODIFICADO Y COMPLETO: ble_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'dart:async';
import 'dart:convert'; // Solo para utf8.encode al enviar comandos, no para recibir
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart'; // Importar provider

import 'ble_repository.dart';
import 'jump_data_processor.dart'; // ¡NUEVA IMPORTACIÓN! Usaremos el JumpData y los streams de aquí.
import 'package:share_plus/share_plus.dart';
import 'bluetooth_provider.dart';

// NOTA: La clase JumpData se ha movido a jump_data_processor.dart
// Elimina la definición de JumpData de este archivo si la tienes aquí.

// --- CLASE BleNotificationsScreen (Widget principal de la pantalla) ---
class BleNotificationsScreen extends StatefulWidget {
  final String jumpType; // Tipo de salto que se está midiendo
  // --- INICIO DEL FRAGMENTO ---
  // Se declaran las variables que almacenarán los parámetros
  final int limiteSaltos;
  final int limiteTiempo;
  final bool comienzaDesdeAdentro;
  final double pesoExtra;
  final bool ultimoSaltoCompleto;

  const BleNotificationsScreen({
    super.key,
    required this.jumpType,
    this.limiteSaltos = 0,
    this.limiteTiempo = 0,
    this.comienzaDesdeAdentro = true,
    this.pesoExtra = 0.0,
    this.ultimoSaltoCompleto = true,
  });

  @override
  State<BleNotificationsScreen> createState() => _BleNotificationsScreenState();
}

class _BleNotificationsScreenState extends State<BleNotificationsScreen>
    with SingleTickerProviderStateMixin {
  // <--- Inicia la clase State aquí
  // Ahora obtendremos el BleRepository y el JumpDataProcessor del Provider
  late final BleRepository _bleRepo;
  late final BleMessageProcessor _messageProcessor;
  File? _lastSavedFile; // Para guardar la referencia al último archivo guardado

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Suscripciones a los streams del BleMessageProcessor
  StreamSubscription<int>? _pinStateSubscription;
  StreamSubscription<JumpData>? _jumpDataSubscription;
  StreamSubscription<bool>? _seriesEndSubscription; // <-- AÑADIDO
  StreamSubscription<bool>? _deviceResetSubscription;
  StreamSubscription<String>? _unrecognizedMessageSubscription;

  int _lastPinState = -1; // -1: desconocido, 0: en alfombra, 1: fuera de alfombra
  bool _isSendingCommand = false; // Indica si se está enviando un comando BLE
  bool _isJumpInProgress = false; // Indica si un salto está en curso (comando enviado y esperando resultado)
  late AnimationController _animationController;
  
  List<JumpData> _jumpHistory = [];
  List<JumpData> _unsavedJumps = []; // <-- AÑADIDO
  
  final ScrollController _scrollController = ScrollController();

  // Variable para mostrar mensajes de feedback temporal al usuario
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _setupBluetoothListeners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendInitialCommand();
      }
    });
  }

  void _setupBluetoothListeners() {
    // Escucha el estado del pin
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
        _controlAnimation();
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
      onError: (e) {
        debugPrint('[APP] Error en pinStateStream: $e');
      },
    );

    // Escucha los datos de salto procesados
   // Escucha los datos de salto procesados
_jumpDataSubscription = _messageProcessor.jumpDataStream.listen(
  (newJump) {
    debugPrint('[APP] JumpData recibido: ${newJump.height} cm');
    if (mounted) {
      setState(() {
        // --- INICIO DEL CAMBIO ---
        _jumpHistory.add(newJump);
        _unsavedJumps.add(newJump);
        // --- FIN DEL CAMBIO ---
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
          // Anima para mostrar el último salto añadido
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut
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

    // <-- AÑADIDO: Listener para el fin de la serie -->
    _seriesEndSubscription = _messageProcessor.seriesEndStream.listen((_) {
      debugPrint('[APP] Fin de serie detectado. Guardando datos si es necesario...');
      if (mounted && _unsavedJumps.isNotEmpty) {
        _saveDataToFile();
      }
    }, onError: (e) {
      debugPrint('[APP] Error en seriesEndStream: $e');
    });

    // Escucha el evento de reinicio del dispositivo
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
      onError: (e) {
        debugPrint('[APP] Error en deviceResetStream: $e');
      },
    );

    // Escucha mensajes no reconocidos
    _unrecognizedMessageSubscription = _messageProcessor.unrecognizedMessageStream.listen(
          (message) {
            debugPrint('[APP] Mensaje no reconocido del BLE: "$message"');
          },
          onError: (e) {
            debugPrint('[APP] Error en unrecognizedMessageStream: $e');
          },
        );
  }

// Agregá esta nueva función a tu clase

Future<void> _stopSeriesCommand() async {
  if (mounted) {
    setState(() {
      _isJumpInProgress = false;
    });

    // Envía un comando de reseteo al dispositivo
    final command = utf8.encode('69'); // Comando de PARADA/REINICIO
    await _bleRepo.writeData(command);
    _playSound('end.wav');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Serie de saltos finalizada.')),
    );
  }
}

  Future<void> _shareDataFile() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final xFile = XFile(file.path);
        await Share.shareXFiles([xFile], text: 'Historial de Saltos');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero debes guardar el archivo antes de compartirlo.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir el archivo: $e')),
      );
    }
  }

  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
      debugPrint('Sonido $soundFile reproducido correctamente');
    } catch (e) {
      debugPrint('Error al reproducir sonido $soundFile: $e');
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _sendInitialCommand() async {
    if (!_bleRepo.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay un dispositivo BLE conectado. Conéctese primero.'),
          ),
        );
      }
      return;
    }
    if (_bleRepo.writeCharacteristics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron características de escritura en el dispositivo.'),
          ),
        );
      }
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comando de tipo de salto enviado. Por favor, colóquese en la alfombra.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[BLE] Error enviando comando inicial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de configuración al enviar el comando inicial: $e'),
          ),
        );
      }
    }
  }

  void _controlAnimation() {
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
  }

  void _resetToInitialState() {
    debugPrint('[APP] Reiniciando estado general.');
    if (mounted) {
      setState(() {
        _isSendingCommand = false;
        _isJumpInProgress = false;
        _lastPinState = -1;
        _animationController.reset();
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
    _controlAnimation();
  }

  Future<void> _sendJumpCommand() async {
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
          const SnackBar(
            content: Text('No se encontraron características de escritura.'),
          ),
        );
      }
      return;
    }

    String feedbackMessage = '';
    String soundToPlay = '';
    bool canSendBluetoothCommand = false;

    bool debeComenzarAfuera = !widget.comienzaDesdeAdentro;

    if (widget.jumpType == 'DJ_EX') {
      debeComenzarAfuera = true;
    } else if (widget.jumpType == 'SJ' ||
        widget.jumpType == 'CMJ' ||
        widget.jumpType == 'SJl' ||
        widget.jumpType == 'DJ_IN' ||
        widget.jumpType == 'ABK') {
      debeComenzarAfuera = false;
    }

    if (debeComenzarAfuera) {
      if (_lastPinState == 1 || _lastPinState == -1) {
        canSendBluetoothCommand = true;
        feedbackMessage = '¡Listo! Inicie desde FUERA de la alfombra.';
        soundToPlay = 'start.wav';
      } else {
        canSendBluetoothCommand = false;
        feedbackMessage = 'ERROR: DEBE INICIAR FUERA DE LA ALFOMBRA.';
        soundToPlay = 'bad.wav';
      }
    } else {
      if (_lastPinState == 0) {
        canSendBluetoothCommand = true;
        feedbackMessage = '¡Listo! Inicie desde DENTRO de la alfombra.';
        soundToPlay = 'start.wav';
      } else {
        canSendBluetoothCommand = false;
        feedbackMessage = 'ERROR: DEBE ESTAR SOBRE LA ALFOMBRA PARA INICIAR.';
        soundToPlay = 'bad.wav';
      }
    }
    if (!canSendBluetoothCommand) {
      await _playSound(soundToPlay);
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _tempFeedbackMessage = feedbackMessage;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _tempFeedbackMessage = '';
            });
          }
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
          SnackBar(
            content: Text(feedbackMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al enviar comando de salto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el comando de salto: $e')),
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

  // <-- CAMBIO: Se ha eliminado el método _toggleRecording() -->

Future<void> _saveDataToFile() async {
  if (_unsavedJumps.isEmpty) {
    debugPrint('No hay nuevos saltos en el búfer para guardar.');
    return;
  }

  try {
    final file = await _localFile;
    final userID = 'defaultUser';
    String csvContent = '';

    // Encabezado más descriptivo para ambos casos
    if (!await file.exists()) {
      csvContent += 'UserID,Jump Type,TC,TF,Timestamp\n';
    }

    // --- LÓGICA CONDICIONAL AÑADIDA ---
    if (widget.jumpType == 'MULTI' || widget.jumpType == 'DJ_IN') {
      // CASO 1: Saltos Múltiples (formato agrupado)
      
      // Mapea y une todos los TCs
      final String allContactTimes = _unsavedJumps.map((jump) {
        return jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2);
      }).join('=');

      // Mapea y une todos los TFs
      final String allFlightTimes = _unsavedJumps.map((jump) {
        return jump.flightTime.toStringAsFixed(2);
      }).join('=');

      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      
      // Construye la línea única para la serie
      csvContent += '$userID,${widget.jumpType},$allContactTimes,$allFlightTimes,$timestamp\n';

    } else {
      // CASO 2: Saltos Simples (una fila por salto)
      for (final jump in _unsavedJumps) {
        final tc = jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2);
        final tf = jump.flightTime.toStringAsFixed(2);
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(jump.timestamp);
        
        // Creamos una línea para este salto individual
        csvContent += '$userID,${widget.jumpType},$tc,$tf,$timestamp\n';
      }
    }
    
    await file.writeAsString(csvContent, mode: FileMode.append);
    
    setState(() {
      _unsavedJumps.clear();
      _lastSavedFile = file;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nuevos saltos guardados en: ${file.path}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al guardar el archivo: $e')),
    );
  }
}
  // <-- CAMBIO: Lógica de limpieza actualizada -->
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

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStamp = dateFormat.format(DateTime.now());
    return File('$path/Chronojump_saltos_$dateStamp.csv');
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

// Reemplazá tu función _buildStatusMessage completa con esta:

Widget _buildStatusMessage() {
  // Primero, manejamos los estados de prioridad alta
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

  // --- LÓGICA CORREGIDA ---
  // Determinamos la regla de inicio. DJ_EX siempre empieza afuera.
  final bool debeComenzarAdentro = (widget.jumpType == 'DJ_EX') ? false : widget.comienzaDesdeAdentro;

  if (debeComenzarAdentro) {
    // Lógica para cuando se debe iniciar DENTRO de la alfombra
    switch (_lastPinState) {
      case -1:
        return const Text(
          'Esperando estado de la plataforma...',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        );
      case 0: // Posición correcta
        return const Text(
          '¡LISTO PARA SALTAR! Estás en la alfombra.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        );
      case 1: // Posición incorrecta
        return const Text(
          'DEBE ESTAR EN LA ALFOMBRA PARA INICIAR.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.red),
          textAlign: TextAlign.center,
        );
    }
  } else {
    // Lógica para cuando se debe iniciar FUERA de la alfombra
    switch (_lastPinState) {
      case -1:
      case 1: // Posición correcta
        return const Text(
          '¡LISTO PARA SALTAR! Estás fuera de la alfombra.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        );
      case 0: // Posición incorrecta
        return const Text(
          'DEBE ESTAR FUERA DE LA ALFOMBRA PARA INICIAR.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.red),
          textAlign: TextAlign.center,
        );
    }
  }

  // Mensaje por defecto si algo falla
  return Text(
    'Estado de sensor desconocido: $_lastPinState',
    style: const TextStyle(fontSize: 16, color: Colors.red),
    textAlign: TextAlign.center,
  );
}// Reemplaza el método _buildJumpHistoryList() existente con este:

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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const SizedBox(width: 40, child: Center(child: Text('N°', style: TextStyle(fontWeight: FontWeight.bold)))),
              const Expanded(flex: 2, child: Center(child: Text('Altura (cm)', style: TextStyle(fontWeight: FontWeight.bold)))),
              const Expanded(flex: 2, child: Center(child: Text('Vuelo (ms)', style: TextStyle(fontWeight: FontWeight.bold)))),
              const Expanded(flex: 3, child: Center(child: Text('Contacto (ms)', style: TextStyle(fontWeight: FontWeight.bold)))),
              if (_jumpHistory.any((jump) => jump.fallTime != null))
                const Expanded(flex: 2, child: Center(child: Text('Caída (cm)', style: TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      Expanded(
        child: _jumpHistory.isEmpty
            ? const Center(
                child: Text(
                  'No hay saltos registrados aún. Los saltos aparecerán aquí.',
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
                          // --- CAMBIO 1: Numeración de saltos ---
                          // Se cambia '${_jumpHistory.length - index}' por '${index + 1}'
                          SizedBox(width: 40, child: Center(child: Text('${index + 1}'))),
                          
                          Expanded(flex: 2, child: Center(child: Text(jump.height.toStringAsFixed(2)))),
                          Expanded(flex: 2, child: Center(child: Text(jump.flightTime.toStringAsFixed(2)))),
                          
                          // --- CAMBIO 2: Mostrar -1 para contacto 0 ---
                          Expanded(
                            flex: 2, 
                            child: Center(
                              child: Text(jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2))
                            )
                          ),

                          if (jump.fallTime != null)
                            Expanded(flex: 2, child: Center(child: Text(jump.fallTime!.toStringAsFixed(2)))),
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
    _seriesEndSubscription?.cancel(); // <-- AÑADIDO
    _deviceResetSubscription?.cancel();
    _unrecognizedMessageSubscription?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medición de Salto - ${widget.jumpType}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToInitialState,
            tooltip: 'Reiniciar la medición',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
// Busca el Padding que envuelve tu botón y reemplázalo por este bloque completo:

Padding(
  padding: const EdgeInsets.symmetric(vertical: 10),
  child: Tooltip(
    message: 'Inicia o detiene la serie de saltos.',
    child: ElevatedButton.icon(
      // Usa el nombre de variable original
      icon: _isJumpInProgress
        ? const Icon(Icons.stop, color: Colors.white)
        : (_isSendingCommand
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow, color: Colors.white)),

      label: Text(
        _isJumpInProgress // <-- Usa el nombre original
            ? 'DETENER SERIE'
            : (_isSendingCommand ? 'ENVIANDO...' : 'INICIAR SERIE'),
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),

      style: ElevatedButton.styleFrom(
        backgroundColor: _isJumpInProgress ? Colors.red : Colors.orange, // <-- Usa el nombre original
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      
      onPressed: 
        (_isSendingCommand || !_bleRepo.isConnected)
          ? null
          : () {
              if (_isJumpInProgress) { // <-- Usa el nombre original
                _stopSeriesCommand();
              } else {
                _sendJumpCommand();
              }
            },
    ),
  ),
),

         Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: _buildJumpHistoryList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
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
import 'session_person_provider.dart'; // <-- AÑADIDO
import 'user_provider.dart';           // <-- AÑADIDO
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
User? _currentPerson; // <--- 1. AÑADE ESTA VARIABLE

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<int>? _pinStateSubscription;
  StreamSubscription<JumpData>? _jumpDataSubscription;
  StreamSubscription<bool>? _seriesEndSubscription;
  StreamSubscription<bool>? _deviceResetSubscription;
  StreamSubscription<String>? _unrecognizedMessageSubscription;

  int _lastPinState = -1;
  bool _isSendingCommand = false;
  bool _isJumpInProgress = false;
  
  // --- NUEVAS VARIABLES AÑADIDAS ---
  bool _isWaitingForAthleteOnMat = false;
  bool _hasJumpBeenTriggered = false;

  List<JumpData> _jumpHistory = [];
  List<JumpData> _unsavedJumps = [];

  final ScrollController _scrollController = ScrollController();
  String _tempFeedbackMessage = '';

  @override
  void initState() {
    super.initState();
_currentPerson = widget.person; // <--- 2. INICIALÍZALA AQUÍ
_lastPinState = context.read<BluetoothProvider>().lastPinState;

// --- NORMALIZACIÓN TÉCNICA ---
  String tipoTecnico = widget.jumpType;
  bool inicioReal = widget.comienzaDesdeAdentro;

  if (widget.jumpType == 'DJ_EX') {
    tipoTecnico = 'DJna'; // 'na' = No Adentro / Externo
    inicioReal = false;   // Forzamos lógica de inicio afuera
  } else if (widget.jumpType == 'DJ_IN') {
    tipoTecnico = 'DJa';  // 'a' = Adentro / Interno
    inicioReal = true;
  }
  // -----------------------------




    debugPrint('--- Pantalla de Medición Iniciada ---');
    debugPrint('Parámetro jumpType: ${widget.jumpType}');
    if (widget.jumpType.startsWith('MULTI')) {
      debugPrint('Límite de Saltos: ${widget.limiteSaltos}');
      debugPrint('Límite de Tiempo: ${widget.limiteTiempo}');
    }
    debugPrint('-------------------------------------');

// AÑADE ESTO AQUÍ:
  debugPrint('--- [DEBUG ENTRADA] ---');
  debugPrint('Valor local _lastPinState: $_lastPinState');
  final providerPin = Provider.of<BluetoothProvider>(context, listen: false).lastPinState;
  debugPrint('Valor en BluetoothProvider: $providerPin');
  debugPrint('-----------------------');
// --- SOLUCIÓN: Ajuste automático de lógica para DJ_EX ---
  bool inicioDesdeAdentro = widget.comienzaDesdeAdentro;
//  if (widget.jumpType == 'DJ_EX') {
 //   inicioDesdeAdentro = false; // Forzamos inicio desde afuera
//  }





    _bleRepo = Provider.of<BleRepository>(context, listen: false);
    _messageProcessor = Provider.of<BleMessageProcessor>(
      context,
      listen: false,
    );
debugPrint('Parámetro parado: $inicioDesdeAdentro');
    _messageProcessor.configurarNuevaPrueba(
    //  jumpType: widget.jumpType,
      jumpType: tipoTecnico, // Usamos la variable normalizada
      limiteSaltos: widget.limiteSaltos,
      limiteTiempo: widget.limiteTiempo,
      comienzaDesdeAdentro: inicioReal,
   //   comienzaDesdeAdentro: inicioDesdeAdentro,
       
    
    );
   // _lastPinState = BluetoothProvider().lastPinState;
 
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
            if (pinState == -1) return; // Si es -1, ignoramos el evento por completo
            if (_isJumpInProgress || widget.jumpType != 'DJ_EX') {
              _tempFeedbackMessage = '';
            }
          });
        }

        // --- NUEVA LÓGICA: Detectar cuando el atleta se pone en posición correcta ---
        if (_isWaitingForAthleteOnMat && !_isJumpInProgress && !_hasJumpBeenTriggered) {
          final bool debeComenzarAdentro = (widget.jumpType == 'DJ_EX') 
              ? false 
              : widget.comienzaDesdeAdentro;
              
          bool isInCorrectPosition = debeComenzarAdentro ? 
              (pinState == 0) : // Debe estar en alfombra
              (pinState == 1);  // Debe estar fuera
              
          if (isInCorrectPosition) {
            debugPrint('[APP] Atleta en posición correcta - iniciando salto automáticamente');
            _startJumpSequence();
          }
        }
        // --- FIN DE NUEVA LÓGICA ---
      
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
            _hasJumpBeenTriggered = false; // Resetear para permitir nuevo salto
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
            _hasJumpBeenTriggered = false;
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
// DEBUG 1: Verificamos las listas apenas entra la función
  debugPrint("[DEBUG SAVE] Cantidad en _unsavedJumps: ${_unsavedJumps.length}");
  debugPrint("[DEBUG SAVE] Cantidad en _jumpHistory: ${_jumpHistory.length}");

  if (_unsavedJumps.isEmpty) {
    debugPrint('[DEBUG SAVE] ABORTANDO: La lista de pendientes está vacía.');
    return;
  }
    if (_unsavedJumps.isEmpty) {
      debugPrint('[UI] No hay nuevos saltos para guardar.');
      return;
    }

    // Se obtiene el servicio desde el provider.
    final storageService = context.read<JumpStorageService>();

    try {
      // Se llama al servicio con todos los datos necesarios.
      String nombreTecnico = widget.jumpType;
      
      if (widget.jumpType == 'DJ_EX') nombreTecnico = 'DJna';
      if (widget.jumpType == 'DJ_IN') nombreTecnico = 'DJa';

// DEBUG 2: Verificamos qué nombre le vamos a mandar al servicio
    debugPrint("[DEBUG SAVE] Enviando al storage -> Tipo: $nombreTecnico, Saltos: ${_unsavedJumps.length}");


// --- DEBUG NIVEL 2: CONTENIDO DE LOS SALTOS ---
  for (var i = 0; i < _unsavedJumps.length; i++) {
    var jump = _unsavedJumps[i];
    debugPrint("[DEBUG] Salto [$i]: Altura=${jump.height}cm, TiempoVuelo=${jump.flightTime}ms");
  }

      final savedFile = await storageService.saveData(
        jumpsToSave: List.from(_unsavedJumps), // Se pasa una copia de la lista
      //  jumpType: widget.jumpType,
        jumpType: nombreTecnico, // Se guarda como DJna o DJa
        person: _currentPerson, // <--- 3. CAMBIA widget.person POR _currentPerson
     //   person: widget.person,
        sessionID: widget.sessionID,
        limiteSaltos: widget.limiteSaltos,
        limiteTiempo: widget.limiteTiempo,
        alturaCaida: widget.alturaCaida,
        pesoPersona: widget.pesoPersona,
        alturaPersona: widget.alturaPersona,
      );

      // Si el servicio tuvo éxito, se actualiza la UI.
      if (savedFile != null && mounted) {
debugPrint("[DEBUG] ARCHIVO GENERADO OK en: ${savedFile.path}");
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

  // --- NUEVOS MÉTODOS PARA EL FLUJO MEJORADO ---

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

    // Si ya hay un salto en progreso o estamos esperando, no hacer nada
    if (_isJumpInProgress || _isWaitingForAthleteOnMat || _hasJumpBeenTriggered) {
      return;
    }

    // Verificar si el atleta está en la posición correcta para comenzar
    final bool debeComenzarAdentro = (widget.jumpType == 'DJ_EX') 
        ? false 
        : widget.comienzaDesdeAdentro;

    if (debeComenzarAdentro && _lastPinState != 0) {
      // Atleta DEBE estar en la alfombra pero NO lo está
      _startWaitingForAthleteOnMat();
      return;
    } else if (!debeComenzarAdentro && _lastPinState != 1) {
      // Atleta DEBE estar fuera pero NO lo está
      _startWaitingForAthleteOffMat();
      return;
    }

    // Si está en la posición correcta, iniciar inmediatamente
    _startJumpSequence();
  }

  void _startWaitingForAthleteOnMat() {
    debugPrint('[APP] Esperando que atleta se ponga en la alfombra...');
    
    if (mounted) {
      setState(() {
        _isWaitingForAthleteOnMat = true;
        _tempFeedbackMessage = 'POR FAVOR: PÓNGASE EN LA ALFOMBRA PARA INICIAR';
      });
    }

    _playSound('bad.wav');
    
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esperando que se ponga en la alfombra...'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startWaitingForAthleteOffMat() {
    debugPrint('[APP] Esperando que atleta salga de la alfombra...');
    
    if (mounted) {
      setState(() {
        _isWaitingForAthleteOnMat = true;
        _tempFeedbackMessage = 'POR FAVOR: SALGA DE LA ALFOMBRA PARA INICIAR';
      });
    }

    _playSound('bad.wav');
    
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Esperando que salga de la alfombra...'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _startJumpSequence() {
    debugPrint('[APP] Iniciando secuencia de salto...');
    
    _messageProcessor.iniciarRecoleccionManual(widget.jumpType);

    if (mounted) {
      setState(() {
        _isJumpInProgress = true;
        _hasJumpBeenTriggered = true;
        _isWaitingForAthleteOnMat = false;
        _tempFeedbackMessage = '';
      });
    }

    _playSound('start.wav');
    
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Secuencia de salto iniciada!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deactivateJumpMode() {
    if (mounted) {
      setState(() {
        _lastPinState = 1;
        _isJumpInProgress = false;
        _hasJumpBeenTriggered = false; // Resetear para permitir nuevo salto
        _isWaitingForAthleteOnMat = false;
        _tempFeedbackMessage = '';
      });
    }
  }

  void _resetToInitialState() {
    debugPrint('[APP] Reiniciando estado general.');
    if (mounted) {
      setState(() {
        _isSendingCommand = false;
        _isJumpInProgress = false;
        _hasJumpBeenTriggered = false;
        _isWaitingForAthleteOnMat = false;
        _lastPinState = -1;
        _tempFeedbackMessage = '';
      });
    }
    _sendInitialCommand();
  }

  // --- MÉTODOS AUXILIARES PARA EL BOTÓN ---
  Widget _getButtonIcon() {
    if (_isJumpInProgress) {
      return const Icon(Icons.stop, color: Colors.white);
    } else if (_isSendingCommand || _isWaitingForAthleteOnMat || _hasJumpBeenTriggered) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    } else {
      return const Icon(Icons.play_arrow, color: Colors.white);
    }
  }

  String _getButtonText() {
    if (_isWaitingForAthleteOnMat) {
      return 'ESPERANDO...';
    } else if (_isJumpInProgress) {
      return 'Detener la Captura';
    } else if (_isSendingCommand) {
      return 'ENVIANDO...';
    } else if (_hasJumpBeenTriggered) {
      return 'PREPARANDO...';
    } else {
      return 'Capturar';
    }
  }

  Color _getButtonColor() {
    if (_isWaitingForAthleteOnMat) {
      return Colors.blue;
    } else if (_isJumpInProgress) {
      return Colors.red;
    } else if (_isSendingCommand || _hasJumpBeenTriggered) {
      return Colors.grey;
    } else {
      return Colors.orange;
    }
  }

  bool _isButtonDisabled() {
    return _isSendingCommand || _hasJumpBeenTriggered;
  }

  // --- MÉTODOS EXISTENTES ---

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
      final jumpToRemove = _jumpHistory[index];
      setState(() {
        _jumpHistory.removeAt(index);
        _unsavedJumps.remove(jumpToRemove);
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
    if (_isWaitingForAthleteOnMat) {
      return Text(
        _tempFeedbackMessage,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        textAlign: TextAlign.center,
      );
    }
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
              SizedBox(width: 35, child: Center(child: Text('N°', style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 3, child: Center(child: Text('Altura\n(cm)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 3, child: Center(child: Text('Vuelo\n(ms)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 3, child: Center(child: Text('Contacto\n(ms)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
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
                            SizedBox(width: 35, child: Center(child: Text('${index + 1}'))),
                            Expanded(flex: 3, child: Center(child: Text(jump.height.toStringAsFixed(2)))),
                            Expanded(flex: 3, child: Center(child: Text(jump.flightTime.toStringAsFixed(2)))),
                            Expanded(flex: 3, child: Center(child: Text(jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2)))),
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
    _scrollController.dispose();
    super.dispose();
  }

// --- PEGA ESTAS DOS FUNCIONES JUSTO ENCIMA DE TU @override Widget build ---

  void _showPersonSelector() {
    if (widget.sessionID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar desde una Sesión para cambiar de atleta.')),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    final sessionPersonProvider = context.read<SessionPersonProvider>();
    
    // Filtramos solo los atletas que pertenecen a esta sesión específica
    final sessionParticipants = userProvider.users.where(
      (p) => sessionPersonProvider.isPersonInSession(widget.sessionID!, p.uniqueID)
    ).toList();

    if (sessionParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay participantes cargados en esta sesión.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Cambiar de Atleta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sessionParticipants.length,
                  itemBuilder: (context, index) {
                    final person = sessionParticipants[index];
                    final isCurrent = _currentPerson?.uniqueID == person.uniqueID;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? Colors.orange : const Color(0xFF3d5a80),
                        child: Text(person.firstName[0], style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text('${person.firstName} ${person.lastName}', 
                        style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () async {
                        Navigator.pop(context);
                        if (!isCurrent) {
                          await _changeAthlete(person);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _changeAthlete(User newPerson) async {
    // Si el atleta anterior dejó saltos colgados, los guardamos antes de cambiar
    if (_unsavedJumps.isNotEmpty) {
      await _triggerSaveData();
    }
    
    if (mounted) {
      setState(() {
        _currentPerson = newPerson;
        _jumpHistory.clear(); // Limpiamos pantalla para el nuevo atleta
        _unsavedJumps.clear();
        _tempFeedbackMessage = '';
        _isJumpInProgress = false;
        _hasJumpBeenTriggered = false;
        _isWaitingForAthleteOnMat = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evaluando a: ${newPerson.firstName}')),
      );
    }
  }

  // --- REEMPLAZA TU APPBAR ACTUAL EN EL MÉTODO BUILD POR ESTA ---

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: _showPersonSelector,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPerson != null 
                        ? '${_currentPerson!.firstName}' 
                        : 'Seleccionar Atleta',
                    style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
             Text(
  'Test: ${widget.jumpType}',
  style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Colors.black54),
),
            ],
          ),
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 40,
                  width: 40,
                  child: Image.asset(
                    _lastPinState == 0
                        ? 'assets/images/pisando.png'
                        : 'assets/images/libre.png',
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusMessage(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            child: Column(
              children: [
                Text(
                  _jumpHistory.isEmpty
                      ? '--'
                      : _jumpHistory.last.height.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 52.0,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'cm (Último Salto)',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Tooltip(
              message: 'Inicia o detiene la serie de saltos.',
              child: ElevatedButton.icon(
                icon: _getButtonIcon(),
                label: Text(
                  _getButtonText(),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getButtonColor(),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: (_isButtonDisabled() || !_bleRepo.isConnected)
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
      // ... (el body de tu Scaffold queda exactamente igual)
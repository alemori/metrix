// ARCHIVO MODIFICADO: lib/ble_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import 'ble_repository.dart';
import 'jump_data_processor.dart';
import 'bluetooth_provider.dart';
import 'session_model.dart';
import 'user_model.dart';
import 'user_provider.dart';
import 'jump_record_model.dart';

class BleNotificationsScreen extends StatefulWidget {
  final String jumpType;
  final int limiteSaltos;
  final int limiteTiempo;
  final bool comienzaDesdeAdentro;
  final double pesoExtra;
  final bool ultimoSaltoCompleto;
  final Session? session; // <-- Recibe la sesión

  const BleNotificationsScreen({
    super.key,
    required this.jumpType,
    this.limiteSaltos = 0,
    this.limiteTiempo = 0,
    this.comienzaDesdeAdentro = true,
    this.pesoExtra = 0.0,
    this.ultimoSaltoCompleto = true,
    this.session, // <-- Recibe la sesión
  });

  @override
  State<BleNotificationsScreen> createState() => _BleNotificationsScreenState();
}

class _BleNotificationsScreenState extends State<BleNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final BleRepository _bleRepo;
  late final BleMessageProcessor _messageProcessor;
  late final BluetoothProvider _bluetoothProvider;

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<int>? _pinStateSubscription;
  StreamSubscription<JumpData>? _jumpDataSubscription;
  StreamSubscription<bool>? _seriesEndSubscription;
  StreamSubscription<bool>? _deviceResetSubscription;

  int _lastPinState = -1;
  bool _isSendingCommand = false;
  bool _isJumpInProgress = false;
  late AnimationController _animationController;

  List<JumpRecord> _jumpHistory = [];
  List<JumpRecord> _unsavedJumps = [];

  final ScrollController _scrollController = ScrollController();
  
  // --- NUEVAS VARIABLES PARA GESTIONAR PARTICIPANTES ---
  List<User> _sessionParticipants = [];
  User? _selectedParticipant;

  @override
  void initState() {
    super.initState();
    _bleRepo = Provider.of<BleRepository>(context, listen: false);
    _messageProcessor = Provider.of<BleMessageProcessor>(context, listen: false);
    _bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);

    _lastPinState = _bluetoothProvider.lastPinState;
    _bluetoothProvider.addListener(_onGlobalPinStateChanged);

    // --- LÓGICA PARA CARGAR PARTICIPANTES DE LA SESIÓN ---
    if (widget.session != null) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _sessionParticipants = widget.session!.participantIDs.map((id) {
        try {
          return userProvider.users.firstWhere((user) => user.uniqueID == id);
        } catch (e) {
          return null; // El usuario pudo haber sido eliminado
        }
      }).whereType<User>().toList();

      // Si solo hay un participante, lo seleccionamos automáticamente
      if (_sessionParticipants.length == 1) {
        _selectedParticipant = _sessionParticipants.first;
      }
    }

    _messageProcessor.configurarNuevaPrueba(
      jumpType: widget.jumpType,
      limiteSaltos: widget.limiteSaltos,
      limiteTiempo: widget.limiteTiempo,
      comienzaDesdeAdentro: widget.comienzaDesdeAdentro,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _setupBluetoothListeners();
  }

  void _onGlobalPinStateChanged() {
    if (mounted && _lastPinState != _bluetoothProvider.lastPinState) {
      setState(() {
        _lastPinState = _bluetoothProvider.lastPinState;
      });
    }
  }

  void _setupBluetoothListeners() {
    _pinStateSubscription = _messageProcessor.pinStateStream.listen((pinState) {
      if (mounted) setState(() => _lastPinState = pinState);
    });

    _jumpDataSubscription = _messageProcessor.jumpDataStream.listen((newJump) {
      if (mounted) {
        // Ignorar saltos si no hay un atleta seleccionado en modo sesión
        if (widget.session != null && _selectedParticipant == null) return;

        final newRecord = JumpRecord(
          sessionID: widget.session?.sessionID ?? 0,
          personID: _selectedParticipant?.uniqueID ?? 0, // 0 si no hay sesión/participante
          jumpType: widget.jumpType,
          jumpData: newJump,
        );
        setState(() {
          _jumpHistory.add(newRecord);
          _unsavedJumps.add(newRecord);
          // Para saltos simples, la "serie" termina después de un salto
          if (widget.jumpType != 'MULTI') {
            _isJumpInProgress = false;
          }
        });
        
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Salto registrado! Altura: ${newJump.height.toStringAsFixed(2)} cm'),
          ),
        );
        _playSound('start.wav');
      }
    });

    _seriesEndSubscription = _messageProcessor.seriesEndStream.listen((_) {
      if (mounted) {
        setState(() => _isJumpInProgress = false);
        if (_unsavedJumps.isNotEmpty) {
          _saveDataToFile();
        }
      }
    });
    
    _deviceResetSubscription = _messageProcessor.deviceResetStream.listen((_) {
      if (mounted) setState(() => _isJumpInProgress = false);
    });
  }
  
  // --- MÉTODOS HELPER COMPLETOS (COPIAR Y PEGAR) ---

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

  Future<void> _saveDataToFile() async {
    if (_unsavedJumps.isEmpty) return;
    try {
      final file = await _localFile;
      String csvContent = '';
      if (!await file.exists()) {
        csvContent += 'SessionID,PersonID,JumpType,ContactTime_ms,FlightTime_ms,Height_cm,Timestamp\n';
      }
      for (final record in _unsavedJumps) {
        final sessionID = record.sessionID;
        final personID = record.personID;
        final jumpType = record.jumpType;
        final tc = record.jumpData.contactTime;
        final tf = record.jumpData.flightTime;
        final height = record.jumpData.height;
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(record.jumpData.timestamp);
        csvContent += '$sessionID,$personID,$jumpType,${tc.toStringAsFixed(2)},${tf.toStringAsFixed(2)},${height.toStringAsFixed(2)},$timestamp\n';
      }
      await file.writeAsString(csvContent, mode: FileMode.append);
      if (mounted) {
        setState(() => _unsavedJumps.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el archivo: $e')),
        );
      }
    }
  }

  Future<void> _sendJumpCommand() async {
    String feedbackMessage = '';
    String soundToPlay = '';
    bool canStart = false;

    bool debeComenzarAdentro = widget.comienzaDesdeAdentro;
    if (widget.jumpType == 'DJ_EX') debeComenzarAdentro = false;

    if (debeComenzarAdentro) {
      if (_lastPinState == 1) { // 1 = Adentro
        canStart = true;
        soundToPlay = 'start.wav';
      } else {
        feedbackMessage = 'ERROR: DEBE ESTAR SOBRE LA ALFOMBRA PARA INICIAR.';
        soundToPlay = 'bad.wav';
      }
    } else { // Debe comenzar afuera
      if (_lastPinState == 0) { // 0 = Afuera
        canStart = true;
        soundToPlay = 'start.wav';
      } else {
        feedbackMessage = 'ERROR: DEBE INICIAR FUERA DE LA ALFOMBRA.';
        soundToPlay = 'bad.wav';
      }
    }

    await _playSound(soundToPlay);
    if (!canStart) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedbackMessage)));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSendingCommand = true;
        _isJumpInProgress = true;
      });
    }
    _messageProcessor.iniciarRecoleccionManual(widget.jumpType);
    if (mounted) {
      setState(() => _isSendingCommand = false);
    }
  }
  
  Future<void> _stopSeriesCommand() async {
     if (mounted) {
      setState(() {
        _isJumpInProgress = false;
      });
      final command = utf8.encode('69');
      await _bleRepo.writeData(command);
      _playSound('end.wav');
    }
  }
  
  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint('Error al reproducir sonido $soundFile: $e');
    }
  }

  Widget _buildStatusMessage() {
    // Esta función no cambia, la dejamos como está en tu versión actual
    if (_isJumpInProgress) { return const Text('¡SERIE DE SALTOS EN CURSO!', style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold)); }
    bool debeComenzarAdentro = widget.comienzaDesdeAdentro;
    if (widget.jumpType == 'DJ_EX') debeComenzarAdentro = false;

    if (debeComenzarAdentro) {
      switch (_lastPinState) {
        case 1: return const Text('¡LISTO PARA SALTAR! Estás en la alfombra.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green));
        case 0: return const Text('DEBE ESTAR EN LA ALFOMBRA PARA INICIAR.', style: TextStyle(fontSize: 18, color: Colors.red));
        default: return const Text('Esperando estado de la plataforma...', style: TextStyle(fontSize: 18, color: Colors.grey));
      }
    } else {
      switch (_lastPinState) {
        case 0: return const Text('¡LISTO PARA SALTAR! Estás fuera de la alfombra.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green));
        case 1: return const Text('DEBE ESTAR FUERA DE LA ALFOMBRA PARA INICIAR.', style: TextStyle(fontSize: 18, color: Colors.red));
        default: return const Text('Esperando estado de la plataforma...', style: TextStyle(fontSize: 18, color: Colors.grey));
      }
    }
  }

  Widget _buildJumpHistoryList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _jumpHistory.length,
      itemBuilder: (context, index) {
        final record = _jumpHistory[index];
        final jump = record.jumpData;
        
        String participantName = 'ID: ${record.personID}';
        if (widget.session != null) {
          try {
            final user = _sessionParticipants.firstWhere((p) => p.uniqueID == record.personID);
            participantName = '${user.firstName} ${user.lastName}';
          } catch(e) { /* user not found, use ID */ }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            title: Text('Salto #${index + 1} - ${jump.height.toStringAsFixed(2)} cm'),
            subtitle: Text('$participantName | V: ${jump.flightTime.toStringAsFixed(2)}ms | C: ${jump.contactTime == 0 ? '-1' : jump.contactTime.toStringAsFixed(2)}ms'),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bluetoothProvider.removeListener(_onGlobalPinStateChanged);
    _pinStateSubscription?.cancel();
    _jumpDataSubscription?.cancel();
    _seriesEndSubscription?.cancel();
    _deviceResetSubscription?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medición - ${widget.jumpType}'),
      ),
      body: Column(
        children: [
          // --- NUEVO WIDGET: MENÚ DESPLEGABLE DE PARTICIPANTES ---
          if (widget.session != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField<User>(
                value: _selectedParticipant,
                hint: const Text('Seleccionar participante...'),
                isExpanded: true,
                items: _sessionParticipants.map((User user) {
                  return DropdownMenuItem<User>(
                    value: user,
                    child: Text('${user.firstName} ${user.lastName}'),
                  );
                }).toList(),
                onChanged: _isJumpInProgress ? null : (User? newValue) {
                  setState(() => _selectedParticipant = newValue);
                },
                decoration: const InputDecoration(
                  labelText: 'Atleta',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          
          SizedBox(height: 120, child: Lottie.asset('assets/animations/Animationjump.json', controller: _animationController)),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _buildStatusMessage(),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              onPressed: 
                // --- CAMBIO: Deshabilita si no hay atleta seleccionado ---
                (_isSendingCommand || !_bleRepo.isConnected || (widget.session != null && _selectedParticipant == null))
                  ? null
                  : () {
                      if (_isJumpInProgress) {
                        _stopSeriesCommand();
                      } else {
                        _sendJumpCommand();
                      }
                    }, 
              icon: Icon(_isJumpInProgress ? Icons.stop : Icons.play_arrow, color: Colors.white),
              label: Text(_isJumpInProgress ? 'DETENER SERIE' : 'INICIAR SERIE', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isJumpInProgress ? Colors.red : Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ),
          
          Expanded(child: _buildJumpHistoryList()),
        ],
      ),
    );
  }
}


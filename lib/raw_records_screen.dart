// ARCHIVO DEFINITIVO: lib/raw_records_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'user_provider.dart';
import 'session_provider.dart'; 

class RawRecord {
  final File file;
  final DateTime date;
  final int userID;
  final String userName;
  final int sessionID;
  final String sessionName;
  final String jumpType;
  final String details;

  RawRecord({
    required this.file,
    required this.date,
    required this.userID,
    required this.userName,
    required this.sessionID,
    required this.sessionName,
    required this.jumpType,
    required this.details,
  });
}

class RawRecordsScreen extends StatefulWidget {
  const RawRecordsScreen({super.key});

  @override
  State<RawRecordsScreen> createState() => _RawRecordsScreenState();
}

class _RawRecordsScreenState extends State<RawRecordsScreen> {
  List<RawRecord> _allRecords = [];
  bool _isLoading = true;
  bool _isExporting = false; // Para mostrar un loader mientras armamos el Excel
  
  int _selectedSessionID = -1; 
  int _selectedUserID = -1;    
  String _selectedDate = 'Todas';

  Map<int, String> _availableSessions = {-1: 'Todas las Sesiones'};
  Map<int, String> _availableUsers = {-1: 'Todos los Atletas'};
  List<String> _availableDates = ['Todas'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndParseRecords();
    });
  }

  Future<void> _loadAndParseRecords() async {
    setState(() { _isLoading = true; });
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where(
        (file) => file.path.contains('Metrix_Crudo_') && file.path.endsWith('.csv')
      ).toList();

      final List<RawRecord> parsedRecords = [];
      final Map<int, String> tempSessions = {-1: 'Todas las Sesiones'};
      final Map<int, String> tempUsers = {-1: 'Todos los Atletas'};
      final Set<String> tempDates = {'Todas'};

      for (var file in files) {
        try {
          final lines = await file.readAsLines();
          if (lines.length <= 1) continue; 

          final cols = lines[1].split(',');
          if (cols.length < 5) continue;

          final sId = int.tryParse(cols[0]) ?? 0;
          final uId = int.tryParse(cols[1]) ?? 0;
          final jumpType = cols[2];
          final tfStr = cols[4];
          final recordDate = file.lastModifiedSync();
          final dateString = DateFormat('yyyy-MM-dd').format(recordDate);

          // INNER JOIN Atleta
          String uName = 'Atleta Desconocido (ID: $uId)';
          try {
            final user = userProvider.users.firstWhere((u) => u.uniqueID == uId);
            uName = '${user.firstName} ${user.lastName}';
          } catch (_) {}

          // INNER JOIN Sesión
          String sName = 'Sesión Libre (ID: $sId)';
          try {
            if (sId != 0) {
              final session = sessionProvider.sessions.firstWhere((s) => s.sessionID == sId);
              sName = '${session.name} (${session.place})';
            }
          } catch (_) {}

          tempSessions[sId] = sName;
          tempUsers[uId] = uName;
          tempDates.add(dateString);

          // Calcular Altura para la UI
          String details = '';
          if (tfStr.contains('=')) {
            details = 'Serie Reactiva: ${tfStr.split('=').length} saltos';
          } else {
            double maxTfSec = 0.0;
            for (int i = 1; i < lines.length; i++) {
              final c = lines[i].split(',');
              if (c.length >= 5) {
                final t = (double.tryParse(c[4]) ?? 0) / 1000.0;
                if (t > maxTfSec) maxTfSec = t;
              }
            }
            final maxH = 122.625 * (maxTfSec * maxTfSec);
            if (lines.length == 2) {
              details = 'Altura: ${maxH.toStringAsFixed(2)} cm';
            } else {
              details = '${lines.length - 1} saltos | Máx: ${maxH.toStringAsFixed(2)} cm';
            }
          }

          parsedRecords.add(RawRecord(
            file: file,
            date: recordDate,
            userID: uId,
            userName: uName,
            sessionID: sId,
            sessionName: sName,
            jumpType: jumpType,
            details: details,
          ));
        } catch (e) {
          debugPrint('Error leyendo registro: $e');
        }
      }

      parsedRecords.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allRecords = parsedRecords;
        _availableSessions = tempSessions;
        _availableUsers = tempUsers;
        _availableDates = tempDates.toList()..sort((a, b) => b.compareTo(a)); 
        
        if (!_availableSessions.containsKey(_selectedSessionID)) _selectedSessionID = -1;
        if (!_availableUsers.containsKey(_selectedUserID)) _selectedUserID = -1;
        if (!_availableDates.contains(_selectedDate)) _selectedDate = 'Todas';
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint('Error general al cargar: $e');
    }
  }

  List<RawRecord> get _filteredRecords {
    return _allRecords.where((r) {
      final dateString = DateFormat('yyyy-MM-dd').format(r.date);
      final matchSession = _selectedSessionID == -1 || r.sessionID == _selectedSessionID;
      final matchUser = _selectedUserID == -1 || r.userID == _selectedUserID;
      final matchDate = _selectedDate == 'Todas' || dateString == _selectedDate;
      return matchSession && matchUser && matchDate;
    }).toList();
  }

  Future<void> _deleteRecord(RawRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Salto'),
        content: Text('¿Eliminar de forma permanente el salto de ${record.userName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await record.file.delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salto eliminado.')));
        _loadAndParseRecords(); 
      } catch (e) {
        debugPrint('Error al eliminar: $e');
      }
    }
  }

  // --- NUEVA LÓGICA DE EXPORTACIÓN ENRIQUECIDA ---
  Future<void> _shareEnrichedRecords(List<RawRecord> recordsToShare) async {
    if (recordsToShare.isEmpty) return;

    setState(() { _isExporting = true; });

    try {
      final tempDir = await getTemporaryDirectory();
      final exportFile = File('${tempDir.path}/Bitacora_MetriX_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
      
      // Armamos un encabezado hermoso y entendible para Excel
      String csvContent = 'Fecha,Hora,Sesion,Atleta,Tipo Salto,Num Salto,Tiempo Contacto(ms),Tiempo Vuelo(ms),Altura(cm)\n';

      for (var record in recordsToShare) {
        final lines = await record.file.readAsLines();
        if (lines.length <= 1) continue;

        // Limpiamos comas de los nombres para no romper las columnas del CSV
        final cleanSession = record.sessionName.replaceAll(',', '');
        final cleanUser = record.userName.replaceAll(',', '');

        for (int i = 1; i < lines.length; i++) {
          final cols = lines[i].split(',');
          if (cols.length < 5) continue;

          final jumpType = cols[2];
          final tcStr = cols[3];
          final tfStr = cols[4];
          
          // El Timestamp suele estar en la columna 5, si no, usamos la fecha del archivo
          final timestamp = cols.length > 5 && cols[5].isNotEmpty 
              ? cols[5] 
              : DateFormat('yyyy-MM-dd HH:mm:ss').format(record.date);
          
          final dtParts = timestamp.split(' ');
          final dDate = dtParts[0];
          final dTime = dtParts.length > 1 ? dtParts[1] : '';

          // Si es una serie múltiple (tiene símbolos "="), la separamos en filas individuales
          if (tfStr.contains('=')) {
            final tcs = tcStr.split('=');
            final tfs = tfStr.split('=');

            for (int j = 0; j < tfs.length; j++) {
              final tc = j < tcs.length ? tcs[j] : '0';
              final tf = tfs[j];
              
              final tfSec = (double.tryParse(tf) ?? 0.0) / 1000.0;
              final heightCm = 122.625 * (tfSec * tfSec); // Cálculo matemático de Altura

              csvContent += '$dDate,$dTime,$cleanSession,$cleanUser,$jumpType,${j+1},$tc,$tf,${heightCm.toStringAsFixed(2)}\n';
            }
          } else {
            // Si es un salto simple
            final tfSec = (double.tryParse(tfStr) ?? 0.0) / 1000.0;
            final heightCm = 122.625 * (tfSec * tfSec); // Cálculo matemático de Altura

            csvContent += '$dDate,$dTime,$cleanSession,$cleanUser,$jumpType,1,$tcStr,$tfStr,${heightCm.toStringAsFixed(2)}\n';
          }
        }
      }

      await exportFile.writeAsString(csvContent);

      String shareText = 'Bitácora Metri-X\n';
      if (_selectedSessionID != -1) shareText += 'Sesión: ${_availableSessions[_selectedSessionID]}\n';
      if (_selectedUserID != -1) shareText += 'Atleta: ${_availableUsers[_selectedUserID]}\n';
      if (_selectedDate != 'Todas') shareText += 'Fecha: $_selectedDate\n';

      setState(() { _isExporting = false; });
      await Share.shareXFiles([XFile(exportFile.path)], text: shareText.trim());

    } catch (e) {
      setState(() { _isExporting = false; });
      debugPrint('Error exportando bitácora enriquecida: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }
  // ----------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentRecords = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora Cruda (Avanzada)'),
        backgroundColor: const Color(0xFF3d5a80),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isExporting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.ios_share),
            tooltip: 'Exportar ${currentRecords.length} registros visibles',
            onPressed: (currentRecords.isEmpty || _isExporting) 
              ? null 
              : () => _shareEnrichedRecords(currentRecords), // Llama a la exportación en masa
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PANEL DE FILTROS
                Container(
                  color: Colors.grey.shade100,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 16.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      if (_availableSessions.length > 1)
                        DropdownButton<int>(
                          value: _selectedSessionID,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.event_note, size: 18),
                          items: _availableSessions.entries.map((entry) {
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedSessionID = val ?? -1),
                        ),
                      if (_availableUsers.length > 1)
                        DropdownButton<int>(
                          value: _selectedUserID,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.person, size: 18),
                          items: _availableUsers.entries.map((entry) {
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedUserID = val ?? -1),
                        ),
                      if (_availableDates.length > 1)
                        DropdownButton<String>(
                          value: _selectedDate,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.calendar_today, size: 18),
                          items: _availableDates.map((date) {
                            return DropdownMenuItem<String>(
                              value: date,
                              child: Text(date),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDate = val ?? 'Todas'),
                        ),
                    ],
                  ),
                ),

                // LISTA DE RESULTADOS
                Expanded(
                  child: currentRecords.isEmpty
                    ? const Center(child: Text('No hay coincidencias para estos filtros.'))
                    : RefreshIndicator(
                        onRefresh: _loadAndParseRecords,
                        child: ListView.builder(
                          itemCount: currentRecords.length,
                          itemBuilder: (context, index) {
                            final record = currentRecords[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF3d5a80).withOpacity(0.1),
                                  child: Text(
                                    record.jumpType, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3d5a80), fontSize: 12)
                                  ),
                                ),
                                title: Text(record.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(record.details, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '🏟️ ${record.sessionName}', 
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)
                                      ),
                                      Text(
                                        '🕒 ${DateFormat('dd/MM/yyyy HH:mm').format(record.date)}', 
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                                      ),
                                    ],
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.blue, size: 22),
                                      // Llama a la exportación para este único archivo
                                      onPressed: () => _shareEnrichedRecords([record]), 
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                      onPressed: () => _deleteRecord(record),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                ),
              ],
            ),
    );
  }
}
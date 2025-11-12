// ARCHIVO NUEVO: lib/session_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'session_model.dart';

class SessionProvider extends ChangeNotifier {
  List<Session> _sessions = [];
  int _nextSessionId = 1; // Las sesiones empiezan con ID 1
  bool _isLoading = true;

  List<Session> get sessions => _sessions;
  bool get isLoading => _isLoading;

  SessionProvider() {
    loadSessions();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/chronojump_sessions.csv');
  }

  Future<void> loadSessions() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final contents = await file.readAsString();
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);

      _sessions.clear();
      // Empezamos desde 1 para saltar la fila de encabezado
      for (var i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        if (row.length >= 5) {
            _sessions.add(Session.fromList(row));
        }
      }
      
      // Ordenar por fecha, de la más reciente a la más antigua
      _sessions.sort((a, b) => b.ts.compareTo(a.ts));

      if (_sessions.isNotEmpty) {
        _nextSessionId = _sessions.map((s) => s.sessionID).reduce((a, b) => a > b ? a : b) + 1;
      } else {
        _nextSessionId = 1;
      }

    } catch (e) {
      print("Error al cargar sesiones: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSessions() async {
    try {
      final file = await _localFile;
      List<List<dynamic>> rows = [];
      // Encabezado
      rows.add(["SessionID", "Name", "Place", "Ts", "Comment"]);
      // Datos
      for (var session in _sessions) {
        rows.add(session.toList());
      }
      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);
    } catch (e) {
      print("Error al guardar sesiones: $e");
    }
  }

  void addSession({
    required String name,
    required String place,
    String comment = '',
  }) {
    final newSession = Session(
      sessionID: _nextSessionId,
      name: name,
      place: place,
      ts: DateTime.now(), // El timestamp se crea aquí
      comment: comment,
    );
    _sessions.insert(0, newSession); // Inserta al principio para que aparezca primero
    _nextSessionId++;
    _saveSessions();
    notifyListeners();
  }

  void deleteSession(int sessionID) {
    _sessions.removeWhere((session) => session.sessionID == sessionID);
    _saveSessions();
    notifyListeners();
  }

  void updateSession(Session updatedSession) {
    final index = _sessions.indexWhere((session) => session.sessionID == updatedSession.sessionID);
    if (index != -1) {
      updatedSession.ts = DateTime.now(); // Actualiza el timestamp al editar
      _sessions[index] = updatedSession;
      _sessions.sort((a, b) => b.ts.compareTo(a.ts)); // Re-ordena la lista
      _saveSessions();
      notifyListeners();
    }
  }
}
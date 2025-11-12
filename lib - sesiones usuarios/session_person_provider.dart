// ARCHIVO MODIFICADO: lib/session_person_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

// Se importa el modelo de datos del vínculo y el modelo de persona
import 'session_person_link.dart';
import 'user_model.dart';

class SessionPersonProvider extends ChangeNotifier {
  List<SessionPersonLink> _links = [];
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  SessionPersonProvider() {
    loadLinks();
  }

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/chronojump_session_people.csv');
  }

  Future<void> loadLinks() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      final contents = await file.readAsString();
      final rows = const CsvToListConverter().convert(contents);
      _links.clear();
      
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        // --- CAMBIO: Se leen 3 columnas ---
        if (row.length >= 3) {
          final sessionID = int.tryParse(row[0].toString());
          final personID = int.tryParse(row[1].toString());
          final personName = row[2].toString(); // El nombre también se lee
          if (sessionID != null && personID != null) {
            _links.add(SessionPersonLink(
              sessionID: sessionID,
              personUniqueID: personID,
              personName: personName,
            ));
          }
        }
      }
    } catch (e) {
      print('Error cargando los vínculos sesión-persona: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLinks() async {
    try {
      final file = await _localFile;
      // --- CAMBIO: El encabezado y los datos ahora tienen 3 columnas ---
      List<List<dynamic>> rows = [['SessionID', 'UniqueID', 'Name']];
      for (var link in _links) {
        rows.add([link.sessionID, link.personUniqueID, link.personName]);
      }
      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);
    } catch (e) {
      print('Error guardando los vínculos sesión-persona: $e');
    }
  }

  bool isPersonInSession(int sessionID, int personID) {
    return _links.any((link) => link.sessionID == sessionID && link.personUniqueID == personID);
  }

  // --- CAMBIO: El método ahora recibe un objeto User completo para tener el nombre ---
  Future<void> togglePersonInSession(int sessionID, User person) async {
    final personFullName = '${person.firstName} ${person.lastName}';
    final index = _links.indexWhere((link) => link.sessionID == sessionID && link.personUniqueID == person.uniqueID);

    if (index != -1) {
      // Si la persona existe, se elimina
      _links.removeAt(index);
    } else {
      // Si no existe, se agrega con su nombre completo
      _links.add(SessionPersonLink(
        sessionID: sessionID,
        personUniqueID: person.uniqueID,
        personName: personFullName,
      ));
    }
    await _saveLinks();
    notifyListeners();
  }

  // Nuevo método para obtener la lista de personas (objetos User) para una sesión
  List<User> getPeopleForSession(int sessionID, List<User> allPeople) {
    final peopleIDs = _links
        .where((link) => link.sessionID == sessionID)
        .map((link) => link.personUniqueID)
        .toSet(); // Usar un Set para búsquedas más eficientes

    if (peopleIDs.isEmpty) return [];

    return allPeople.where((person) => peopleIDs.contains(person.uniqueID)).toList();
  }
}
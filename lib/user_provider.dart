// ARCHIVO ACTUALIZADO: lib/user_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'user_model.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert'; // Para el encoding UTF-8
import 'dart:math';

class UserProvider extends ChangeNotifier {
  List<User> _users = [];
  int _nextUniqueId = 0;
  final _uuid = Uuid();
  bool _isLoading = true;

  // Getters
  List<User> get users => _users;
  bool get isLoading => _isLoading;

  // Constructor: Carga los usuarios al iniciar la app
  UserProvider() {
    loadUsers();
  }

  // --- LÓGICA DE PERSISTENCIA (GUARDADO Y CARGA) ---

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/chronojump_users.csv');
  }


// --- COMIENZA EL CÓDIGO A AGREGAR ---

// FUNCIÓN DE IMPORTACIÓN
// En el archivo: user_provider.dart

// En el archivo: user_provider.dart
// No olvides añadir 'import 'dart:math';' y 'import 'package:flutter/foundation.dart';' al principio del archivo.

Future<int> importUsers() async {
  try {
    debugPrint("--- INICIANDO PROCESO DE IMPORTACIÓN (FORMATO PERSONALIZADO) ---");
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (resultado == null || resultado.files.single.path == null) {
      debugPrint("--- IMPORTACIÓN CANCELADA POR EL USUARIO ---");
      return -1;
    }

    final archivo = File(resultado.files.single.path!);
    var contenido = await archivo.readAsString(encoding: utf8);
    debugPrint("Archivo seleccionado y leído correctamente.");

    if (contenido.startsWith('\uFEFF')) {
      contenido = contenido.substring(1);
      debugPrint("Carácter BOM detectado y eliminado.");
    }

    final String contenidoNormalizado = contenido.replaceAll('\r\n', '\n');
    List<List<dynamic>> filasComoLista = const CsvToListConverter(eol: '\n').convert(contenidoNormalizado);
    debugPrint("Archivo convertido a lista. Total de filas (incluyendo encabezado): ${filasComoLista.length}");

    final Set<int> existingUniqueIDs = _users.map((u) => u.uniqueID).toSet();
    debugPrint("Total de usuarios existentes en la app: ${existingUniqueIDs.length}. IDs: $existingUniqueIDs");
    
    int usuariosAgregados = 0;

    for (var i = 1; i < filasComoLista.length; i++) {
      final fila = filasComoLista[i];
      debugPrint("\n[Procesando Fila #${i}]: $fila");

      if (fila.length >= 6) {
        debugPrint(" -> OK: La fila tiene ${fila.length} columnas.");
        
        // --- CAMBIO: Se aplica la nueva lógica de mapeo ---
        final uniqueID = int.tryParse(fila[0].toString());

        if (uniqueID == null) {
          debugPrint(" -> ERROR: El ID '${fila[0]}' no es un número válido. Se ignora la fila.");
          continue;
        }

        debugPrint(" -> OK: El ID parseado es $uniqueID.");

        if (existingUniqueIDs.contains(uniqueID)) {
          debugPrint(" -> ERROR: El ID $uniqueID ya existe. Se ignora la fila.");
        } else {
          debugPrint(" -> ¡ÉXITO! Usuario nuevo. Se va a agregar.");
          
          // --- CAMBIO: Se reasignan las columnas según tus reglas ---
          
          // 1. Unir MUUID_m (columna 2) y MUUID_id (columna 3)
          final String muuidCombinado = '${fila[1]}-${fila[2]}';
          
          // 2. Asignar el resto de las columnas y la descripción fija
          final user = User(
            uniqueID: uniqueID,
            muuid: muuidCombinado,
            firstName: fila[3].toString().trim(),     // NameFirst (columna 4)
            lastName: fila[4].toString().trim(),      // NameLast (columna 5)
            sex: fila[5].toString().trim(),           // Sex (columna 6)
            descripcion: "importado de Chronojump", // Descripción fija
          );
          
          _users.add(user);
          usuariosAgregados++;
        }
      } else {
        debugPrint(" -> ERROR: La fila solo tiene ${fila.length} columnas (se necesitan >= 6). Se ignora la fila.");
      }
    }

    debugPrint("\n--- PROCESO FINALIZADO ---");
    debugPrint("Total de usuarios nuevos agregados: $usuariosAgregados");

    if (usuariosAgregados > 0) {
      await _saveUsers();
      notifyListeners(); // Notifica a la UI que la lista de usuarios ha cambiado
      debugPrint("Usuarios guardados en el archivo.");
    }
    return usuariosAgregados;

  } catch (e) {
    debugPrint("--- ERROR CATASTRÓFICO EN LA IMPORTACIÓN: $e ---");
    return -2;
  }
}
  Future<void> loadUsers() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final contents = await file.readAsString();
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);
      
      _users.clear();
      // Empezamos desde 1 para saltar la fila de encabezado
      for (var i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        final user = User(
          uniqueID: int.parse(row[0].toString()),
          muuid: row[1].toString(),
          firstName: row[2].toString(),
          lastName: row[3].toString(),
          sex: row[4].toString(),
          descripcion: row[5].toString(),
        );
        _users.add(user);
      }

      // Actualizar el siguiente ID único
      if (_users.isNotEmpty) {
        _nextUniqueId = _users.map((u) => u.uniqueID).reduce((a, b) => a > b ? a : b) + 1;
      }

    } catch (e) {
      print("Error al cargar usuarios: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveUsers() async {
    try {
      final file = await _localFile;
      List<List<dynamic>> rows = [];
      // Encabezado
      rows.add(["uniqueID", "muuid", "firstName", "lastName", "sex", "description"]);
      // Datos
      for (var user in _users) {
        rows.add(user.toList());
      }
      String csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);
    } catch (e) {
      print("Error al guardar usuarios: $e");
    }
  }

  // --- GESTIÓN DE USUARIOS (Ahora con guardado automático) ---

  void addUser({
    required String firstName,
    required String lastName,
    String sex = 'U',
    String description = '',
  }) {
    final newUser = User(
      uniqueID: _nextUniqueId,
      muuid: _uuid.v4().hashCode.toString(),
      firstName: firstName,
      lastName: lastName,
      sex: sex,
      descripcion: description,
    );
    _users.add(newUser);
    _nextUniqueId++;
    _saveUsers(); // Guarda los cambios
    notifyListeners();
  }

  void deleteUser(int uniqueID) {
    _users.removeWhere((user) => user.uniqueID == uniqueID);
    _saveUsers(); // Guarda los cambios
    notifyListeners();
  }

  void updateUser(User updatedUser) {
    final index = _users.indexWhere((user) => user.uniqueID == updatedUser.uniqueID);
    if (index != -1) {
      _users[index] = updatedUser;
      _saveUsers(); // Guarda los cambios
      notifyListeners();
    }
  }

  // --- FUNCIÓN DE EXPORTACIÓN ---

  Future<void> exportUsers(BuildContext context) async {
    // Asegurarse de que el archivo esté actualizado
    await _saveUsers();
    
    final file = await _localFile;
    if (await file.exists()) {
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile], 
        text: 'Archivo de usuarios de ChronoJump.',
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuarios para exportar.')),
      );
    }
  }
}
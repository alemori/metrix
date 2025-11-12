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
Future<int> importUsers() async {
  int usuariosAgregados = 0;
  
  try {
    // 1. Abrir el selector de archivos
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (resultado != null && resultado.files.single.path != null) {
      final rutaDelArchivo = resultado.files.single.path!;
      final archivo = File(rutaDelArchivo);

      // 2. Leer el contenido del archivo
      final contenido = await archivo.readAsString(encoding: utf8);
      
      // 3. Procesar el CSV
      List<List<dynamic>> filasComoLista = const CsvToListConverter().convert(contenido);

      // Creamos un set con los IDs existentes para una búsqueda más rápida
      final Set<int> existingUniqueIDs = _users.map((u) => u.uniqueID).toSet();

      // 4. Recorrer las filas, validar y agregar
      // Empezamos en 1 para saltar el encabezado
      for (var i = 1; i < filasComoLista.length; i++) {
        final fila = filasComoLista[i];

        if (fila.length >= 6) {
          final uniqueID = int.tryParse(fila[0].toString());
          
          // Si el ID es válido y NO existe en nuestra lista actual...
          if (uniqueID != null && !existingUniqueIDs.contains(uniqueID)) {
            final user = User(
              uniqueID: uniqueID,
              muuid: fila[1].toString(),
              firstName: fila[2].toString(),
              lastName: fila[3].toString(),
              sex: fila[4].toString(),
              descripcion: fila[5].toString(),
            );
            _users.add(user);
            usuariosAgregados++;
          }
        }
      }

      // Si se agregó al menos un usuario, actualizamos el siguiente ID y guardamos
      if (usuariosAgregados > 0) {
        // 5. Guardar los cambios
        if (_users.isNotEmpty) {
           _nextUniqueId = _users.map((u) => u.uniqueID).reduce((a, b) => a > b ? a : b) + 1;
        }
        await _saveUsers();
        
        // 6. Notificar a la interfaz
        notifyListeners();
      }
    }
  } catch (e) {
    print("Error al importar usuarios: $e");
    return -1; // Devolvemos -1 para indicar un error
  }
  
  // 7. Devolver el resultado
  return usuariosAgregados;
}

// --- TERMINA EL CÓDIGO A AGREGAR ---



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
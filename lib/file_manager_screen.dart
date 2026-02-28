import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'export_service.dart';
import 'user_provider.dart';
import 'settings_provider.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});
  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<File> _csvFiles = [];
  Set<File> _selectedFiles = {}; // <-- NUEVO: Guarda los archivos seleccionados
  bool _isLoading = true;
  final ExportService _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() { _isLoading = true; });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final csvFiles = files.whereType<File>().where((file) => file.path.endsWith('.csv')).toList();
      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      setState(() {
        _csvFiles = csvFiles;
        // Limpiamos selecciones viejas si se recarga la lista
        _selectedFiles.removeWhere((file) => !csvFiles.any((c) => c.path == file.path));
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar archivos: $e')));
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "${file.path.split('/').last}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        setState(() {
          _selectedFiles.remove(file); // <-- NUEVO: Lo sacamos de la selección si lo borramos
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo eliminado.')));
        }
        _loadFiles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  String _formatFileName(String path) {
    try {
      final name = path.split('/').last;
      if (name.contains("Metrix_Crudo_")) {
        final dateTimeString = name.replaceAll('Metrix_Crudo_', '').replaceAll('.csv', '');
        final parts = dateTimeString.split('_');
        final timeFormatted = parts[1].replaceAll('-', ':');
        return 'Test: $timeFormatted hs';
      }
      return name;
    } catch (e) {
      return path.split('/').last;
    }
  }
// --- NUEVA FUNCIÓN: Borra todos los archivos seleccionados ---
  Future<void> _deleteMultipleSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Múltiples Archivos'),
        content: Text('¿Estás seguro de que quieres eliminar ${_selectedFiles.length} archivos de forma permanente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar Todos', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int borrados = 0;
      for (var file in _selectedFiles.toList()) {
        try {
          if (await file.exists()) {
            await file.delete();
            borrados++;
          }
        } catch (e) {
          debugPrint("Error al borrar ${file.path}: $e");
        }
      }

      setState(() {
        _selectedFiles.clear(); // Limpiamos la selección
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$borrados archivos eliminados correctamente.'))
        );
      }
      
      _loadFiles(); // Recargamos la lista
    }
  }
  // --- NUEVA FUNCIÓN: Fusiona y Exporta los seleccionados ---
  Future<void> _exportMultipleSelected(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    List<String> lineasCombinadas = [];
    bool esElPrimerArchivo = true;

    try {
      for (var file in _selectedFiles) {
        final lineas = await file.readAsLines();
        if (lineas.isEmpty) continue;

        if (esElPrimerArchivo) {
          // Al primer archivo le respetamos el encabezado
          lineasCombinadas.addAll(lineas);
          esElPrimerArchivo = false;
        } else {
          // A los demás archivos les volamos la línea 0 (el encabezado)
          if (lineas.length > 1) {
            lineasCombinadas.addAll(lineas.sublist(1));
          }
        }
      }

      if (lineasCombinadas.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos válidos para exportar.')));
        return;
      }

      // Creamos archivo temporal gigante
      final directory = await getApplicationDocumentsDirectory();
      final tempFile = File('${directory.path}/Metrix_Exportacion_Masiva_${DateTime.now().millisecondsSinceEpoch}.csv');
      await tempFile.writeAsString(lineasCombinadas.join('\n'));

      // Exportamos
      await _exportService.smartExportToChronojumpFormat(
        sourceFile: tempFile,
        allUsers: userProvider.users,
        context: context,
        format: settingsProvider.exportFormat,
      );

      // Limpiamos selecciones
      setState(() {
        _selectedFiles.clear();
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar múltiples: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        // Si hay seleccionados, muestra cuántos. Si no, muestra el título normal.
        title: _selectedFiles.isNotEmpty
            ? Text('${_selectedFiles.length} seleccionados')
            : const Text('Archivos Guardados'),
        // Cambia de color si estás en modo selección (opcional)
        backgroundColor: _selectedFiles.isNotEmpty ? Colors.blueGrey : null,
        actions: [
          // --- NUEVO BOTÓN: Borrar Seleccionados ---
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteMultipleSelected,
              tooltip: 'Borrar seleccionados',
            ),
          // ----------------------------------------

          // Tu botón actual de Seleccionar / Deseleccionar Todos
          IconButton(
            icon: Icon(
              _selectedFiles.length == _csvFiles.length && _csvFiles.isNotEmpty
                  ? Icons.deselect
                  : Icons.select_all
            ),
            onPressed: () {
              setState(() {
                if (_selectedFiles.length == _csvFiles.length) {
                  _selectedFiles.clear();
                } else {
                  _selectedFiles.addAll(_csvFiles);
                }
              });
            },
            tooltip: 'Seleccionar / Deseleccionar Todos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _csvFiles.isEmpty
              ? const Center(child: Text('No hay archivos guardados.'))
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    itemCount: _csvFiles.length,
                    itemBuilder: (context, index) {
                      final file = _csvFiles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          // --- NUEVO: Checkbox a la izquierda ---
                          leading: Checkbox(
                            value: _selectedFiles.contains(file),
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedFiles.add(file);
                                } else {
                                  _selectedFiles.remove(file);
                                }
                              });
                            },
                          ),
                          title: Text(_formatFileName(file.path)),
                          subtitle: Text(file.path.split('/').last),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.send_and_archive, color: Colors.teal),
                                onPressed: () {
                                  _exportService.smartExportToChronojumpFormat(
                                    sourceFile: file,
                                    allUsers: userProvider.users,
                                    context: context,
                                    format: settingsProvider.exportFormat,
                                  );
                                },
                                tooltip: 'Traducir y Enviar a Chronojump',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteFile(file),
                                tooltip: 'Eliminar Test',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      // --- NUEVO: Botón Flotante para exportar en masa ---
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _exportMultipleSelected(context),
              label: Text('Exportar ${_selectedFiles.length}'),
              icon: const Icon(Icons.send_and_archive),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
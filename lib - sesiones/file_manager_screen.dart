// ARCHIVO NUEVO: file_manager_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<File> _csvFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // Carga los archivos .csv del directorio de la app
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      final csvFiles = files
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      // Ordena los archivos por fecha, del más reciente al más antiguo
      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      setState(() {
        _csvFiles = csvFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar archivos: $e')),
      );
    }
  }

  // Comparte un archivo específico
  Future<void> _shareFile(File file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Archivo de datos de ChronoJump');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  // Elimina un archivo, pidiendo confirmación primero
  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar el archivo "${file.path.split('/').last}"? Esta acción no se puede deshacer.'),
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

    if (confirmed == true) {
      try {
        await file.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo eliminado con éxito.')),
        );
        // Recarga la lista de archivos para reflejar el cambio
        _loadFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el archivo: $e')),
        );
      }
    }
  }
  
  // Formatea el nombre del archivo para que sea más legible
  String _formatFileName(String path) {
    try {
      final name = path.split('/').last;
      // Extrae la fecha del nombre del archivo, ej: Chronojump_saltos_2025-08-26.csv
      final dateString = name.split('_').last.replaceAll('.csv', '');
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      // Devuelve un formato más amigable, ej: "Martes, 26 de agosto de 2025"
      return DateFormat.yMMMMEEEEd('es').format(date);
    } catch (e) {
      // Si el formato no es el esperado, devuelve el nombre original
      return path.split('/').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivos Guardados'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _csvFiles.isEmpty
              ? const Center(
                  child: Text(
                    'No hay archivos de saltos guardados.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.builder(
                    itemCount: _csvFiles.length,
                    itemBuilder: (context, index) {
                      final file = _csvFiles[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined, color: Colors.blueGrey),
                          title: Text(_formatFileName(file.path)),
                          subtitle: Text(file.path.split('/').last),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.blue),
                                onPressed: () => _shareFile(file),
                                tooltip: 'Compartir',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteFile(file),
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
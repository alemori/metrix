import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'export_service.dart';
import 'user_provider.dart';
// En lib/file_manager_screen.dart
import 'settings_provider.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});
  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  List<File> _csvFiles = [];
  bool _isLoading = true;
  final ExportService _exportService = ExportService(); // <-- LÍNEA EN SU LUGAR CORRECTO

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
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar archivos: $e')));
      }
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Archivo de datos de ChronoJump');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
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
      if (name.contains("Chronojump_saltos_") || name.contains("Export_")) {
        final dateString = name.split('_').last.replaceAll('.csv', '');
        final date = DateFormat('yyyy-MM-dd').parse(dateString);
        final formattedDate = DateFormat.yMMMMEEEEd('es').format(date);

        if (name.contains('Export_Simple')) { return 'Export. Simple ($formattedDate)'; }
        else if (name.contains('Export_MultiJump')) { return 'Export. Múltiple ($formattedDate)'; }
        else if (name.contains('Chronojump_saltos')) { return 'Registro Diario ($formattedDate)'; }
      }
      return name;
    } catch (e) {
      return path.split('/').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
 final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Archivos Guardados')),
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
                          leading: const Icon(Icons.description_outlined, color: Colors.blueGrey),
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
    // --- AÑADE ESTA LÍNEA ---
    format: settingsProvider.exportFormat,
  );
},
                                tooltip: 'Exportar para Chronojump',
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, color: Colors.blue),
                                onPressed: () => _shareFile(file),
                                tooltip: 'Compartir (Original)',
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
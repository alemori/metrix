// ARCHIVO NUEVO: lib/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Definimos un 'enum' para que el código sea más legible y seguro.
// En lugar de usar strings como "latino", usaremos ExportFormat.LATIN.
enum ExportFormat { LATIN, NON_LATIN }

class SettingsProvider extends ChangeNotifier {
  
  // --- PROPIEDADES ---

  // Clave que usaremos para guardar el dato en el dispositivo.
  static const _formatKey = 'export_format';
  
  // La preferencia actual. Por defecto, será LATIN.
  ExportFormat _exportFormat = ExportFormat.LATIN;
  
  // Getter público para que el resto de la app pueda leer la preferencia actual.
  ExportFormat get exportFormat => _exportFormat;

  // --- CONSTRUCTOR ---

  // Cuando se crea el SettingsProvider, automáticamente intenta cargar la preferencia guardada.
  SettingsProvider() {
    loadSettings();
  }

  // --- MÉTODOS ---

  /// Carga la preferencia de formato desde el almacenamiento del dispositivo.
  Future<void> loadSettings() async {
    // Obtenemos la instancia de SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    
    // Leemos el valor guardado como un String. Si no hay nada, usamos 'LATIN' por defecto.
    final formatString = prefs.getString(_formatKey) ?? 'LATIN';
    
    // Convertimos el String guardado a nuestro tipo de dato 'ExportFormat'.
    _exportFormat = (formatString == 'NON_LATIN') ? ExportFormat.NON_LATIN : ExportFormat.LATIN;
    
    // Notificamos a cualquier widget que esté escuchando que la data se cargó.
    notifyListeners();
  }

  /// Guarda la nueva preferencia de formato en el dispositivo.
  Future<void> setExportFormat(ExportFormat newFormat) async {
    // Si el nuevo formato es el mismo que ya teníamos, no hacemos nada.
    if (_exportFormat == newFormat) return;

    // Actualizamos el valor en nuestra clase.
    _exportFormat = newFormat;
    
    // Notificamos a los widgets que el valor ha cambiado para que se redibujen.
    notifyListeners();
    
    // Guardamos el nuevo valor en el almacenamiento del dispositivo.
    final prefs = await SharedPreferences.getInstance();
    // Guardamos el enum como un String (ej: "ExportFormat.LATIN" -> "LATIN")
    prefs.setString(_formatKey, newFormat.name);
  }
}
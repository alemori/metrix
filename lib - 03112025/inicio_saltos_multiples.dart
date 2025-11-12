import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ble_notifications_screen.dart';
import 'user_model.dart';

class InicioSaltosMultiples extends StatefulWidget {
  final int? sessionID;
  final User? person;

  const InicioSaltosMultiples({
    super.key,
    this.sessionID,
    this.person,
  });

  @override
  State<InicioSaltosMultiples> createState() => _InicioSaltosMultiplesState();
}

enum LimiteOpcion { saltos, tiempo, sinLimite }

class _InicioSaltosMultiplesState extends State<InicioSaltosMultiples> {
  LimiteOpcion _limiteSeleccionado = LimiteOpcion.sinLimite;
  final TextEditingController _cantidadSaltosController = TextEditingController();
  final TextEditingController _tiempoLimiteController = TextEditingController();
  final TextEditingController _pesoExtraController = TextEditingController();
  bool _comienzaDesdeAdentro = true;
  bool _ultimoSaltoCompleto = true;

  // --- AÑADIDO: Controladores para los nuevos campos ---
  final TextEditingController _alturaCaidaController = TextEditingController(text: '0');
  final TextEditingController _pesoPersonaController = TextEditingController();
  final TextEditingController _alturaPersonaController = TextEditingController();

  @override
  void dispose() {
    _cantidadSaltosController.dispose();
    _tiempoLimiteController.dispose();
    _pesoExtraController.dispose();
    // --- AÑADIDO: Dispose para los nuevos controladores ---
    _alturaCaidaController.dispose();
    _pesoPersonaController.dispose();
    _alturaPersonaController.dispose();
    super.dispose();
  }

  void _aceptarConfiguracion() {
    if (_limiteSeleccionado == LimiteOpcion.saltos && _cantidadSaltosController.text.isEmpty) {
      _mostrarSnackBar('Por favor, ingresa la cantidad de saltos.');
      return;
    }
    if (_limiteSeleccionado == LimiteOpcion.tiempo && _tiempoLimiteController.text.isEmpty) {
      _mostrarSnackBar('Por favor, ingresa el tiempo límite en segundos.');
      return;
    }

    int limiteSaltos = int.tryParse(_cantidadSaltosController.text) ?? 0;
    int limiteTiempo = int.tryParse(_tiempoLimiteController.text) ?? 0;
    double pesoExtra = double.tryParse(_pesoExtraController.text) ?? 0.0;

    // --- AÑADIDO: Parseo de los nuevos valores ---
    final double alturaCaida = double.tryParse(_alturaCaidaController.text) ?? 0.0;
    final double pesoPersona = double.tryParse(_pesoPersonaController.text) ?? 0.0;
    final int alturaPersona = int.tryParse(_alturaPersonaController.text) ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BleNotificationsScreen(
          sessionID: widget.sessionID,
          person: widget.person,
          jumpType: "MULTI",
          limiteSaltos: limiteSaltos,
          limiteTiempo: limiteTiempo,
          comienzaDesdeAdentro: _comienzaDesdeAdentro,
          pesoExtra: pesoExtra,
          ultimoSaltoCompleto: _ultimoSaltoCompleto,
          // --- AÑADIDO: Se envían los nuevos datos ---
          alturaCaida: alturaCaida,
          pesoPersona: pesoPersona,
          alturaPersona: alturaPersona,
        ),
      ),
    );
  }

  void _cancelar() {
    Navigator.pop(context);
  }

  void _mostrarSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- CAMBIO AQUÍ ---
        title: Text(
          // 2. MUEVE EL '\n':
          // Colócalo donde quieras que se corte el texto
          'Configuración de\nSaltos Múltiples', 
          
          // 3. MANTÉN ESTA LÍNEA:
          // Centra las dos líneas de texto una respecto a la otra
          textAlign: TextAlign.center, 
         // --- AÑADE ESTA SECCIÓN ---
          style: TextStyle(
            fontSize: 18.0, // <-- Prueba con 18.0 o 16.0
          ),
          // ---------------------------
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECCIÓN ORIGINAL: Límite por ---
              Text(
                'Límite por:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RadioListTile<LimiteOpcion>(
                title: const Text('Saltos', style: TextStyle(fontSize: 15.0)),
                value: LimiteOpcion.saltos,
                groupValue: _limiteSeleccionado,
                onChanged: (LimiteOpcion? value) {
                  setState(() { _limiteSeleccionado = value!; });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _cantidadSaltosController,
                  keyboardType: TextInputType.number,
                  enabled: _limiteSeleccionado == LimiteOpcion.saltos,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de saltos',
                    border: OutlineInputBorder(), isDense: true,
                  ),
                ),
              ),
              RadioListTile<LimiteOpcion>(
                title: const Text('Tiempo (segundos)', style: TextStyle(fontSize: 15.0)),
                value: LimiteOpcion.tiempo,
                groupValue: _limiteSeleccionado,
                onChanged: (LimiteOpcion? value) {
                  setState(() { _limiteSeleccionado = value!; });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _tiempoLimiteController,
                  keyboardType: TextInputType.number,
                  enabled: _limiteSeleccionado == LimiteOpcion.tiempo,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Tiempo límite en segundos',
                    border: OutlineInputBorder(), isDense: true,
                  ),
                ),
              ),
              RadioListTile<LimiteOpcion>(
                title: const Text('Sin límite', style: TextStyle(fontSize: 15.0)),
                value: LimiteOpcion.sinLimite,
                groupValue: _limiteSeleccionado,
                onChanged: (LimiteOpcion? value) {
                  setState(() { _limiteSeleccionado = value!; });
                },
              ),
              const SizedBox(height: 15),

              // --- SECCIÓN ORIGINAL: Comienza desde ---
              Text(
                'Comienza desde:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Adentro', style: TextStyle(fontSize: 15.0)),
                      value: true,
                      groupValue: _comienzaDesdeAdentro,
                      onChanged: (bool? value) {
                        setState(() { _comienzaDesdeAdentro = value!; });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Afuera', style: TextStyle(fontSize: 15.0)),
                      value: false,
                      groupValue: _comienzaDesdeAdentro,
                      onChanged: (bool? value) {
                        setState(() { _comienzaDesdeAdentro = value!; });
                      },
                    ),
                  ),
                ],
              ),
              
              // --- AÑADIDO: Campo condicional para "Altura de Caída" ---
              Visibility(
                visible: !_comienzaDesdeAdentro,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                  child: TextField(
                    controller: _alturaCaidaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Altura de Caída (cm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // --- SECCIÓN ORIGINAL: Peso Extra ---
              Text(
                'Peso Extra (kg):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: _pesoExtraController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: 'Kilogramos', border: OutlineInputBorder(),
                    hintText: 'Ej: 5.5', isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              
              // --- AÑADIDO: Nuevos campos para "Peso" y "Altura" de la persona ---
              const Divider(height: 20, thickness: 1),
              Text(
                'Datos Adicionales de la Persona:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pesoPersonaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(
                  labelText: 'Peso de la Persona (kg)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alturaPersonaController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Altura de la Persona (cm)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 15),
              const Divider(height: 20, thickness: 1),
              // ----------------------------------------------------------------

              // --- SECCIÓN ORIGINAL: Último salto completo ---
              Text(
                'Último salto completo:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Sí', style: TextStyle(fontSize: 15.0)),
                      value: true,
                      groupValue: _ultimoSaltoCompleto,
                      onChanged: (bool? value) {
                        setState(() { _ultimoSaltoCompleto = value!; });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('No', style: TextStyle(fontSize: 15.0)),
                      value: false,
                      groupValue: _ultimoSaltoCompleto,
                      onChanged: (bool? value) {
                        setState(() { _ultimoSaltoCompleto = value!; });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // --- SECCIÓN ORIGINAL: Botones ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _aceptarConfiguracion,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Aceptar', style: TextStyle(fontSize: 16)),
                  ),
                  OutlinedButton(
                    onPressed: _cancelar,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
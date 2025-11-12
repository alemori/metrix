// ARCHIVO: inicio_saltos_multiples.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// CAMBIO: Apuntar a la pantalla de notificaciones, que ahora es nuestra pantalla unificada.
import 'ble_notifications_screen.dart';

class InicioSaltosMultiples extends StatefulWidget {
  const InicioSaltosMultiples({super.key}); // Constructor sin parámetros

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

  @override
  void dispose() {
    _cantidadSaltosController.dispose();
    _tiempoLimiteController.dispose();
    _pesoExtraController.dispose();
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

    int limiteSaltos = 0;
    int limiteTiempo = 0;

    if (_limiteSeleccionado == LimiteOpcion.saltos) {
      limiteSaltos = int.tryParse(_cantidadSaltosController.text) ?? 0;
    } else if (_limiteSeleccionado == LimiteOpcion.tiempo) {
      limiteTiempo = int.tryParse(_tiempoLimiteController.text) ?? 0;
    }

    double pesoExtra = double.tryParse(_pesoExtraController.text) ?? 0.0;

    // --- CAMBIO CLAVE ---
    // Se elimina la construcción de la cadena de texto compleja "MULTI_...".
    // Ahora navegamos a BleNotificationsScreen pasándole los parámetros individuales.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BleNotificationsScreen(
          jumpType: "MULTI", // Se envía un tipo de salto genérico
          limiteSaltos: limiteSaltos,
          limiteTiempo: limiteTiempo,
          comienzaDesdeAdentro: _comienzaDesdeAdentro,
          pesoExtra: pesoExtra,
          ultimoSaltoCompleto: _ultimoSaltoCompleto,
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
    // La UI de esta pantalla no cambia en absoluto.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Saltos Múltiples'),
      ),
      body: SingleChildScrollView(
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Límite por:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    RadioListTile<LimiteOpcion>(
                      title: const Text('Saltos', style: TextStyle(fontSize: 15.0)),
                      value: LimiteOpcion.saltos,
                      groupValue: _limiteSeleccionado,
                      onChanged: (LimiteOpcion? value) {
                        setState(() {
                          _limiteSeleccionado = value!;
                        });
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
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        ),
                        style: const TextStyle(fontSize: 15.0),
                      ),
                    ),
                    RadioListTile<LimiteOpcion>(
                      title: const Text('Tiempo (segundos)', style: TextStyle(fontSize: 15.0)),
                      value: LimiteOpcion.tiempo,
                      groupValue: _limiteSeleccionado,
                      onChanged: (LimiteOpcion? value) {
                        setState(() {
                          _limiteSeleccionado = value!;
                        });
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
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        ),
                        style: const TextStyle(fontSize: 15.0),
                      ),
                    ),
                    RadioListTile<LimiteOpcion>(
                      title: const Text('Sin límite', style: TextStyle(fontSize: 15.0)),
                      value: LimiteOpcion.sinLimite,
                      groupValue: _limiteSeleccionado,
                      onChanged: (LimiteOpcion? value) {
                        setState(() {
                          _limiteSeleccionado = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 15),

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
                              setState(() {
                                _comienzaDesdeAdentro = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Afuera', style: TextStyle(fontSize: 15.0)),
                            value: false,
                            groupValue: _comienzaDesdeAdentro,
                            onChanged: (bool? value) {
                              setState(() {
                                _comienzaDesdeAdentro = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Text(
                      'Peso Extra (kg):',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: _pesoExtraController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Kilogramos',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: 5.5',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                        ),
                        style: const TextStyle(fontSize: 15.0),
                      ),
                    ),
                    const SizedBox(height: 15),

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
                              setState(() {
                                _ultimoSaltoCompleto = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('No', style: TextStyle(fontSize: 15.0)),
                            value: false,
                            groupValue: _ultimoSaltoCompleto,
                            onChanged: (bool? value) {
                              setState(() {
                                _ultimoSaltoCompleto = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _aceptarConfiguracion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aceptar', style: TextStyle(fontSize: 16)),
                    ),
                    OutlinedButton(
                      onPressed: _cancelar,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
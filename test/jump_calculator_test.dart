import 'package:flutter_test/flutter_test.dart';
// Asegurate de que la ruta coincida con el nombre de tu paquete, por ejemplo:
// import 'package:metrix/jump_calculator.dart';
// import 'package:metrix/jump_data_processor.dart';
import '../lib/jump_calculator.dart';
import '../lib/jump_data_processor.dart';

void main() {
  // Instanciamos el calculador que vamos a someter a prueba
  final calculator = JumpCalculator();

  group('Pruebas de Saltos Múltiples (MULTI)', () {
    
    test('1. Serie empezando desde ADENTRO (comienzaDesdeAdentro: true)', () {
      // SIMULACIÓN: El atleta está parado en la alfombra. 
      // Salta (Despegue), vuela 500ms, cae (Aterriza) por 300ms, salta y vuela 600ms, y cae.
      final rawCollection = {
        'jumpType': 'MULTI',
        'comienzaDesdeAdentro': true,
        'data': [
          {'estado': '1', 'tiempo': '1000'}, // Despegue inicial (T=1000ms)
          {'estado': '0', 'tiempo': '1500'}, // Aterrizaje (Vuelo 1: 500ms)
          {'estado': '1', 'tiempo': '1800'}, // Despegue (Contacto 1: 300ms)
          {'estado': '0', 'tiempo': '2400'}, // Aterrizaje (Vuelo 2: 600ms)
        ]
      };

      // Ejecutamos tu matemática
      final List<JumpData> results = calculator.calculateJumpFromRawData(rawCollection);

      // VERIFICACIONES AUTOMÁTICAS:
      expect(results.length, 2, reason: 'Debería haber detectado exactamente 2 saltos');
      
      // Verificamos el Salto 1
      expect(results[0].flightTime, 0.500, reason: 'El primer vuelo debe ser de 500ms');
      expect(results[0].contactTime, 0.0, reason: 'Como empezó adentro, el primer contacto calculado debe ser 0.0 (luego se exporta como -1)');
      
      // Verificamos el Salto 2
      expect(results[1].flightTime, 0.600, reason: 'El segundo vuelo debe ser de 600ms');
      expect(results[1].contactTime, 0.300, reason: 'El tiempo de contacto entre vuelos debe ser 300ms');
    });

    test('2. Serie empezando desde AFUERA (comienzaDesdeAdentro: false)', () {
      // SIMULACIÓN: El atleta salta desde un cajón. 
      // Cae a la alfombra (Aterriza), amortigua 400ms (Despegue), vuela 700ms, y cae.
      final rawCollection = {
        'jumpType': 'MULTI',
        'comienzaDesdeAdentro': false,
        'data': [
          {'estado': '0', 'tiempo': '1000'}, // Aterrizaje desde el cajón
          {'estado': '1', 'tiempo': '1400'}, // Despegue (Contacto inicial: 400ms)
          {'estado': '0', 'tiempo': '2100'}, // Aterrizaje (Vuelo 1: 700ms)
          {'estado': '1', 'tiempo': '2400'}, // Despegue (Contacto 2: 300ms)
          {'estado': '0', 'tiempo': '3000'}, // Aterrizaje (Vuelo 2: 600ms)
        ]
      };

      // Ejecutamos tu matemática
      final List<JumpData> results = calculator.calculateJumpFromRawData(rawCollection);

      // VERIFICACIONES AUTOMÁTICAS:
      expect(results.length, 2, reason: 'Debería haber detectado 2 vuelos reales');

      // Verificamos el Salto 1
      expect(results[0].flightTime, 0.700, reason: 'El primer vuelo debe ser de 700ms');
      expect(results[0].contactTime, 0.400, reason: 'El contacto inicial desde el cajón debe ser 400ms');

      // Verificamos el Salto 2
      expect(results[1].flightTime, 0.600, reason: 'El segundo vuelo debe ser de 600ms');
      expect(results[1].contactTime, 0.300, reason: 'El segundo contacto debe ser de 300ms');
    });

  });
}
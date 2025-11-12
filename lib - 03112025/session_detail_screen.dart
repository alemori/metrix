// ARCHIVO MODIFICADO: lib/session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'session_model.dart';
import 'user_model.dart';
import 'user_provider.dart';
import 'session_person_provider.dart';
import 'add_person_to_session_screen.dart';
// --- AÑADIR IMPORTACIONES PARA NAVEGAR A LAS PANTALLAS DE SALTO ---
import 'ble_notifications_screen.dart';
import 'inicio_saltos_multiples.dart';


class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

// --- REEMPLAZA EL MÉTODO EXISTENTE CON ESTA VERSIÓN COMPLETA ---
void _showJumpSelectionMenu(BuildContext context, User person) {
  final sessionID = session.sessionID; // Para usarlo más fácil abajo

  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      // Usamos ListView para que funcione bien si hay muchas opciones
      return ListView(
        shrinkWrap: true, // Se ajusta al contenido
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test SJ'),
            onTap: () {
              Navigator.pop(ctx); // Cierra el menú
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'SJ',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test SJl'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'SJl',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test CMJ'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'CMJ',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test ABK'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'ABK',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test DJ_IN'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'DJ_IN',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Iniciar Test DJ_EX'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleNotificationsScreen(
                    jumpType: 'DJ_EX',
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Configurar Salto Múltiple'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InicioSaltosMultiples(
                    sessionID: sessionID,
                    person: person,
                  ),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final sessionPersonProvider = context.watch<SessionPersonProvider>();

    if (userProvider.isLoading || sessionPersonProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Cargando...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final participants = sessionPersonProvider.getPeopleForSession(
      session.sessionID,
      userProvider.users,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Participantes: ${session.name}'),
      ),
      body: participants.isEmpty
          ? const Center(
              child: Text(
                'No hay personas en esta sesión.\nPresiona "+" para agregar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final person = participants[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(person.firstName[0])),
                    title: Text('${person.firstName} ${person.lastName}'),
                    subtitle: Text('ID: ${person.uniqueID}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      tooltip: 'Quitar de la sesión',
                      onPressed: () {
                        context.read<SessionPersonProvider>().togglePersonInSession(
                              session.sessionID,
                              person,
                            );
                      },
                    ),
                    // --- CAMBIO CLAVE: Al tocar, se abre el menú de saltos ---
                    onTap: () {
                      _showJumpSelectionMenu(context, person);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPersonToSessionScreen(session: session),
            ),
          );
        },
        tooltip: 'Agregar o quitar personas',
        child: const Icon(Icons.add),
      ),
    );
  }
}
// ARCHIVO MODIFICADO: lib/session_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'session_model.dart';
import 'user_provider.dart';
import 'session_person_provider.dart';
// --- AÑADIR IMPORTACIÓN A LA NUEVA PANTALLA DE SELECCIÓN ---
import 'add_person_to_session_screen.dart'; 

class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // Escuchamos a los providers para obtener los datos y redibujar si cambian
    final userProvider = context.watch<UserProvider>();
    final sessionPersonProvider = context.watch<SessionPersonProvider>();

    if (userProvider.isLoading || sessionPersonProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Cargando...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- LÓGICA NUEVA: Obtener solo las personas que participan en esta sesión ---
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
                        // Llama al provider para quitar la persona
                        context.read<SessionPersonProvider>().togglePersonInSession(
                              session.sessionID,
                              person,
                            );
                      },
                    ),
                  ),
                );
              },
            ),
      // --- NUEVO BOTÓN FLOTANTE ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega a la pantalla de selección de personas
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
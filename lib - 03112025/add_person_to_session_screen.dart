// ARCHIVO NUEVO: lib/add_person_to_session_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'session_model.dart';
import 'user_provider.dart';
import 'session_person_provider.dart';
import 'user_model.dart';

class AddPersonToSessionScreen extends StatelessWidget {
  final Session session;
  const AddPersonToSessionScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // Usamos 'watch' para que la UI se actualice al marcar/desmarcar
    final sessionPersonProvider = context.watch<SessionPersonProvider>();

    if (userProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleccionar Personas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<User> allPeople = userProvider.users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Personas'),
      ),
      body: allPeople.isEmpty
          ? const Center(
              child: Text('No hay personas creadas.'),
            )
          : ListView.builder(
              itemCount: allPeople.length,
              itemBuilder: (context, index) {
                final person = allPeople[index];
                final bool isSelected = sessionPersonProvider.isPersonInSession(
                  session.sessionID,
                  person.uniqueID,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CheckboxListTile(
                    secondary: CircleAvatar(child: Text(person.firstName[0])),
                    title: Text('${person.firstName} ${person.lastName}'),
                    subtitle: Text('ID: ${person.uniqueID}'),
                    value: isSelected,
                    onChanged: (bool? value) {
                      // Usamos 'read' dentro de un callback para llamar a la función sin redibujar todo
                      context.read<SessionPersonProvider>().togglePersonInSession(
                            session.sessionID,
                            person,
                          );
                    },
                  ),
                );
              },
            ),
    );
  }
}
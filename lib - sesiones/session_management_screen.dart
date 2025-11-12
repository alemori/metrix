// ARCHIVO NUEVO: lib/session_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'session_model.dart';
import 'session_provider.dart';

class SessionManagementScreen extends StatelessWidget {
  const SessionManagementScreen({super.key});

  void _showSessionDialog(BuildContext context, {Session? session}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: session?.name ?? '');
    final placeController = TextEditingController(text: session?.place ?? '');
    final commentController = TextEditingController(text: session?.comment ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(session == null ? 'Agregar Sesión' : 'Editar Sesión'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Campo requerido' : null,
                  ),
                  TextFormField(
                    controller: placeController,
                    decoration: const InputDecoration(labelText: 'Lugar'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Campo requerido' : null,
                  ),
                  TextFormField(
                    controller: commentController,
                    decoration: const InputDecoration(labelText: 'Comentario'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final sessionProvider = Provider.of<SessionProvider>(
                    context,
                    listen: false,
                  );
                  if (session == null) {
                    sessionProvider.addSession(
                      name: nameController.text,
                      place: placeController.text,
                      comment: commentController.text,
                    );
                  } else {
                    final updatedSession = Session(
                      sessionID: session.sessionID,
                      name: nameController.text,
                      place: placeController.text,
                      ts: session.ts, // El provider actualizará el timestamp
                      comment: commentController.text,
                    );
                    sessionProvider.updateSession(updatedSession);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gestión de Sesiones'),
          ),
          body: sessionProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : sessionProvider.sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay sesiones. Agrega una con el botón "+".',
                      ),
                    )
                  : ListView.builder(
                      itemCount: sessionProvider.sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessionProvider.sessions[index];
                        final formattedDate =
                            DateFormat('dd/MM/yyyy HH:mm').format(session.ts);
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(session.name[0])),
                            title: Text('${session.name} - ${session.place}'),
                            subtitle:
                                Text('Fecha: $formattedDate\nID: ${session.sessionID}'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar eliminación'),
                                    content: Text(
                                        '¿Estás seguro de que quieres eliminar la sesión "${session.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          sessionProvider
                                              .deleteSession(session.sessionID);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Sí, eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            onTap: () => _showSessionDialog(context, session: session),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showSessionDialog(context),
            tooltip: 'Agregar Nueva Sesión',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
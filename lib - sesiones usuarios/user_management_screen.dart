// ARCHIVO MODIFICADO: lib/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'user_provider.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  void _showUserDialog(BuildContext context, {User? user}) {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(
      text: user?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: user?.lastName ?? '',
    );
    final descriptionController = TextEditingController(
      text: user?.descripcion ?? '',
    );
    String selectedSex = user?.sex ?? 'U';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user == null ? 'Agregar Persona' : 'Editar Persona'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Campo requerido' : null,
                  ),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Campo requerido' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedSex,
                    decoration: const InputDecoration(labelText: 'Sexo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'U',
                        child: Text('No especificado'),
                      ),
                      DropdownMenuItem(value: 'M', child: Text('Masculino')),
                      DropdownMenuItem(value: 'F', child: Text('Femenino')),
                    ],
                    onChanged: (value) {
                      if (value != null) selectedSex = value;
                    },
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
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
                  final userProvider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );
                  if (user == null) {
                    userProvider.addUser(
                      firstName: firstNameController.text,
                      lastName: lastNameController.text,
                      sex: selectedSex,
                      description: descriptionController.text,
                    );
                  } else {
                    final updatedUser = User(
                      uniqueID: user.uniqueID,
                      muuid: user.muuid,
                      firstName: firstNameController.text,
                      lastName: lastNameController.text,
                      sex: selectedSex,
                      descripcion: descriptionController.text,
                    );
                    userProvider.updateUser(updatedUser);
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
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Scaffold(
          appBar: AppBar(
            // --- CAMBIO AQUÍ ---
            title: const Text('Gestión de Personas'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: () => userProvider.exportUsers(context),
                tooltip: 'Exportar a CSV',
              ),
              IconButton(
                icon: const Icon(Icons.file_upload),
                onPressed: () async {
                  final resultado = await userProvider.importUsers();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          resultado > 0
                              ? 'Se importaron $resultado personas nuevas.'
                              : resultado == 0
                                  ? 'No se encontraron personas nuevas para importar.'
                                  : 'Ocurrió un error al importar el archivo.',
                        ),
                      ),
                    );
                  }
                },
                tooltip: 'Importar desde CSV',
              ),
            ],
          ),
          body: userProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : userProvider.users.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay personas. Agrega una con el botón "+".',
                      ),
                    )
                  : ListView.builder(
                      itemCount: userProvider.users.length,
                      itemBuilder: (context, index) {
                        final user = userProvider.users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(user.firstName[0])),
                            title: Text('${user.firstName} ${user.lastName}'),
                            subtitle: Text(
                              'ID: ${user.uniqueID} | MUUID: ${user.muuid.substring(0, 8)}...',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      'Confirmar eliminación',
                                    ),
                                    content: Text(
                                      '¿Estás seguro de que quieres eliminar a ${user.firstName}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          userProvider.deleteUser(
                                            user.uniqueID,
                                          );
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Sí, eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            onTap: () => _showUserDialog(context, user: user),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showUserDialog(context),
            tooltip: 'Agregar Nueva Persona',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
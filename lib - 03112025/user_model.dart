// ARCHIVO ACTUALIZADO: lib/user_model.dart

class User {
  final int uniqueID;
  final String muuid;
  String firstName;
  String lastName;
  String sex; // 'U', 'M', 'F'
  String descripcion;

  User({
    required this.uniqueID,
    required this.muuid,
    required this.firstName,
    required this.lastName,
    this.sex = 'U',
    this.descripcion = '',
  });

  // Método para convertir el usuario a una lista para el CSV
  List<dynamic> toList() {
    return [uniqueID, muuid, firstName, lastName, sex, descripcion];
  }
}
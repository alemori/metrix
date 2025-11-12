// ARCHIVO NUEVO: lib/session_model.dart

class Session {
  final int sessionID;
  String name;
  String place;
  DateTime ts;
  String comment;

  Session({
    required this.sessionID,
    required this.name,
    required this.place,
    required this.ts,
    this.comment = '',
  });

  // Método para convertir la sesión a una lista para el CSV
  List<dynamic> toList() {
    // Formatear el timestamp a un string estándar (ISO 8601) para consistencia
    String formattedTs = ts.toIso8601String();
    return [sessionID, name, place, formattedTs, comment];
  }

  // Factory constructor para crear una Sesión desde una fila de CSV
  factory Session.fromList(List<dynamic> list) {
    return Session(
      sessionID: int.tryParse(list[0].toString()) ?? 0,
      name: list[1].toString(),
      place: list[2].toString(),
      ts: DateTime.tryParse(list[3].toString()) ?? DateTime.now(),
      comment: list[4].toString(),
    );
  }
}
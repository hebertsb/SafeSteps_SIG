/// Modelo para registros de ubicación
/// Se usa tanto en memoria como para persistencia local
class Registro {
  final String? id;
  final String hora;
  final double latitud;
  final double longitud;
  final String hijoId;
  final bool isSynced;

  Registro({
    this.id,
    required this.hora,
    required this.latitud,
    required this.longitud,
    required this.hijoId,
    this.isSynced = false,
  });

  /// Convierte de JSON (desde API) a Registro
  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      id: json['id']?.toString(),
      hora: json['hora'] as String,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      hijoId: json['hijoId'] as String,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  /// Convierte Registro a JSON (para enviar a API)
  Map<String, dynamic> toJson() => {
    'hora': hora,
    'latitud': latitud,
    'longitud': longitud,
    'hijoId': hijoId,
    'isSynced': isSynced,
  };

  /// Convierte a Map para SQLite
  Map<String, dynamic> toSqliteMap() => {
    'hora': hora,
    'latitud': latitud,
    'longitud': longitud,
    'hijoId': hijoId,
    'isSynced': isSynced ? 1 : 0,
  };

  /// Convierte de Map de SQLite a Registro
  factory Registro.fromSqliteMap(Map<String, dynamic> map) {
    return Registro(
      id: map['id'].toString(),
      hora: map['hora'] as String,
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      hijoId: map['hijoId'] as String,
      isSynced: (map['isSynced'] as int) == 1,
    );
  }

  /// Crea una copia con campos modificados
  Registro copyWith({
    String? id,
    String? hora,
    double? latitud,
    double? longitud,
    String? hijoId,
    bool? isSynced,
  }) {
    return Registro(
      id: id ?? this.id,
      hora: hora ?? this.hora,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      hijoId: hijoId ?? this.hijoId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  String toString() =>
      'Registro(id: $id, hora: $hora, lat: $latitud, lng: $longitud, hijoId: $hijoId, synced: $isSynced)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Registro &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          hora == other.hora &&
          latitud == other.latitud &&
          longitud == other.longitud &&
          hijoId == other.hijoId &&
          isSynced == other.isSynced;

  @override
  int get hashCode =>
      id.hashCode ^
      hora.hashCode ^
      latitud.hashCode ^
      longitud.hashCode ^
      hijoId.hashCode ^
      isSynced.hashCode;
}

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/registro.dart';

/// Servicio para persistencia local de registros usando SQLite
class RegistroSQLite {
  static final RegistroSQLite _instance = RegistroSQLite._internal();
  static Database? _database;

  factory RegistroSQLite() => _instance;
  RegistroSQLite._internal();

  static const String _tableName = 'registros';
  static const String _dbName = 'safesteps.db';
  static const int _dbVersion = 2; // v2: agregó columna fueOffline

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  /// Inicializa la base de datos SQLite
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    print('📂 Initializing SQLite at: $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea la tabla al inicializar la BD
  Future<void> _onCreate(Database db, int version) async {
    print('🏗️ Creating table $_tableName');
    await db.execute(
      '''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hora TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        hijoId TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        fueOffline INTEGER DEFAULT 0,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
      ''',
    );

    // Crear índices para optimizar búsquedas
    await db.execute(
      'CREATE INDEX idx_hijoId ON $_tableName(hijoId)',
    );
    await db.execute(
      'CREATE INDEX idx_isSynced ON $_tableName(isSynced)',
    );
  }

  /// Manejo de migraciones en futuras versiones
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from $oldVersion to $newVersion');
    
    // Migración v1 → v2: agregar columna fueOffline
    if (oldVersion < 2) {
      print('📦 Migrando a v2: agregando columna fueOffline');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN fueOffline INTEGER DEFAULT 0');
    }
  }

  /// Inserta un nuevo registro en la BD local
  Future<int> insertRegistro(Registro registro) async {
    try {
      final db = await database;
      final id = await db.insert(
        _tableName,
        registro.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ Registro insertado localmente (ID: $id)');
      return id;
    } catch (e) {
      print('❌ Error al insertar registro: $e');
      rethrow;
    }
  }

  /// Inserta múltiples registros en una transacción
  Future<void> insertMultiple(List<Registro> registros) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final registro in registros) {
          await txn.insert(
            _tableName,
            registro.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      print('✅ ${registros.length} registros insertados localmente');
    } catch (e) {
      print('❌ Error al insertar múltiples registros: $e');
      rethrow;
    }
  }

  /// Obtiene todos los registros pendientes de sincronizar
  Future<List<Registro>> getPendientes() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'isSynced = ?',
        whereArgs: [0],
        orderBy: 'createdAt ASC', // Más antiguos primero
      );
      print('📋 ${maps.length} registros pendientes encontrados');
      return maps.map(Registro.fromSqliteMap).toList();
    } catch (e) {
      print('❌ Error al obtener registros pendientes: $e');
      rethrow;
    }
  }

  /// Obtiene registros pendientes de un hijo específico
  Future<List<Registro>> getPendientesByHijo(String hijoId) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'isSynced = ? AND hijoId = ?',
        whereArgs: [0, hijoId],
        orderBy: 'createdAt ASC',
      );
      print('📋 ${maps.length} registros pendientes para hijo $hijoId');
      return maps.map(Registro.fromSqliteMap).toList();
    } catch (e) {
      print('❌ Error al obtener registros pendientes: $e');
      rethrow;
    }
  }

  /// Obtiene todos los registros (synced y no synced)
  Future<List<Registro>> getAllRegistros() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        orderBy: 'createdAt DESC',
      );
      return maps.map(Registro.fromSqliteMap).toList();
    } catch (e) {
      print('❌ Error al obtener todos los registros: $e');
      rethrow;
    }
  }

  /// Obtiene registros de un rango de fechas
  Future<List<Registro>> getRegistrosByFecha(
    String hijoId,
    DateTime desde,
    DateTime hasta,
  ) async {
    try {
      final db = await database;
      final desdeIso = desde.toIso8601String();
      final hastaIso = hasta.toIso8601String();

      final maps = await db.query(
        _tableName,
        where: 'hijoId = ? AND hora >= ? AND hora <= ?',
        whereArgs: [hijoId, desdeIso, hastaIso],
        orderBy: 'hora DESC',
      );
      return maps.map(Registro.fromSqliteMap).toList();
    } catch (e) {
      print('❌ Error al obtener registros por fecha: $e');
      rethrow;
    }
  }

  /// Marca un registro como sincronizado
  Future<void> marcarComoSynced(int id) async {
    try {
      final db = await database;
      await db.update(
        _tableName,
        {'isSynced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Registro $id marcado como sincronizado');
    } catch (e) {
      print('❌ Error al marcar como sincronizado: $e');
      rethrow;
    }
  }

  /// Marca múltiples registros como sincronizados
  Future<void> marcarMultipleComoSynced(List<int> ids) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final id in ids) {
          await txn.update(
            _tableName,
            {'isSynced': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
      print('✅ ${ids.length} registros marcados como sincronizados');
    } catch (e) {
      print('❌ Error al marcar múltiples como sincronizados: $e');
      rethrow;
    }
  }

  /// Elimina un registro de la BD local
  Future<void> deleteRegistro(int id) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🗑️ Registro $id eliminado');
    } catch (e) {
      print('❌ Error al eliminar registro: $e');
      rethrow;
    }
  }

  /// Elimina múltiples registros
  Future<void> deleteMultiple(List<int> ids) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final id in ids) {
          await txn.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
      print('🗑️ ${ids.length} registros eliminados');
    } catch (e) {
      print('❌ Error al eliminar múltiples registros: $e');
      rethrow;
    }
  }

  /// Limpia todos los registros sincronizados (mantenimiento)
  Future<int> limpiarSincronizados() async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableName,
        where: 'isSynced = ?',
        whereArgs: [1],
      );
      print('🧹 $count registros sincronizados eliminados');
      return count;
    } catch (e) {
      print('❌ Error al limpiar sincronizados: $e');
      rethrow;
    }
  }

  /// Obtiene estadísticas de la base de datos
  Future<Map<String, int>> getEstadisticas() async {
    try {
      final db = await database;
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM $_tableName',
      );
      final syncResult = await db.rawQuery(
        'SELECT COUNT(*) as synced FROM $_tableName WHERE isSynced = 1',
      );

      return {
        'total': totalResult.first['total'] as int? ?? 0,
        'synced': syncResult.first['synced'] as int? ?? 0,
        'pending': (totalResult.first['total'] as int? ?? 0) -
            (syncResult.first['synced'] as int? ?? 0),
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      rethrow;
    }
  }

  /// Cierra la conexión con la BD (para cleanup)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔌 Base de datos cerrada');
    }
  }
}

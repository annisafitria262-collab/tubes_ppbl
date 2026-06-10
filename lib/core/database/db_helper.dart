import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../features/domain_eval/models/evaluasi_model.dart';
import '../../features/domain_eval/models/jurnal_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fitplate.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        filePath,
        version: 5, 
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 5, // NAIK KE VERSI 5 UNTUK TABEL USERS
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onConfigure: _onConfigure,
      );
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // ==========================================
    // TABEL AUTHENTICATION (PINTU MASUK)
    // ==========================================
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // ==========================================
    // DOMAIN 1 (ATHAYA): INPUT
    // ==========================================
    await db.execute('''
      CREATE TABLE master_makanan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        kalori_per_100g REAL NOT NULL,
        protein_g REAL NOT NULL,
        karbo_g REAL NOT NULL,
        lemak_g REAL NOT NULL,
        satuan_default TEXT DEFAULT 'gram',
        kategori TEXT,
        sumber TEXT DEFAULT 'manual',
        aktif INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE log_konsumsi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        makanan_id INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        waktu_makan TEXT NOT NULL,
        jumlah_gram REAL NOT NULL,
        kalori_total REAL NOT NULL,
        protein_total REAL,
        karbo_total REAL,
        lemak_total REAL,
        catatan TEXT,
        FOREIGN KEY (makanan_id) REFERENCES master_makanan (id) ON DELETE CASCADE
      )
    ''');

    // ==========================================
    // DOMAIN 2 (ACA): PLANNING
    // ==========================================
    await db.execute('''
      CREATE TABLE rencana_makan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        makanan_id INTEGER NOT NULL,
        hari TEXT NOT NULL,
        waktu_makan TEXT NOT NULL,
        jumlah_gram REAL NOT NULL,
        minggu_ke TEXT NOT NULL,
        status TEXT DEFAULT 'DRAFT',
        FOREIGN KEY (makanan_id) REFERENCES master_makanan (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daftar_belanja (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        makanan_id INTEGER,
        nama_item TEXT NOT NULL,
        jumlah_total REAL NOT NULL,
        satuan TEXT NOT NULL,
        minggu_ke TEXT NOT NULL,
        sudah_dibeli INTEGER DEFAULT 0,
        sumber TEXT DEFAULT 'auto',
        FOREIGN KEY (makanan_id) REFERENCES master_makanan (id) ON DELETE SET NULL
      )
    ''');

    // ==========================================
    // DOMAIN 3 (ANNISA): EVALUASI — JANGAN DISENTUH
    // ==========================================
    await db.execute('''
      CREATE TABLE evaluasi_harian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL UNIQUE,
        target_kalori REAL NOT NULL,
        kalori_aktual REAL NOT NULL,
        surplus_defisit REAL NOT NULL,
        status TEXT NOT NULL,
        protein_total REAL DEFAULT 0,
        karbo_total REAL DEFAULT 0,
        lemak_total REAL DEFAULT 0,
        is_strict INTEGER DEFAULT 0,
        langkah_kaki INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE jurnal_deviasi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evaluasi_id INTEGER NOT NULL UNIQUE,
        root_cause TEXT NOT NULL,
        catatan TEXT,
        mood_score INTEGER DEFAULT 3,
        dibuat_pada INTEGER NOT NULL,
        FOREIGN KEY (evaluasi_id) REFERENCES evaluasi_harian (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE evaluasi_harian ADD COLUMN is_strict INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE evaluasi_harian ADD COLUMN langkah_kaki INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE log_konsumsi ADD COLUMN protein_total REAL');
        await db.execute('ALTER TABLE log_konsumsi ADD COLUMN karbo_total REAL');
        await db.execute('ALTER TABLE log_konsumsi ADD COLUMN lemak_total REAL');
      } catch (_) {}
    }
    // EKSEKUSI JIKA USER UPDATE DARI VERSI 4 KE 5
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL
        )
      ''');
    }
  }

  // ==========================================
  // CRUD DOMAIN 3 (ANNISA) — JANGAN DISENTUH
  // ==========================================
  Future<int> insertEvaluasi(EvaluasiModel evaluasi) async {
    final db = await instance.database;
    return await db.insert('evaluasi_harian', evaluasi.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<EvaluasiModel>> getAllEvaluasi() async {
    final db = await instance.database;
    final result = await db.query('evaluasi_harian', orderBy: 'tanggal DESC');
    return result.map((json) => EvaluasiModel.fromMap(json)).toList();
  }

  Future<int> insertJurnal(JurnalModel jurnal) async {
    final db = await instance.database;
    return await db.insert('jurnal_deviasi', jurnal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JurnalModel?> getJurnalByEvaluasiId(int evaluasiId) async {
    final db = await instance.database;
    final maps = await db.query(
      'jurnal_deviasi',
      where: 'evaluasi_id = ?',
      whereArgs: [evaluasiId],
    );
    if (maps.isNotEmpty) return JurnalModel.fromMap(maps.first);
    return null;
  }

  Future<int> updateEvaluasi(EvaluasiModel evaluasi) async {
    final db = await instance.database;
    return await db.update(
      'evaluasi_harian',
      evaluasi.toMap(),
      where: 'id = ?',
      whereArgs: [evaluasi.id],
    );
  }

  Future<int> deleteEvaluasi(int id) async {
    final db = await instance.database;
    return await db.delete('evaluasi_harian', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteJurnalByEvaluasiId(int evaluasiId) async {
    final db = await instance.database;
    return await db.delete('jurnal_deviasi', where: 'evaluasi_id = ?', whereArgs: [evaluasiId]);
  }

  Future<Map<String, int>> getRootCauseStats() async {
    final db = await instance.database;
    final int batasWaktu =
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final result = await db.rawQuery('''
      SELECT root_cause, COUNT(*) as count 
      FROM jurnal_deviasi 
      WHERE dibuat_pada >= ?
      GROUP BY root_cause
    ''', [batasWaktu]);
    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['root_cause'] as String] = row['count'] as int;
    }
    return stats;
  }

  // ==========================================
  // CRUD AUTHENTICATION (LOGIN & REGISTER)
  // ==========================================
  
  // Fungsi Register (CREATE Data User)
  Future<int> registerUser(String nama, String email, String password) async {
    final db = await instance.database;
    try {
      return await db.insert('users', {
        'nama': nama,
        'email': email,
        'password': password, 
      });
    } catch (e) {
      // Jika email sudah terdaftar, SQLite akan melemparkan error UNIQUE Constraint
      return -1; 
    }
  }

  // Fungsi Login (READ/SELECT Data User)
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    
    // Jika data ditemukan, kembalikan data user tersebut. Jika tidak, kembalikan null.
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
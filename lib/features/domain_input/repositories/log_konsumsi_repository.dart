import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../models/log_konsumsi_model.dart';

class LogKonsumsiRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. CREATE
  Future<int> insertLog(LogKonsumsiModel log) async {
    Database db = await _dbHelper.database;
    return await db.insert('log_konsumsi', log.toMap());
  }

  // 2. READ: Ambil log berdasarkan tanggal + JOIN nama makanan
  Future<List<LogKonsumsiModel>> getLogsByDate(String tanggal) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        l.*, 
        m.nama AS nama_makanan 
      FROM log_konsumsi l
      JOIN master_makanan m ON l.makanan_id = m.id
      WHERE l.tanggal = ?
      ORDER BY l.id ASC
    ''', [tanggal]);

    return List.generate(maps.length, (i) => LogKonsumsiModel.fromMap(maps[i]));
  }

  // 3. UPDATE
  Future<int> updateLog(LogKonsumsiModel log) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'log_konsumsi',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  // 4. DELETE
  Future<int> deleteLog(int id) async {
    Database db = await _dbHelper.database;
    return await db.delete(
      'log_konsumsi',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // FUNGSI EKSTRA: Total kalori hari ini
  Future<double> getTotalKaloriHariIni(String tanggal) async {
    Database db = await _dbHelper.database;
    var result = await db.rawQuery('''
      SELECT SUM(kalori_total) as total 
      FROM log_konsumsi 
      WHERE tanggal = ?
    ''', [tanggal]);

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // FUNGSI EKSTRA: Total macro hari ini (protein, karbo, lemak) — pakai data REAL dari SQLite
  Future<Map<String, double>> getTotalMacroHariIni(String tanggal) async {
    Database db = await _dbHelper.database;

    // Coba ambil dari kolom macro di log_konsumsi (jika tersedia)
    var result = await db.rawQuery('''
      SELECT 
        SUM(COALESCE(protein_total, (m.protein_g * l.jumlah_gram / 100))) AS total_protein,
        SUM(COALESCE(l.karbo_total, (m.karbo_g * l.jumlah_gram / 100))) AS total_karbo,
        SUM(COALESCE(l.lemak_total, (m.lemak_g * l.jumlah_gram / 100))) AS total_lemak
      FROM log_konsumsi l
      JOIN master_makanan m ON l.makanan_id = m.id
      WHERE l.tanggal = ?
    ''', [tanggal]);

    if (result.isNotEmpty && result.first['total_protein'] != null) {
      return {
        'protein': (result.first['total_protein'] as num).toDouble(),
        'karbo': (result.first['total_karbo'] as num? ?? 0).toDouble(),
        'lemak': (result.first['total_lemak'] as num? ?? 0).toDouble(),
      };
    }
    return {'protein': 0.0, 'karbo': 0.0, 'lemak': 0.0};
  }
}

import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../models/rencana_makan_model.dart';
import 'daftar_belanja_repository.dart';

class RencanaMakanRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DaftarBelanjaRepository _belanjaRepo = DaftarBelanjaRepository();

  // 1. CREATE
  Future<int> insertRencana(RencanaMakanModel rencana) async {
    Database db = await _dbHelper.database;
    return await db.insert('rencana_makan', rencana.toMap());
  }

  // 2. READ berdasarkan minggu + JOIN nama makanan
  Future<List<RencanaMakanModel>> getRencanaByMinggu(String mingguKe) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        r.*, 
        m.nama AS nama_makanan,
        m.kalori_per_100g
      FROM rencana_makan r
      JOIN master_makanan m ON r.makanan_id = m.id
      WHERE r.minggu_ke = ?
      ORDER BY r.hari ASC, r.waktu_makan ASC
    ''', [mingguKe]);

    return List.generate(maps.length, (i) => RencanaMakanModel.fromMap(maps[i]));
  }

  // 3. UPDATE rencana (hari/waktu/porsi)
  Future<int> updateRencana(RencanaMakanModel rencana) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'rencana_makan',
      rencana.toMap(),
      where: 'id = ?',
      whereArgs: [rencana.id],
    );
  }

  // 3b. Aktifkan semua DRAFT jadi AKTIF + trigger generate daftar belanja
  Future<void> aktifkanRencanaMingguIni(String mingguKe) async {
    Database db = await _dbHelper.database;
    await db.update(
      'rencana_makan',
      {'status': 'AKTIF'},
      where: 'minggu_ke = ? AND status = ?',
      whereArgs: [mingguKe, 'DRAFT'],
    );
    await _belanjaRepo.generateDariRencana(mingguKe);
  }

  // 4. DELETE
  Future<int> deleteRencana(int id) async {
    Database db = await _dbHelper.database;
    return await db.delete(
      'rencana_makan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

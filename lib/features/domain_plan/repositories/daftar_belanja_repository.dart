import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../models/daftar_belanja_model.dart';

class DaftarBelanjaRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. AUTO-GENERATE dari rencana_makan
  Future<void> generateDariRencana(String mingguKe) async {
    Database db = await _dbHelper.database;

    // Hapus daftar belanja auto sebelumnya
    await db.delete(
      'daftar_belanja',
      where: 'minggu_ke = ? AND sumber = ?',
      whereArgs: [mingguKe, 'auto'],
    );

    final List<Map<String, dynamic>> bahanAgregasi = await db.rawQuery('''
      SELECT 
        r.makanan_id,
        m.nama AS nama_item,
        SUM(r.jumlah_gram) AS total_kebutuhan,
        m.satuan_default AS satuan
      FROM rencana_makan r
      JOIN master_makanan m ON r.makanan_id = m.id
      WHERE r.minggu_ke = ? AND r.status = 'AKTIF'
      GROUP BY r.makanan_id, m.nama, m.satuan_default
    ''', [mingguKe]);

    for (var bahan in bahanAgregasi) {
      final itemBelanja = DaftarBelanjaModel(
        makananId: bahan['makanan_id'],
        namaItem: bahan['nama_item'],
        jumlahTotal: (bahan['total_kebutuhan'] as num).toDouble(),
        satuan: bahan['satuan'],
        mingguKe: mingguKe,
        sumber: 'auto',
      );
      await db.insert('daftar_belanja', itemBelanja.toMap());
    }
  }

  // 2. CREATE MANUAL
  Future<int> insertBelanjaManual(DaftarBelanjaModel item) async {
    Database db = await _dbHelper.database;
    return await db.insert('daftar_belanja', item.toMap());
  }

  // 3. READ
  Future<List<DaftarBelanjaModel>> getDaftarBelanja(String mingguKe) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daftar_belanja',
      where: 'minggu_ke = ?',
      whereArgs: [mingguKe],
      orderBy: 'sudah_dibeli ASC, nama_item ASC',
    );
    return List.generate(maps.length, (i) => DaftarBelanjaModel.fromMap(maps[i]));
  }

  // 4. UPDATE: toggle sudah dibeli
  Future<int> toggleSudahDibeli(int id, int statusSekarang) async {
    Database db = await _dbHelper.database;
    int statusBaru = statusSekarang == 0 ? 1 : 0;
    return await db.update(
      'daftar_belanja',
      {'sudah_dibeli': statusBaru},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 4b. UPDATE: edit item belanja
  Future<int> updateBelanja(DaftarBelanjaModel item) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'daftar_belanja',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // 5. DELETE item belanja (manual maupun auto)
  Future<int> deleteItem(int id) async {
    Database db = await _dbHelper.database;
    return await db.delete(
      'daftar_belanja',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE semua item auto untuk minggu tertentu
  Future<int> deleteAutoItems(String mingguKe) async {
    Database db = await _dbHelper.database;
    return await db.delete(
      'daftar_belanja',
      where: 'minggu_ke = ? AND sumber = ?',
      whereArgs: [mingguKe, 'auto'],
    );
  }
}

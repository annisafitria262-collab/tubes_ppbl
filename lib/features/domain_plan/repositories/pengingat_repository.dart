import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../models/pengingat_model.dart';

class PengingatRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. CREATE
  Future<int> insertPengingat(PengingatModel pengingat) async {
    Database db = await _dbHelper.database;
    return await db.insert('pengingat_notifikasi', pengingat.toMap());
  }

  // 2. READ ALL
  Future<List<PengingatModel>> getPengingatList() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pengingat_notifikasi',
      orderBy: 'hari ASC, jam ASC',
    );
    return List.generate(maps.length, (i) => PengingatModel.fromMap(maps[i]));
  }

  // 3. UPDATE
  Future<int> updatePengingat(PengingatModel pengingat) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'pengingat_notifikasi',
      pengingat.toMap(),
      where: 'id = ?',
      whereArgs: [pengingat.id],
    );
  }

  // 4. TOGGLE ACTIVE STATUS
  Future<int> toggleAktif(int id, int statusSekarang) async {
    Database db = await _dbHelper.database;
    int statusBaru = statusSekarang == 1 ? 0 : 1;
    return await db.update(
      'pengingat_notifikasi',
      {'aktif': statusBaru},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 5. DELETE
  Future<int> deletePengingat(int id) async {
    Database db = await _dbHelper.database;
    return await db.delete(
      'pengingat_notifikasi',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

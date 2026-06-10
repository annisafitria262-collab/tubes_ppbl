import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../models/makanan_model.dart';

class MakananRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 1. CREATE
  Future<int> insertMakanan(MakananModel makanan) async {
    Database db = await _dbHelper.database;
    return await db.insert('master_makanan', makanan.toMap());
  }

  // 2. READ: Semua makanan aktif
  Future<List<MakananModel>> getAllMakanan() async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'master_makanan',
      where: 'aktif = ?',
      whereArgs: [1],
      orderBy: 'nama ASC',
    );
    return List.generate(maps.length, (i) => MakananModel.fromMap(maps[i]));
  }

  // 2b. READ by ID
  Future<MakananModel?> getMakananById(int id) async {
    Database db = await _dbHelper.database;
    final maps = await db.query(
      'master_makanan',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MakananModel.fromMap(maps.first);
  }

  // 3. UPDATE
  Future<int> updateMakanan(MakananModel makanan) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'master_makanan',
      makanan.toMap(),
      where: 'id = ?',
      whereArgs: [makanan.id],
    );
  }

  // 4. DELETE (Soft Delete)
  Future<int> arsipMakanan(int id) async {
    Database db = await _dbHelper.database;
    return await db.update(
      'master_makanan',
      {'aktif': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // SEARCH untuk TypeAhead lokal
  Future<List<MakananModel>> searchMakanan(String keyword) async {
    Database db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'master_makanan',
      where: 'aktif = ? AND nama LIKE ?',
      whereArgs: [1, '%$keyword%'],
    );
    return List.generate(maps.length, (i) => MakananModel.fromMap(maps[i]));
  }
}

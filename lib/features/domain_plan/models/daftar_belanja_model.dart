class DaftarBelanjaModel {
  final int? id;
  final int? makananId; // Bisa null kalau item ditambahkan manual
  final String namaItem;
  final double jumlahTotal;
  final String satuan;
  final String mingguKe;
  final int sudahDibeli; // 0 = belum, 1 = sudah
  final String sumber; // 'auto' (dari meal plan) atau 'manual'

  DaftarBelanjaModel({
    this.id,
    this.makananId,
    required this.namaItem,
    required this.jumlahTotal,
    required this.satuan,
    required this.mingguKe,
    this.sudahDibeli = 0,
    this.sumber = 'auto',
  });

  factory DaftarBelanjaModel.fromMap(Map<String, dynamic> map) {
    return DaftarBelanjaModel(
      id: map['id'],
      makananId: map['makanan_id'],
      namaItem: map['nama_item'],
      jumlahTotal: map['jumlah_total'],
      satuan: map['satuan'],
      mingguKe: map['minggu_ke'],
      sudahDibeli: map['sudah_dibeli'],
      sumber: map['sumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'makanan_id': makananId,
      'nama_item': namaItem,
      'jumlah_total': jumlahTotal,
      'satuan': satuan,
      'minggu_ke': mingguKe,
      'sudah_dibeli': sudahDibeli,
      'sumber': sumber,
    };
  }
}
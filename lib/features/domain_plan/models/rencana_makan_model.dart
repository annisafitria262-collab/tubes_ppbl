class RencanaMakanModel {
  final int? id;
  final int makananId; // Foreign Key ke master_makanan
  final String hari;
  final String waktuMakan;
  final double jumlahGram;
  final String mingguKe; // Format: YYYY-WW
  final String status;

  // Variabel ekstra untuk kemudahan UI (hasil JOIN)
  final String? namaMakanan;
  final double? kaloriPer100g;

  RencanaMakanModel({
    this.id,
    required this.makananId,
    required this.hari,
    required this.waktuMakan,
    required this.jumlahGram,
    required this.mingguKe,
    this.status = 'DRAFT',
    this.namaMakanan,
    this.kaloriPer100g,
  });

  factory RencanaMakanModel.fromMap(Map<String, dynamic> map) {
    return RencanaMakanModel(
      id: map['id'],
      makananId: map['makanan_id'],
      hari: map['hari'],
      waktuMakan: map['waktu_makan'],
      jumlahGram: map['jumlah_gram'],
      mingguKe: map['minggu_ke'],
      status: map['status'],
      namaMakanan: map['nama_makanan'],
      kaloriPer100g: map['kalori_per_100g'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'makanan_id': makananId,
      'hari': hari,
      'waktu_makan': waktuMakan,
      'jumlah_gram': jumlahGram,
      'minggu_ke': mingguKe,
      'status': status,
    };
  }
}
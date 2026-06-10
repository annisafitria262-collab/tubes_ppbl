class LogKonsumsiModel {
  final int? id;
  final int makananId;
  final String tanggal;
  final String waktuMakan;
  final double jumlahGram;
  final double kaloriTotal;
  final double? proteinTotal;
  final double? karboTotal;
  final double? lemakTotal;
  final String? catatan;

  // Variabel JOIN
  final String? namaMakanan;

  LogKonsumsiModel({
    this.id,
    required this.makananId,
    required this.tanggal,
    required this.waktuMakan,
    required this.jumlahGram,
    required this.kaloriTotal,
    this.proteinTotal,
    this.karboTotal,
    this.lemakTotal,
    this.catatan,
    this.namaMakanan,
  });

  factory LogKonsumsiModel.fromMap(Map<String, dynamic> map) {
    return LogKonsumsiModel(
      id: map['id'],
      makananId: map['makanan_id'],
      tanggal: map['tanggal'],
      waktuMakan: map['waktu_makan'],
      jumlahGram: (map['jumlah_gram'] as num).toDouble(),
      kaloriTotal: (map['kalori_total'] as num).toDouble(),
      proteinTotal: map['protein_total'] != null ? (map['protein_total'] as num).toDouble() : null,
      karboTotal: map['karbo_total'] != null ? (map['karbo_total'] as num).toDouble() : null,
      lemakTotal: map['lemak_total'] != null ? (map['lemak_total'] as num).toDouble() : null,
      catatan: map['catatan'],
      namaMakanan: map['nama_makanan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'makanan_id': makananId,
      'tanggal': tanggal,
      'waktu_makan': waktuMakan,
      'jumlah_gram': jumlahGram,
      'kalori_total': kaloriTotal,
      'protein_total': proteinTotal,
      'karbo_total': karboTotal,
      'lemak_total': lemakTotal,
      'catatan': catatan,
    };
  }
}

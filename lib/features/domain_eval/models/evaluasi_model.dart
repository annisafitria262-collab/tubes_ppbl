class EvaluasiModel {
  int? id;
  String tanggal;
  double targetKalori;
  double kaloriAktual;
  double surplusDefisit;
  String status;
  double proteinTotal;
  double karboTotal;
  double lemakTotal;
  bool isStrict;
  int langkahKaki;

  EvaluasiModel({
    this.id,
    required this.tanggal,
    required this.targetKalori,
    required this.kaloriAktual,
    required this.surplusDefisit,
    required this.status,
    this.proteinTotal = 0.0,
    this.karboTotal = 0.0,
    this.lemakTotal = 0.0,
    this.isStrict = false,
    this.langkahKaki = 0,
  });

  // Mengubah objek Dart jadi Map (Buat INSERT ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal,
      'target_kalori': targetKalori,
      'kalori_aktual': kaloriAktual,
      'surplus_defisit': surplusDefisit,
      'status': status,
      'protein_total': proteinTotal,
      'karbo_total': karboTotal,
      'lemak_total': lemakTotal,
      'is_strict': isStrict ? 1 : 0,
      'langkah_kaki': langkahKaki,
    };
  }

  // Mengubah Map dari SQLite balik jadi objek Dart (Buat READ/Tampil data)
  factory EvaluasiModel.fromMap(Map<String, dynamic> map) {
    return EvaluasiModel(
      id: map['id'],
      tanggal: map['tanggal'],
      targetKalori: map['target_kalori'],
      kaloriAktual: map['kalori_aktual'],
      surplusDefisit: map['surplus_defisit'],
      status: map['status'],
      proteinTotal: map['protein_total'],
      karboTotal: map['karbo_total'],
      lemakTotal: map['lemak_total'],
      isStrict: map['is_strict'] == 1,
      langkahKaki: map['langkah_kaki'] ?? 0,
    );
  }
}
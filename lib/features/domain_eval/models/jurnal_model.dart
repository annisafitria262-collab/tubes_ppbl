class JurnalModel {
  int? id;
  int evaluasiId;
  String rootCause;
  String? catatan;
  int moodScore;
  int dibuatPada;

  JurnalModel({
    this.id,
    required this.evaluasiId,
    required this.rootCause,
    this.catatan,
    this.moodScore = 3,
    required this.dibuatPada,
  });

  // Mengubah objek Dart jadi Map (Buat INSERT ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'evaluasi_id': evaluasiId,
      'root_cause': rootCause,
      'catatan': catatan,
      'mood_score': moodScore,
      'dibuat_pada': dibuatPada,
    };
  }

  // Mengubah Map dari SQLite balik jadi objek Dart (Buat READ/Tampil data)
  factory JurnalModel.fromMap(Map<String, dynamic> map) {
    return JurnalModel(
      id: map['id'],
      evaluasiId: map['evaluasi_id'],
      rootCause: map['root_cause'],
      catatan: map['catatan'],
      moodScore: map['mood_score'],
      dibuatPada: map['dibuat_pada'],
    );
  }
}
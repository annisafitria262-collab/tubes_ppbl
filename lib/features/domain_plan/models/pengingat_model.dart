class PengingatModel {
  final int? id;
  final String judul;
  final String hari; // e.g. 'Senin', 'Selasa', dll.
  final String jam;  // e.g. '08:30' (format HH:mm)
  final int aktif;   // 1 = aktif, 0 = nonaktif

  PengingatModel({
    this.id,
    required this.judul,
    required this.hari,
    required this.jam,
    this.aktif = 1,
  });

  factory PengingatModel.fromMap(Map<String, dynamic> map) {
    return PengingatModel(
      id: map['id'],
      judul: map['judul'],
      hari: map['hari'],
      jam: map['jam'],
      aktif: map['aktif'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'judul': judul,
      'hari': hari,
      'jam': jam,
      'aktif': aktif,
    };
  }

  PengingatModel copyWith({
    int? id,
    String? judul,
    String? hari,
    String? jam,
    int? aktif,
  }) {
    return PengingatModel(
      id: id ?? this.id,
      judul: judul ?? this.judul,
      hari: hari ?? this.hari,
      jam: jam ?? this.jam,
      aktif: aktif ?? this.aktif,
    );
  }
}

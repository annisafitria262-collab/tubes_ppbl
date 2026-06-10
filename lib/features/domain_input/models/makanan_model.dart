class MakananModel {
  final int? id;
  final String nama;
  final double kaloriPer100g;
  final double proteinG;
  final double karboG;
  final double lemakG;
  final String satuanDefault;
  final String? kategori;
  final String sumber;
  final int aktif;

  MakananModel({
    this.id,
    required this.nama,
    required this.kaloriPer100g,
    required this.proteinG,
    required this.karboG,
    required this.lemakG,
    this.satuanDefault = 'gram',
    this.kategori,
    this.sumber = 'manual',
    this.aktif = 1,
  });

  // Convert dari Map (SQLite) ke Object
  factory MakananModel.fromMap(Map<String, dynamic> map) {
    return MakananModel(
      id: map['id'],
      nama: map['nama'],
      kaloriPer100g: map['kalori_per_100g'],
      proteinG: map['protein_g'],
      karboG: map['karbo_g'],
      lemakG: map['lemak_g'],
      satuanDefault: map['satuan_default'],
      kategori: map['kategori'],
      sumber: map['sumber'],
      aktif: map['aktif'],
    );
  }

  // Convert dari Object ke Map (Untuk insert ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kalori_per_100g': kaloriPer100g,
      'protein_g': proteinG,
      'karbo_g': karboG,
      'lemak_g': lemakG,
      'satuan_default': satuanDefault,
      'kategori': kategori,
      'sumber': sumber,
      'aktif': aktif,
    };
  }
}
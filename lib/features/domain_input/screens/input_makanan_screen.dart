import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/makanan_model.dart';
import '../models/log_konsumsi_model.dart';
import '../repositories/makanan_repository.dart';
import '../repositories/log_konsumsi_repository.dart';
import '../services/api_service.dart';
import '../widgets/macro_arc_dashboard.dart';
import '../widgets/nutrition_donut_widget.dart';
import '../widgets/calorie_burn_timeline.dart';
import '../../../core/utils/shared_prefs_helper.dart';

class InputMakananScreen extends StatefulWidget {
  const InputMakananScreen({super.key});

  @override
  State<InputMakananScreen> createState() => _InputMakananScreenState();
}

class _InputMakananScreenState extends State<InputMakananScreen>
    with SingleTickerProviderStateMixin {
  final OpenFoodFactsService _apiService = OpenFoodFactsService();
  final LogKonsumsiRepository _logRepo = LogKonsumsiRepository();
  final MakananRepository _makananRepo = MakananRepository();
  final TextEditingController _searchController = TextEditingController();

  late TabController _filterTabController;

  double _kaloriAktual = 0;
  double _proteinAktual = 0;
  double _karboAktual = 0;
  double _lemakAktual = 0;
  List<LogKonsumsiModel> _logHariIni = [];
  bool _isLoading = true;
  bool _isOffline = false;
  final String _hariIni = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Filter waktu makan: 0=Semua, 1=Sarapan, 2=Makan Siang, 3=Makan Malam, 4=Camilan
  static const List<String> _waktuMakanOptions = [
    'SARAPAN', 'MAKAN_SIANG', 'MAKAN_MALAM', 'CAMILAN',
  ];
  static const List<String> _filterLabels = [
    'Semua', 'Sarapan', 'Siang', 'Malam', 'Camilan',
  ];
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    _filterTabController = TabController(length: 5, vsync: this);
    _filterTabController.addListener(() {
      if (!_filterTabController.indexIsChanging) {
        setState(() => _filterIndex = _filterTabController.index);
      }
    });
    _loadDataHarian();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none) || result.isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _filterTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataHarian() async {
    setState(() => _isLoading = true);
    final kalori = await _logRepo.getTotalKaloriHariIni(_hariIni);
    final macros = await _logRepo.getTotalMacroHariIni(_hariIni);
    final logs = await _logRepo.getLogsByDate(_hariIni);
    if (mounted) {
      setState(() {
        _kaloriAktual = kalori;
        _proteinAktual = macros['protein'] ?? 0;
        _karboAktual = macros['karbo'] ?? 0;
        _lemakAktual = macros['lemak'] ?? 0;
        _logHariIni = logs;
        _isLoading = false;
      });
    }
  }

  List<LogKonsumsiModel> get _filteredLogs {
    if (_filterIndex == 0) return _logHariIni;
    final waktu = _waktuMakanOptions[_filterIndex - 1];
    return _logHariIni.where((l) => l.waktuMakan == waktu).toList();
  }

  void _onMakananTerpilih(MakananModel makanan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          _DialogTambahLog(makanan: makanan, waktuOptions: _waktuMakanOptions),
    );
    if (result == null) return;

    // Cek apakah makanan dari API sudah ada di DB (cegah duplikat)
    final existing = await _makananRepo.searchMakanan(makanan.nama);
    int makananId;
    if (existing.isNotEmpty && makanan.sumber == 'open_food_facts') {
      // Pakai yang sudah ada
      makananId = existing.first.id!;
    } else {
      makananId = await _makananRepo.insertMakanan(makanan);
    }

    final double gram = result['gram'];
    final String waktu = result['waktu'];
    final double kaloriTotal = (makanan.kaloriPer100g * gram) / 100;

    final logBaru = LogKonsumsiModel(
      makananId: makananId,
      tanggal: _hariIni,
      waktuMakan: waktu,
      jumlahGram: gram,
      kaloriTotal: kaloriTotal,
      proteinTotal: (makanan.proteinG * gram) / 100,
      karboTotal: (makanan.karboG * gram) / 100,
      lemakTotal: (makanan.lemakG * gram) / 100,
    );
    await _logRepo.insertLog(logBaru);
    _searchController.clear();
    await _loadDataHarian();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
                child: Text('${makanan.nama} (+${kaloriTotal.toInt()} kkal) ditambahkan! 🥗')),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showTambahManualDialog() async {
    final namaCtrl = TextEditingController();
    final kaloriCtrl = TextEditingController(text: '100');
    final proteinCtrl = TextEditingController(text: '0');
    final karboCtrl = TextEditingController(text: '0');
    final lemakCtrl = TextEditingController(text: '0');
    final List<String> kategoriOptions = [
      'Karbohidrat', 'Protein', 'Sayur', 'Buah', 'Minuman', 'Snack', 'Lainnya'
    ];
    String? selectedKategori = 'Lainnya';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          // ---> PERBAIKAN: Bungkus judul dengan Expanded <---
          title: Row(children: [
            const Icon(Icons.add_box, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            const Expanded(child: Text('Tambah Makanan Manual')),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Makanan *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: kaloriCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kalori/100g *',
                        border: OutlineInputBorder(),
                        suffixText: 'kkal',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedKategori,
                      // ---> PERBAIKAN: Agar dropdown tidak menabrak <---
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: kategoriOptions
                          .map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setD(() => selectedKategori = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Protein',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: karboCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Karbo',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lemakCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Lemak',
                        border: OutlineInputBorder(),
                        suffixText: 'g',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blue),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Semua nilai nutrisi per 100 gram makanan',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Simpan & Log'),
              onPressed: () async {
                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Nama makanan wajib diisi!')),
                  );
                  return;
                }
                final makananBaru = MakananModel(
                  nama: nama,
                  kaloriPer100g: double.tryParse(kaloriCtrl.text) ?? 100,
                  proteinG: double.tryParse(proteinCtrl.text) ?? 0,
                  karboG: double.tryParse(karboCtrl.text) ?? 0,
                  lemakG: double.tryParse(lemakCtrl.text) ?? 0,
                  kategori: selectedKategori,
                  sumber: 'manual',
                );
                Navigator.pop(ctx);
                _onMakananTerpilih(makananBaru);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(LogKonsumsiModel log) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) =>
          _DialogEditLog(log: log, waktuOptions: _waktuMakanOptions),
    );
    if (result == null) return;

    final makanan = await _makananRepo.getMakananById(log.makananId);
    if (makanan == null) return;

    final double gram = result['gram'];
    final String waktu = result['waktu'];
    final double kaloriTotal = (makanan.kaloriPer100g * gram) / 100;

    final updatedLog = LogKonsumsiModel(
      id: log.id,
      makananId: log.makananId,
      tanggal: log.tanggal,
      waktuMakan: waktu,
      jumlahGram: gram,
      kaloriTotal: kaloriTotal,
      proteinTotal: (makanan.proteinG * gram) / 100,
      karboTotal: (makanan.karboG * gram) / 100,
      lemakTotal: (makanan.lemakG * gram) / 100,
      catatan: log.catatan,
    );
    await _logRepo.updateLog(updatedLog);
    await _loadDataHarian();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.edit, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Log konsumsi berhasil diperbarui ✅'),
          ]),
          backgroundColor: Color(0xFF0D47A1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _deleteLog(LogKonsumsiModel log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('Hapus Log'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hapus "${log.namaMakanan}" dari jurnal hari ini?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${log.kaloriTotal.toInt()} kkal akan dikurangi dari total harian.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Hapus'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _logRepo.deleteLog(log.id!);
    await _loadDataHarian();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.delete, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Log konsumsi dihapus 🗑️'),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSettingsDialog() async {
    double target = SharedPrefsHelper.dailyCalorieTarget;
    String macro = SharedPrefsHelper.macroRatioPreference;
    final targetCtrl = TextEditingController(text: target.toInt().toString());
    String? selectedMacro = macro;

    // Map label yang lebih deskriptif
    const Map<String, String> macroLabels = {
      '50:25:25': '50:25:25 — Seimbang (Balanced)',
      '30:40:30': '30:40:30 — Tinggi Protein',
      '25:35:40': '25:35:40 — Rendah Karbo',
      '5:25:70': '5:25:70 — Keto',
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.tune, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Pengaturan Nutrisi'),
          ]),
          // ---> PERBAIKAN: Bungkus seluruh konten dengan SingleChildScrollView <---
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info nilai saat ini
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF2E7D32), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Target saat ini: ${target.toInt()} kkal\nRasio: $macro',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ]),
                ),
                const Text('🎯 Target Kalori Harian',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: 'kkal',
                    hintText: 'Contoh: 2000',
                    prefixIcon: Icon(Icons.local_fire_department),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('⚖️ Rasio Makro (Karbo:Protein:Lemak)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMacro,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  isExpanded: true,
                  items: macroLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedMacro = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 Perubahan rasio makro akan otomatis memperbarui tampilan Macro Arc.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Simpan'),
              onPressed: () async {
                final newTarget =
                    double.tryParse(targetCtrl.text) ?? 2000;
                await SharedPrefsHelper.setDailyCalorieTarget(newTarget);
                
                if (selectedMacro != null) {
                  // ---> KUNCI PERBAIKAN: SINKRONISASI 2 ARAH! <---
                  // Kita ubah rasio makro pilihan Athaya menjadi Tipe Diet milik Aca
                  String tipeDietAca = 'BALANCED';
                  if (selectedMacro == '30:40:30') tipeDietAca = 'HIGH_PROTEIN';
                  else if (selectedMacro == '25:35:40') tipeDietAca = 'LOW_CARB';
                  else if (selectedMacro == '5:25:70') tipeDietAca = 'KETO';
                  
                  // Gunakan fungsi Aca, yang otomatis juga mengupdate rasio Athaya!
                  await SharedPrefsHelper.setDefaultDietType(tipeDietAca);
                }
                
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Target: ${newTarget.toInt()} kkal  •  Rasio: $selectedMacro ✅'),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Parsing macro ratio dari SharedPrefs "50:25:25" → {karbo:0.5, protein:0.25, lemak:0.25}
  Map<String, double> _parseMacroRatio() {
    final ratio = SharedPrefsHelper.macroRatioPreference;
    final parts = ratio.split(':');
    if (parts.length != 3) {
      return {'karbo': 0.5, 'protein': 0.25, 'lemak': 0.25};
    }
    final karbo = double.tryParse(parts[0]) ?? 50;
    final protein = double.tryParse(parts[1]) ?? 25;
    final lemak = double.tryParse(parts[2]) ?? 25;
    final total = karbo + protein + lemak;
    return {
      'karbo': karbo / total,
      'protein': protein / total,
      'lemak': lemak / total,
    };
  }

  String _formatWaktu(String w) {
    switch (w) {
      case 'SARAPAN':
        return 'Sarapan';
      case 'MAKAN_SIANG':
        return 'Makan Siang';
      case 'MAKAN_MALAM':
        return 'Makan Malam';
      case 'CAMILAN':
        return 'Camilan';
      default:
        return w;
    }
  }

  Color _waktuColor(String w) {
    switch (w) {
      case 'SARAPAN':
        return const Color(0xFFFFB300);
      case 'MAKAN_SIANG':
        return const Color(0xFF2E7D32);
      case 'MAKAN_MALAM':
        return const Color(0xFF1565C0);
      case 'CAMILAN':
        return const Color(0xFFAD1457);
      default:
        return Colors.grey;
    }
  }

  IconData _waktuIcon(String w) {
    switch (w) {
      case 'SARAPAN':
        return Icons.wb_sunny;
      case 'MAKAN_SIANG':
        return Icons.wb_cloudy;
      case 'MAKAN_MALAM':
        return Icons.nights_stay;
      case 'CAMILAN':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetKalori = SharedPrefsHelper.dailyCalorieTarget;
    final macroRatio = _parseMacroRatio();
    final ratioStr = SharedPrefsHelper.macroRatioPreference;

    // Hitung persentase macro aktual berdasarkan target kalori × rasio
    final targetKarboKal = targetKalori * macroRatio['karbo']!;
    final targetProteinKal = targetKalori * macroRatio['protein']!;
    final targetLemakKal = targetKalori * macroRatio['lemak']!;

    // 1g karbo=4kkal, 1g protein=4kkal, 1g lemak=9kkal
    final double persenKarbo =
        targetKarboKal > 0 ? (_karboAktual * 4) / targetKarboKal : 0;
    final double persenProtein =
        targetProteinKal > 0 ? (_proteinAktual * 4) / targetProteinKal : 0;
    final double persenLemak =
        targetLemakKal > 0 ? (_lemakAktual * 9) / targetLemakKal : 0;

    final sisa = targetKalori - _kaloriAktual;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jurnal Makanan',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'id').format(DateTime.now()),
              style:
                  const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Tombol Tambah Makanan Manual di AppBar
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Tambah Makanan Manual',
            onPressed: _showTambahManualDialog,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Pengaturan Target',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 12),
                  Text('Memuat data harian...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDataHarian,
              color: const Color(0xFF2E7D32),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── SHARED PREFS INFO BANNER ───────────────────────────
                    _buildSharedPrefsBanner(targetKalori, ratioStr, sisa),
                    const SizedBox(height: 16),

                    // ─── NUTRITION DONUT (Custom Widget Interaktif) ──────────
                    // Widget baru: donut chart interaktif dengan animasi fill
                    // dan tap-to-detail per makro. Tap chip untuk highlight.
                    Center(
                      child: NutritionDonutWidget(
                        kaloriAktual: _kaloriAktual,
                        kaloriTarget: targetKalori,
                        proteinAktual: _proteinAktual,
                        proteinTarget: targetKalori * macroRatio['protein']! / 4,
                        karboAktual: _karboAktual,
                        karboTarget: targetKalori * macroRatio['karbo']! / 4,
                        lemakAktual: _lemakAktual,
                        lemakTarget: targetKalori * macroRatio['lemak']! / 9,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── CALORIE BURN TIMELINE ───────────────────────────────
                    // Widget baru: timeline makan hari ini per sesi waktu.
                    // Tap tiap sesi untuk expand daftar makanan.
                    CalorieBurnTimeline(
                      allLogs: _logHariIni,
                      kaloriTarget: targetKalori,
                    ),
                    const SizedBox(height: 8),

                    // ─── SEARCH API (TypeAhead) ──────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.search,
                            color: Color(0xFF2E7D32), size: 20),
                        const SizedBox(width: 6),
                        const Text('Cari & Tambah Makanan',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Manual', style: TextStyle(fontSize: 12)),
                          onPressed: _showTambahManualDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tampilkan nama makanan terakhir yang dicari via API
                    Builder(builder: (context) {
                      final lastName = SharedPrefsHelper.cachedMealName;
                      final lastDate = SharedPrefsHelper.lastApiDate;
                      if (lastName.isEmpty || lastDate.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final isToday = lastDate == _hariIni;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              isToday
                                  ? 'Terakhir dicari hari ini: $lastName'
                                  : 'Terakhir dicari ($lastDate): $lastName',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),
                    TypeAheadField<MakananModel>(
                      controller: _searchController,
                      builder: (context, controller, focusNode) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText:
                                'Ketik min. 3 karakter (via Open Food Facts API)...',
                            prefixIcon:
                                const Icon(Icons.search),
                            suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => controller.clear(),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFF2E7D32), width: 2),
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context) => const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E7D32)),
                            ),
                            SizedBox(width: 8),
                            Text('Mencari di Open Food Facts...',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      emptyBuilder: (context) => Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          _isOffline
                              ? 'Tidak ada koneksi internet. Tambahkan makanan secara manual.'
                              : 'Makanan tidak ditemukan. Coba tambahkan manual.',
                          style: TextStyle(
                            color: _isOffline
                                ? Colors.orange.shade700
                                : Colors.grey,
                          ),
                        ),
                      ),
                      suggestionsCallback: (pattern) async {
                        if (pattern.length < 3) return [];
                        await _checkConnectivity();
                        if (_isOffline) return [];
                        return await _apiService.searchFoodItem(pattern);
                      },
                      itemBuilder: (context, MakananModel suggestion) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE8F5E9),
                            child: Text(
                              suggestion.nama.isNotEmpty
                                  ? suggestion.nama[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(suggestion.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${suggestion.kaloriPer100g.toStringAsFixed(0)} kkal  •  '
                            'P:${suggestion.proteinG.toStringAsFixed(1)}g  '
                            'K:${suggestion.karboG.toStringAsFixed(1)}g  '
                            'L:${suggestion.lemakG.toStringAsFixed(1)}g / 100g',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.add_circle,
                              color: Color(0xFF2E7D32)),
                        );
                      },
                      onSelected: (MakananModel suggestion) {
                        // Cache nama & tanggal makanan dari API ke SharedPrefs
                        if (suggestion.sumber == 'open_food_facts') {
                          SharedPrefsHelper.setCachedMealName(suggestion.nama);
                          SharedPrefsHelper.setLastApiDate(_hariIni);
                        }
                        _onMakananTerpilih(suggestion);
                      },
                    ),
                    const SizedBox(height: 24),

                    // ─── LOG KONSUMSI HARI INI ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.list_alt,
                              color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 6),
                          const Text('Dimakan Hari Ini',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_logHariIni.length} item',
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ─── FILTER TAB WAKTU MAKAN ─────────────────────────────
                    TabBar(
                      controller: _filterTabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: const Color(0xFF2E7D32),
                      labelColor: const Color(0xFF2E7D32),
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      tabs: _filterLabels
                          .map((l) => Tab(text: l))
                          .toList(),
                    ),
                    const SizedBox(height: 10),

                    // ─── DAFTAR LOG (difilter) ──────────────────────────────
                    _filteredLogs.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredLogs.length,
                            itemBuilder: (context, index) {
                              final log = _filteredLogs[index];
                              return _buildLogCard(log);
                            },
                          ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSharedPrefsBanner(
      double targetKalori, String ratioStr, double sisa) {
    final isOver = sisa < 0;
    return Card(
      elevation: 0,
      color: isOver ? const Color(0xFFFCE4EC) : const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOver ? Colors.red.shade200 : const Color(0xFF81C784),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              isOver ? Icons.warning_amber : Icons.local_fire_department,
              color: isOver ? Colors.red : const Color(0xFF2E7D32),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOver
                        ? 'Melebihi target ${(-sisa).toInt()} kkal!'
                        : 'Sisa ${sisa.toInt()} kkal dari target',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          isOver ? Colors.red.shade700 : const Color(0xFF1B5E20),
                    ),
                  ),
                  Text(
                    'Target: ${targetKalori.toInt()} kkal  •  Rasio: $ratioStr',
                    style: TextStyle(
                        fontSize: 11,
                        color: isOver ? Colors.red.shade400 : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // Tombol edit setting langsung dari banner
            InkWell(
              onTap: _showSettingsDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOver ? Colors.red.shade100 : const Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit,
                        size: 12,
                        color: isOver
                            ? Colors.red.shade700
                            : const Color(0xFF2E7D32)),
                    const SizedBox(width: 3),
                    Text(
                      'Ubah',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOver
                              ? Colors.red.shade700
                              : const Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_food,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _filterIndex == 0
                  ? 'Belum ada makanan yang dicatat hari ini.'
                  : 'Tidak ada log untuk ${_filterLabels[_filterIndex]}.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cari makanan di atas atau tambah secara manual.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(LogKonsumsiModel log) {
    final color = _waktuColor(log.waktuMakan);
    final icon = _waktuIcon(log.waktuMakan);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            // Waktu Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),

            // Info makanan
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.namaMakanan ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatWaktu(log.waktuMakan),
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${log.jumlahGram.toStringAsFixed(0)} g',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ]),
                  if (log.proteinTotal != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'P:${log.proteinTotal!.toStringAsFixed(1)}  '
                      'K:${log.karboTotal?.toStringAsFixed(1) ?? '-'}  '
                      'L:${log.lemakTotal?.toStringAsFixed(1) ?? '-'} g',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),

            // Kalori + aksi
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${log.kaloriTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color),
                ),
                const Text('kkal',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showEditDialog(log),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit,
                            color: Color(0xFF0D47A1), size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteLog(log),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.delete_outline,
                            color: Colors.red.shade700, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── DIALOG TAMBAH LOG ────────────────────────────────
class _DialogTambahLog extends StatefulWidget {
  final MakananModel makanan;
  final List<String> waktuOptions;
  const _DialogTambahLog(
      {required this.makanan, required this.waktuOptions});

  @override
  State<_DialogTambahLog> createState() => _DialogTambahLogState();
}

class _DialogTambahLogState extends State<_DialogTambahLog> {
  final _gramCtrl = TextEditingController(text: '100');
  String _selectedWaktu = 'MAKAN_SIANG';

  double get _kaloriPreview {
    final gram = double.tryParse(_gramCtrl.text) ?? 100;
    return (widget.makanan.kaloriPer100g * gram) / 100;
  }

  double get _proteinPreview {
    final gram = double.tryParse(_gramCtrl.text) ?? 100;
    return (widget.makanan.proteinG * gram) / 100;
  }

  double get _karboPreview {
    final gram = double.tryParse(_gramCtrl.text) ?? 100;
    return (widget.makanan.karboG * gram) / 100;
  }

  double get _lemakPreview {
    final gram = double.tryParse(_gramCtrl.text) ?? 100;
    return (widget.makanan.lemakG * gram) / 100;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.makanan.nama,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(
            '${widget.makanan.kaloriPer100g.toStringAsFixed(0)} kkal/100g  •  ${widget.makanan.sumber == 'open_food_facts' ? '🌐 API' : '📝 Manual'}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      content: SingleChildScrollView( // ---> PERBAIKAN: Agar aman saat keyboard muncul
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _gramCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porsi (gram)',
                border: OutlineInputBorder(),
                suffixText: 'g',
                prefixIcon: Icon(Icons.scale),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWaktu,
              decoration: const InputDecoration(
                labelText: 'Waktu Makan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              items: widget.waktuOptions
                  .map((w) => DropdownMenuItem(
                      value: w,
                      child: Text(w.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWaktu = v!),
            ),
            const SizedBox(height: 12),
            // Preview nutrisi
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Color(0xFF2E7D32), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${_kaloriPreview.toStringAsFixed(0)} kkal',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _previewChip('P', _proteinPreview, const Color(0xFF0D47A1)),
                      _previewChip('K', _karboPreview, const Color(0xFFEF9F27)),
                      _previewChip('L', _lemakPreview, const Color(0xFFFBC02D)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Tambah ke Jurnal'),
          onPressed: () {
            final gram = double.tryParse(_gramCtrl.text) ?? 100;
            Navigator.pop(
                context, {'gram': gram, 'waktu': _selectedWaktu});
          },
        ),
      ],
    );
  }

  Widget _previewChip(String label, double value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        Text('${value.toStringAsFixed(1)}g',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ─────────────────────── DIALOG EDIT LOG ──────────────────────────────────
class _DialogEditLog extends StatefulWidget {
  final LogKonsumsiModel log;
  final List<String> waktuOptions;
  const _DialogEditLog(
      {required this.log, required this.waktuOptions});

  @override
  State<_DialogEditLog> createState() => _DialogEditLogState();
}

class _DialogEditLogState extends State<_DialogEditLog> {
  late TextEditingController _gramCtrl;
  late String _selectedWaktu;

  @override
  void initState() {
    super.initState();
    _gramCtrl = TextEditingController(
        text: widget.log.jumlahGram.toStringAsFixed(0));
    _selectedWaktu = widget.log.waktuMakan;
    if (!widget.waktuOptions.contains(_selectedWaktu)) {
      _selectedWaktu = widget.waktuOptions.first;
    }
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.edit, color: Color(0xFF0D47A1), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Edit: ${widget.log.namaMakanan ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ]),
      content: SingleChildScrollView( // ---> PERBAIKAN: Agar aman saat keyboard muncul
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info lama
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                Icon(Icons.history, size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text(
                  'Sebelumnya: ${widget.log.jumlahGram.toStringAsFixed(0)}g  •  '
                  '${widget.log.kaloriTotal.toStringAsFixed(0)} kkal',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ]),
            ),
            TextField(
              controller: _gramCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porsi (gram)',
                border: OutlineInputBorder(),
                suffixText: 'g',
                prefixIcon: Icon(Icons.scale),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWaktu,
              decoration: const InputDecoration(
                labelText: 'Waktu Makan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
              items: widget.waktuOptions
                  .map((w) => DropdownMenuItem(
                      value: w,
                      child: Text(w.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWaktu = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton.icon(
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Simpan'),
          onPressed: () {
            final gram = double.tryParse(_gramCtrl.text) ??
                widget.log.jumlahGram;
            Navigator.pop(
                context, {'gram': gram, 'waktu': _selectedWaktu});
          },
        ),
      ],
    );
  }
}
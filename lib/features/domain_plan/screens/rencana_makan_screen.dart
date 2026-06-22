import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/weekly_meal_matrix.dart';
import '../models/rencana_makan_model.dart';
import '../models/daftar_belanja_model.dart';
import '../repositories/rencana_makan_repository.dart';
import '../repositories/daftar_belanja_repository.dart';
import '../../domain_input/repositories/makanan_repository.dart';
import '../../domain_input/models/makanan_model.dart';
import '../services/notification_service.dart';
import '../../../core/utils/shared_prefs_helper.dart';

// Custom Widgets
import '../widgets/stat_chip.dart';
import '../widgets/meal_plan_card.dart';
import '../widgets/shopping_item_card.dart';
import '../widgets/empty_state_view.dart';

// Third-Party Libraries
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:confetti/confetti.dart';

class RencanaMakanScreen extends StatefulWidget {
  const RencanaMakanScreen({super.key});

  @override
  State<RencanaMakanScreen> createState() => _RencanaMakanScreenState();
}

class _RencanaMakanScreenState extends State<RencanaMakanScreen>
    with SingleTickerProviderStateMixin {
  final RencanaMakanRepository _rencanaRepo = RencanaMakanRepository();
  final DaftarBelanjaRepository _belanjaRepo = DaftarBelanjaRepository();
  final MakananRepository _makananRepo = MakananRepository();

  late TabController _tabController;
  late ConfettiController _confettiController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<RencanaMakanModel> _rencanaList = [];
  List<DaftarBelanjaModel> _belanjaList = [];
  List<List<int>> _matrixData =
      List.generate(4, (_) => List.filled(7, 0));

  bool _isLoading = true;

  final List<String> _hariList = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];
  final List<String> _waktuList = [
    'SARAPAN', 'MAKAN_SIANG', 'MAKAN_MALAM', 'CAMILAN'
  ];

  String get _mingguKe {
    final w = _getWeekNumber(_focusedDay);
    return '${_focusedDay.year}-W$w';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _selectedDay = _focusedDay;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final rencana = await _rencanaRepo.getRencanaByMinggu(_mingguKe);
    final belanja = await _belanjaRepo.getDaftarBelanja(_mingguKe);

    // Build matrix dari SQLite — bukan hardcode
    List<List<int>> matrix =
        List.generate(4, (_) => List.filled(7, 0));
    for (var r in rencana) {
      int row = _waktuList.indexOf(r.waktuMakan);
      int col = _hariList.indexOf(r.hari);
      if (row >= 0 && col >= 0) {
        int val = r.status == 'AKTIF' ? 2 : 1;
        if (matrix[row][col] < val) matrix[row][col] = val;
      }
    }

    if (mounted) {
      setState(() {
        _rencanaList = rencana;
        _belanjaList = belanja;
        _matrixData = matrix;
        _isLoading = false;
      });
    }
  }

  void _aktifkanRencanaMingguIni() async {
    final draftCount =
        _rencanaList.where((r) => r.status == 'DRAFT').length;
    if (draftCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada rencana DRAFT. Semua sudah aktif atau kosong.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.shopping_cart_checkout, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Text('Aktifkan Rencana?'),
        ]),
        content: Text(
          '$draftCount rencana DRAFT akan diaktifkan dan daftar belanja akan digenerate otomatis untuk $_mingguKe.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aktifkan')),
        ],
      ),
    );
    if (confirm != true) return;

    await _rencanaRepo.aktifkanRencanaMingguIni(_mingguKe);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$draftCount rencana aktif! Daftar belanja otomatis dibuat. 🛒'),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      // Pindah ke tab belanja untuk lihat hasilnya
      _tabController.animateTo(1);
    }
  }

  // ─────────────────── RENCANA MAKAN CRUD ───────────────────────────────

  void _showTambahRencanaDialog({String? initialHari, String? initialWaktu}) async {
    final makananList = await _makananRepo.getAllMakanan();
    if (!mounted) return;

    if (makananList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Database makanan kosong! Tambahkan makanan di tab Jurnal terlebih dahulu.'),
            ),
          ]),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    MakananModel? selectedMakanan = makananList.first;
    String selectedHari = initialHari ?? _hariList.first;
    String selectedWaktu = initialWaktu ?? _waktuList.first;
    final gramCtrl = TextEditingController(text: '100');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          // ---> PERBAIKAN 1: Tambahkan Expanded di Judul agar tidak nabrak kanan <---
          title: const Row(children: [
            Icon(Icons.calendar_today, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Tambah Rencana Makan', overflow: TextOverflow.ellipsis),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info minggu aktif
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF2E7D32), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Minggu: $_mingguKe',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ]),
                ),
                DropdownButtonFormField<MakananModel>(
                  value: selectedMakanan,
                  decoration: const InputDecoration(
                      labelText: 'Makanan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant)),
                  isExpanded: true,
                  items: makananList
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.nama,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setD(() => selectedMakanan = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedHari,
                      decoration: const InputDecoration(
                          labelText: 'Hari',
                          border: OutlineInputBorder()),
                      items: _hariList
                          .map((h) => DropdownMenuItem(
                              value: h, child: Text(h)))
                          .toList(),
                      onChanged: (v) =>
                          setD(() => selectedHari = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: gramCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Porsi',
                          border: OutlineInputBorder(),
                          suffixText: 'g'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWaktu,
                  decoration: const InputDecoration(
                      labelText: 'Waktu Makan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time)),
                  items: _waktuList
                      .map((w) => DropdownMenuItem(
                          value: w,
                          child: Text(w.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) =>
                      setD(() => selectedWaktu = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah'),
              onPressed: () async {
                if (selectedMakanan == null) return;
                final gram =
                    double.tryParse(gramCtrl.text) ?? 100;
                final rencana = RencanaMakanModel(
                  makananId: selectedMakanan!.id!,
                  hari: selectedHari,
                  waktuMakan: selectedWaktu,
                  jumlahGram: gram,
                  mingguKe: _mingguKe,
                );
                await _rencanaRepo.insertRencana(rencana);
                if (mounted) Navigator.pop(ctx);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${selectedMakanan!.nama} ditambahkan ke rencana $selectedHari ✅'),
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

  void _showEditRencanaDialog(RencanaMakanModel rencana) async {
    String selectedHari = rencana.hari;
    String selectedWaktu = rencana.waktuMakan;
    final gramCtrl = TextEditingController(
        text: rencana.jumlahGram.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.edit, color: Color(0xFF0D47A1), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Edit: ${rencana.namaMakanan ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedHari,
                      decoration: const InputDecoration(
                          labelText: 'Hari',
                          border: OutlineInputBorder()),
                      items: _hariList
                          .map((h) => DropdownMenuItem(
                              value: h, child: Text(h)))
                          .toList(),
                      onChanged: (v) =>
                          setD(() => selectedHari = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: gramCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Porsi',
                          border: OutlineInputBorder(),
                          suffixText: 'g'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedWaktu,
                  decoration: const InputDecoration(
                      labelText: 'Waktu Makan',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time)),
                  items: _waktuList
                      .map((w) => DropdownMenuItem(
                          value: w,
                          child: Text(w.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) =>
                      setD(() => selectedWaktu = v!),
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
                final gram = double.tryParse(gramCtrl.text) ??
                    rencana.jumlahGram;
                final updated = RencanaMakanModel(
                  id: rencana.id,
                  makananId: rencana.makananId,
                  hari: selectedHari,
                  waktuMakan: selectedWaktu,
                  jumlahGram: gram,
                  mingguKe: rencana.mingguKe,
                  status: rencana.status,
                );
                await _rencanaRepo.updateRencana(updated);
                if (mounted) Navigator.pop(ctx);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(children: [
                        Icon(Icons.edit, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('Rencana berhasil diperbarui ✅'),
                      ]),
                      backgroundColor: Color(0xFF0D47A1),
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

  void _deleteRencana(RencanaMakanModel rencana) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('Hapus Rencana'),
        ]),
        content: Text(
            'Hapus "${rencana.namaMakanan}" dari rencana ${rencana.hari}?'),
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
    await _rencanaRepo.deleteRencana(rencana.id!);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.delete, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Rencana makan dihapus 🗑️'),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─────────────────── DAFTAR BELANJA CRUD ──────────────────────────────

  void _showTambahBelanjaDialog() async {
    final namaCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController(text: '1');
    final satuanCtrl = TextEditingController(text: 'gram');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // ---> PERBAIKAN 2: Tambahkan Expanded di Judul agar tidak nabrak kanan <---
        title: const Row(children: [
          Icon(Icons.add_shopping_cart, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Tambah Item Belanja', overflow: TextOverflow.ellipsis),
          ),
        ]),
        // ---> PERBAIKAN 3: Bungkus content dengan SingleChildScrollView agar keyboard aman <---
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Item *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: jumlahCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: satuanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Satuan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah'),
            onPressed: () async {
              if (namaCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Nama item wajib diisi!')),
                );
                return;
              }
              final item = DaftarBelanjaModel(
                namaItem: namaCtrl.text.trim(),
                jumlahTotal:
                    double.tryParse(jumlahCtrl.text) ?? 1,
                satuan: satuanCtrl.text.isEmpty
                    ? 'gram'
                    : satuanCtrl.text,
                mingguKe: _mingguKe,
                sumber: 'manual',
              );
              await _belanjaRepo.insertBelanjaManual(item);
              if (mounted) Navigator.pop(ctx);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.add_shopping_cart,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          '${namaCtrl.text.trim()} ditambahkan ke daftar belanja ✅'),
                    ]),
                    backgroundColor: const Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteBelanjaItem(DaftarBelanjaModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('Hapus Item'),
        ]),
        content:
            Text('Hapus "${item.namaItem}" dari daftar belanja?'),
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
    await _belanjaRepo.deleteItem(item.id!);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.delete, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Item dihapus dari daftar belanja 🗑️'),
          ]),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSettingsDialog() async {
    String shoppingDay = SharedPrefsHelper.shoppingDay;
    String dietType = SharedPrefsHelper.defaultDietType;

    const Map<String, String> dietLabels = {
      'BALANCED': '🥗 BALANCED — Seimbang (50:25:25)',
      'HIGH_PROTEIN': '💪 HIGH PROTEIN — Tinggi Protein (30:40:30)',
      'LOW_CARB': '🥩 LOW CARB — Rendah Karbo (25:35:40)',
      'KETO': '🥑 KETO — Ketogenik (5:25:70)',
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.settings, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Pengaturan Meal Plan', 
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF2E7D32), size: 14),
                        SizedBox(width: 6),
                        Text('Pengaturan aktif:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF2E7D32))),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Hari belanja: $shoppingDay\nTipe diet: $dietType',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF388E3C)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '⚡ Ubah tipe diet akan otomatis memperbarui rasio makro.',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Text('🛒 Hari Belanja Rutin',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: shoppingDay,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today)),
                  items: [
                    'Senin', 'Selasa', 'Rabu', 'Kamis',
                    'Jumat', 'Sabtu', 'Minggu'
                  ]
                      .map((d) => DropdownMenuItem(
                          value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) =>
                      setD(() => shoppingDay = v!),
                ),
                const SizedBox(height: 16),
                const Text('🥗 Tipe Diet Default',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: dietType,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder()),
                  isExpanded: true,
                  items: dietLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setD(() => dietType = v!),
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
                await SharedPrefsHelper.setShoppingDay(shoppingDay);
                await SharedPrefsHelper.setDefaultDietType(dietType);
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                        const Icon(Icons.settings,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Belanja: $shoppingDay  •  Diet: $dietType  •  Rasio makro diperbarui! ✅',
                          ),
                        ),
                      ]),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
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

  void _toggleRencanaStatus(RencanaMakanModel rencana) async {
    final newStatus = rencana.status == 'DRAFT' ? 'AKTIF' : 'DRAFT';
    final updated = RencanaMakanModel(
      id: rencana.id,
      makananId: rencana.makananId,
      hari: rencana.hari,
      waktuMakan: rencana.waktuMakan,
      jumlahGram: rencana.jumlahGram,
      mingguKe: rencana.mingguKe,
      status: newStatus,
    );
    await _rencanaRepo.updateRencana(updated);
    await _loadData();

    if (mounted) {
      Fluttertoast.showToast(
        msg: "Status '${rencana.namaMakanan ?? ''}' diubah menjadi $newStatus",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: newStatus == 'AKTIF' ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1),
        textColor: Colors.white,
      );
    }
  }

  void _showMealOptionsBottomSheet(RencanaMakanModel rencana) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              title: Text(rencana.namaMakanan ?? 'Menu Makanan',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${rencana.hari} - ${_formatWaktu(rencana.waktuMakan)}'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                rencana.status == 'DRAFT' ? Icons.check_circle : Icons.pending,
                color: rencana.status == 'DRAFT' ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1),
              ),
              title: Text(rencana.status == 'DRAFT' ? 'Aktifkan Rencana' : 'Jadikan Draft'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleRencanaStatus(rencana);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF0D47A1)),
              title: const Text('Edit Porsi / Waktu'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditRencanaDialog(rencana);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus Rencana', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteRencana(rencana);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShoppingOptionsBottomSheet(DaftarBelanjaModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              title: Text(item.namaItem,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${item.jumlahTotal.toStringAsFixed(0)} ${item.satuan}  •  Sumber: ${item.sumber}'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                item.sudahDibeli == 1 ? Icons.check_box_outline_blank : Icons.check_box,
                color: const Color(0xFF2E7D32),
              ),
              title: Text(item.sudahDibeli == 1 ? 'Tandai Belum Dibeli' : 'Tandai Sudah Dibeli'),
              onTap: () async {
                Navigator.pop(ctx);
                await _belanjaRepo.toggleSudahDibeli(item.id!, item.sudahDibeli);
                await _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus Item', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteBelanjaItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatWaktu(String w) {
    switch (w) {
      case 'SARAPAN': return 'Sarapan';
      case 'MAKAN_SIANG': return 'Makan Siang';
      case 'MAKAN_MALAM': return 'Makan Malam';
      case 'CAMILAN': return 'Camilan';
      default: return w;
    }
  }



  @override
  Widget build(BuildContext context) {
    final shoppingDay = SharedPrefsHelper.shoppingDay;
    final dietType = SharedPrefsHelper.defaultDietType;
    final macroRatio = SharedPrefsHelper.macroRatioPreference;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meal Plan Mingguan',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              'Minggu: $_mingguKe',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test Notifikasi Belanja',
            onPressed: NotificationService.tampilkanNotifikasiBelanja,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Meal Plan',
            onPressed: _showSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: 'Rencana'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Belanja'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          color: Color(0xFF2E7D32)),
                      SizedBox(height: 12),
                      Text('Memuat data meal plan...',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRencanaTab(dietType, macroRatio),
                    _buildBelanjaTab(shoppingDay),
                  ],
                ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.yellow
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRencanaTab(String dietType, String macroRatio) {
    final draftCount =
        _rencanaList.where((r) => r.status == 'DRAFT').length;
    final aktifCount =
        _rencanaList.where((r) => r.status == 'AKTIF').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2E7D32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── SHARED PREFS BANNER ─────────────────────────────────
            _buildSharedPrefsBanner(dietType, macroRatio, draftCount, aktifCount),
            const SizedBox(height: 16),

            // ─── KALENDER ────────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.week,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadData();
                  },
                  onPageChanged: (focusedDay) {
                    setState(
                        () => _focusedDay = focusedDay);
                    _loadData();
                  },
                  headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(
                        color: Color(0xFF81C784),
                        shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── WEEKLY MEAL MATRIX (data dari SQLite) ────────────────
            WeeklyMealMatrix(
              matrixData: _matrixData,
              hariList: _hariList,
              waktuList: _waktuList,
              onCellTapped: (hari, waktu) {
                int col = _hariList.indexOf(hari);
                int row = _waktuList.indexOf(waktu);
                int status = 0;
                if (row >= 0 && col >= 0 && row < _matrixData.length && col < _matrixData[row].length) {
                  status = _matrixData[row][col];
                }
                String statusText = status == 2 
                    ? 'Aktif' 
                    : status == 1 
                        ? 'Direncanakan (DRAFT)' 
                        : 'Kosong';
                
                Fluttertoast.showToast(
                  msg: "$hari - ${waktu.replaceAll('_', ' ')}: $statusText",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: status == 2 
                      ? const Color(0xFF2E7D32) 
                      : status == 1 
                          ? const Color(0xFF0D47A1) 
                          : Colors.grey.shade700,
                  textColor: Colors.white,
                  fontSize: 13.0,
                );
              },
              onCellDoubleTapped: (hari, waktu) {
                _showTambahRencanaDialog(initialHari: hari, initialWaktu: waktu);
              },
            ),
            const SizedBox(height: 16),

            // ─── TOMBOL AKTIFKAN ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: draftCount > 0
                    ? _aktifkanRencanaMingguIni
                    : null,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  draftCount > 0
                      ? 'Aktifkan $draftCount Rencana & Generate Belanja'
                      : 'Semua Rencana Sudah Aktif ✅',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── LIST RENCANA MAKAN ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.list_alt,
                      color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Rencana Minggu Ini (${_rencanaList.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  onPressed: _showTambahRencanaDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _rencanaList.isEmpty
                ? EmptyStateView(
                    lottieUrl: 'https://lottie.host/801ba681-36b1-4f9b-bd5b-d45cc4bfa934/1c9Qv8Q3Z0.json',
                    title: 'Belum ada rencana makan minggu ini.',
                    description: 'Silakan tambah menu makanan baru ke dalam meal plan mingguan Anda.',
                    buttonText: 'Tambah Sekarang',
                    onButtonPressed: _showTambahRencanaDialog,
                    fallbackIcon: Icons.calendar_today,
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rencanaList.length,
                      itemBuilder: (context, index) {
                        final r = _rencanaList[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: MealPlanCard(
                                rencana: r,
                                onEditPressed: () => _showEditRencanaDialog(r),
                                onDeletePressed: () => _deleteRencana(r),
                                onToggleStatus: () => _toggleRencanaStatus(r),
                                onLongPress: () => _showMealOptionsBottomSheet(r),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPrefsBanner(
      String dietType, String macroRatio, int draftCount, int aktifCount) {
    return Card(
      elevation: 0,
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF81C784)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diet: $dietType  •  Rasio Makro: $macroRatio',
                  style: const TextStyle(
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              InkWell(
                onTap: _showSettingsDialog,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(children: [
                    Icon(Icons.edit,
                        size: 12, color: Color(0xFF2E7D32)),
                    SizedBox(width: 3),
                    Text('Ubah',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32))),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              StatChip(
                icon: Icons.pending,
                label: '$draftCount DRAFT',
                color: const Color(0xFF0D47A1),
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.check_circle,
                label: '$aktifCount AKTIF',
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.grid_view,
                label: '${_rencanaList.length} Total',
                color: Colors.grey.shade600,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBelanjaTab(String shoppingDay) {
    final sudahDibeli =
        _belanjaList.where((b) => b.sudahDibeli == 1).length;
    final totalItem = _belanjaList.length;
    final progress =
        totalItem > 0 ? sudahDibeli / totalItem : 0.0;

    return Column(
      children: [
        // ─── HEADER BELANJA (SharedPrefs shoppingDay) ─────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF81C784)),
          ),
          child: Column(
            children: [
              Row(children: [
                const Icon(Icons.calendar_today,
                    color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jadwal Belanja: $shoppingDay',
                    style: const TextStyle(
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                InkWell(
                  onTap: _showSettingsDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E6C9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(children: [
                      Icon(Icons.edit,
                          size: 12, color: Color(0xFF2E7D32)),
                      SizedBox(width: 3),
                      Text('Ubah',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32))),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              // Progress belanja
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$sudahDibeli/$totalItem item selesai',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
        ),

        // ─── TOMBOL TAMBAH MANUAL ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tambah Item Manual'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32)),
              ),
              onPressed: _showTambahBelanjaDialog,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ─── LIST DAFTAR BELANJA ─────────────────────────────────────
        Expanded(
          child: _belanjaList.isEmpty
              ? const EmptyStateView(
                  lottieUrl: 'https://lottie.host/df236687-fefd-4e9c-a1f9-9069d273a4d7/4eRtfqX5Pq.json',
                  title: 'Daftar belanja kosong.',
                  description: 'Aktifkan rencana makan di tab Rencana atau tambah item manual.',
                  fallbackIcon: Icons.shopping_cart_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF2E7D32),
                  child: AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _belanjaList.length,
                      itemBuilder: (context, index) {
                        final item = _belanjaList[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: ShoppingItemCard(
                                item: item,
                                onToggleChecked: (_) async {
                                  final currentVal = item.sudahDibeli;
                                  final newVal = currentVal == 0 ? 1 : 0;
                                  await _belanjaRepo.toggleSudahDibeli(item.id!, currentVal);
                                  await _loadData();

                                  if (newVal == 1) {
                                    final updatedBelanja = await _belanjaRepo.getDaftarBelanja(_mingguKe);
                                    final allChecked = updatedBelanja.isNotEmpty && updatedBelanja.every((b) => b.sudahDibeli == 1);
                                    if (allChecked) {
                                      _confettiController.play();
                                      if (mounted) {
                                        Fluttertoast.showToast(
                                          msg: "Luar biasa! Semua item belanja telah terpenuhi! 🎉",
                                          toastLength: Toast.LENGTH_LONG,
                                          gravity: ToastGravity.CENTER,
                                          backgroundColor: const Color(0xFF2E7D32),
                                          textColor: Colors.white,
                                        );
                                      }
                                    }
                                  }
                                },
                                onDeletePressed: () => _deleteBelanjaItem(item),
                                onLongPress: () => _showShoppingOptionsBottomSheet(item),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
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
    _selectedDay = _focusedDay;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _showTambahRencanaDialog() async {
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
    String selectedHari = _hariList.first;
    String selectedWaktu = _waktuList.first;
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

  String _formatWaktu(String w) {
    switch (w) {
      case 'SARAPAN': return 'Sarapan';
      case 'MAKAN_SIANG': return 'Makan Siang';
      case 'MAKAN_MALAM': return 'Makan Malam';
      case 'CAMILAN': return 'Camilan';
      default: return w;
    }
  }

  Color _statusColor(String status) =>
      status == 'AKTIF' ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1);

  IconData _statusIcon(String status) =>
      status == 'AKTIF' ? Icons.check_circle : Icons.pending;

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
      body: _isLoading
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
                ? _buildEmptyRencana()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _rencanaList.length,
                    itemBuilder: (context, index) {
                      final r = _rencanaList[index];
                      return _buildRencanaCard(r);
                    },
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
              _statChip(Icons.pending, '$draftCount DRAFT',
                  const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              _statChip(Icons.check_circle, '$aktifCount AKTIF',
                  const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _statChip(Icons.grid_view,
                  '${_rencanaList.length} Total',
                  Colors.grey.shade600),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildRencanaCard(RencanaMakanModel r) {
    final color = _statusColor(r.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                r.hari.substring(0, 3),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color),
              ),
            ),
            const SizedBox(height: 3),
            Icon(_statusIcon(r.status), size: 14, color: color),
          ],
        ),
        title: Text(r.namaMakanan ?? '-',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatWaktu(r.waktuMakan)}  •  ${r.jumlahGram.toStringAsFixed(0)}g',
              style: const TextStyle(fontSize: 12),
            ),
            if (r.kaloriPer100g != null)
              Text(
                '${((r.kaloriPer100g! * r.jumlahGram) / 100).toStringAsFixed(0)} kkal',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(r.status,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.edit,
                  color: Color(0xFF0D47A1), size: 18),
              onPressed: () => _showEditRencanaDialog(r),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 18),
              onPressed: () => _deleteRencana(r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRencana() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Belum ada rencana makan minggu ini.',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Sekarang'),
              onPressed: _showTambahRencanaDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBelanjaTab(String shoppingDay) {
    final belumDibeli =
        _belanjaList.where((b) => b.sudahDibeli == 0).length;
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Daftar belanja kosong.',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15)),
                      const SizedBox(height: 8),
                      Text(
                        'Aktifkan rencana makan di tab Rencana\natau tambah item manual.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF2E7D32),
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _belanjaList.length,
                    itemBuilder: (context, index) {
                      final item = _belanjaList[index];
                      return _buildBelanjaCard(item);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBelanjaCard(DaftarBelanjaModel item) {
    final isBeli = item.sudahDibeli == 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: isBeli ? 0 : 1,
      color: isBeli ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isBeli
              ? Colors.grey.shade300
              : item.sumber == 'auto'
                  ? const Color(0xFF81C784)
                  : Colors.blue.shade200,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isBeli,
          activeColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4)),
          onChanged: (_) async {
            await _belanjaRepo.toggleSudahDibeli(
                item.id!, item.sudahDibeli);
            await _loadData();
          },
        ),
        title: Text(
          item.namaItem,
          style: TextStyle(
            decoration:
                isBeli ? TextDecoration.lineThrough : null,
            color: isBeli ? Colors.grey : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(children: [
          Text(
            '${item.jumlahTotal.toStringAsFixed(0)} ${item.satuan}',
            style: TextStyle(
                color: isBeli ? Colors.grey.shade400 : null,
                fontSize: 12),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: item.sumber == 'auto'
                  ? const Color(0xFFE8F5E9)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.sumber == 'auto' ? '🔄 Auto' : '✏️ Manual',
              style: TextStyle(
                  fontSize: 10,
                  color: item.sumber == 'auto'
                      ? const Color(0xFF2E7D32)
                      : Colors.blue.shade700),
            ),
          ),
        ]),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              color: Colors.red.shade400, size: 20),
          tooltip: 'Hapus item',
          onPressed: () => _deleteBelanjaItem(item),
        ),
      ),
    );
  }
}
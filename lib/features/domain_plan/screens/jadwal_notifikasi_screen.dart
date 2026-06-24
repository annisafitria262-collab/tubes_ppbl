import 'package:flutter/material.dart';
import '../models/pengingat_model.dart';
import '../repositories/pengingat_repository.dart';
import '../services/notification_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class JadwalNotifikasiScreen extends StatefulWidget {
  const JadwalNotifikasiScreen({super.key});

  @override
  State<JadwalNotifikasiScreen> createState() => _JadwalNotifikasiScreenState();
}

class _JadwalNotifikasiScreenState extends State<JadwalNotifikasiScreen> {
  final PengingatRepository _pengingatRepo = PengingatRepository();
  List<PengingatModel> _daftarPengingat = [];
  bool _isLoading = true;

  final List<String> _hariOptions = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _pengingatRepo.getPengingatList();
    if (mounted) {
      setState(() {
        _daftarPengingat = data;
        _isLoading = false;
      });
    }
  }

  void _syncNotification(PengingatModel p) async {
    if (p.aktif == 1) {
      final parts = p.jam.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      await NotificationService.scheduleWeeklyNotification(
        id: p.id!,
        title: '${p.judul} 🔔',
        body: 'Pengingat kustom: Saatnya jadwal ${p.judul.toLowerCase()} Anda!',
        day: p.hari,
        hour: hour,
        minute: minute,
      );
    } else {
      await NotificationService.cancelNotification(p.id!);
    }
  }

  void _toggleActive(PengingatModel p) async {
    await _pengingatRepo.toggleAktif(p.id!, p.aktif);
    await _loadData();
    // Cari data yang terupdate untuk di-sinkronisasi notifikasinya
    final updatedList = await _pengingatRepo.getPengingatList();
    final updatedItem = updatedList.firstWhere((x) => x.id == p.id);
    _syncNotification(updatedItem);

    Fluttertoast.showToast(
      msg: updatedItem.aktif == 1
          ? "Pengingat '${p.judul}' diaktifkan 🔔"
          : "Pengingat '${p.judul}' dinonaktifkan 🔕",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: updatedItem.aktif == 1
          ? const Color(0xFF2E7D32)
          : Colors.grey.shade700,
      textColor: Colors.white,
    );
  }

  void _deletePengingat(PengingatModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red),
          SizedBox(width: 8),
          Text('Hapus Pengingat'),
        ]),
        content: Text('Hapus jadwal pengingat "${p.judul}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.cancelNotification(p.id!);
      await _pengingatRepo.deletePengingat(p.id!);
      await _loadData();

      Fluttertoast.showToast(
        msg: "Pengingat '${p.judul}' dihapus ",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _showFormDialog({PengingatModel? pengingat}) async {
    final isEdit = pengingat != null;
    final titleCtrl =
        TextEditingController(text: isEdit ? pengingat.judul : '');
    String selectedHari = isEdit ? pengingat.hari : 'Senin';
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    if (isEdit) {
      final parts = pengingat.jam.split(':');
      selectedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(
              isEdit ? Icons.edit_calendar : Icons.add_alarm,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Text(isEdit ? 'Ubah Pengingat' : 'Tambah Pengingat'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama / Judul Pengingat',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Misal: Olahraga, Belanja Mingguan',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Hari Pengingat',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedHari,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  items: _hariOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedHari = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Waktu Pengingat',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedTime.format(ctx),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.access_time, color: Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  Fluttertoast.showToast(
                    msg: "Judul pengingat tidak boleh kosong!",
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                  );
                  return;
                }

                final formattedHour =
                    selectedTime.hour.toString().padLeft(2, '0');
                final formattedMinute =
                    selectedTime.minute.toString().padLeft(2, '0');
                final timeStr = '$formattedHour:$formattedMinute';

                final newItem = PengingatModel(
                  id: isEdit ? pengingat.id : null,
                  judul: titleCtrl.text.trim(),
                  hari: selectedHari,
                  jam: timeStr,
                  aktif: isEdit ? pengingat.aktif : 1,
                );

                if (isEdit) {
                  await _pengingatRepo.updatePengingat(newItem);
                } else {
                  final id = await _pengingatRepo.insertPengingat(newItem);
                  // Ambil ID yang didapat dari insert untuk penjadwalan
                  final generatedItem = newItem.copyWith(id: id);
                  _syncNotification(generatedItem);
                }

                if (isEdit) {
                  _syncNotification(newItem);
                }

                Navigator.pop(ctx);
                _loadData();

                Fluttertoast.showToast(
                  msg: isEdit
                      ? "Pengingat diperbarui ✅"
                      : "Pengingat ditambahkan ✅",
                  backgroundColor: const Color(0xFF2E7D32),
                  textColor: Colors.white,
                );
              },
              child: Text(
                isEdit ? 'Simpan' : 'Tambah',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pengingat Kustom',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : _daftarPengingat.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm_off,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada jadwal pengingat kustom.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ketuk tombol + di bawah untuk menambahkan.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _daftarPengingat.length,
                  itemBuilder: (context, index) {
                    final p = _daftarPengingat[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.aktif == 1
                              ? const Color(0xFFE8F5E9)
                              : Colors.grey.shade100,
                          child: Icon(
                            p.aktif == 1 ? Icons.alarm : Icons.alarm_off,
                            color: p.aktif == 1
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                          ),
                        ),
                        title: Text(
                          p.judul,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: p.aktif == 0
                                ? TextDecoration.lineThrough
                                : null,
                            color: p.aktif == 1 ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          'Setiap ${p.hari} pukul ${p.jam}',
                          style: TextStyle(
                            fontSize: 13,
                            color: p.aktif == 1 ? Colors.black54 : Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: p.aktif == 1,
                              activeColor: const Color(0xFF2E7D32),
                              onChanged: (_) => _toggleActive(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showFormDialog(pengingat: p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deletePengingat(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

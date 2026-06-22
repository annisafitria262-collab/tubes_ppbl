import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/utils/shared_prefs_helper.dart'; 
import '../models/evaluasi_model.dart';
import '../models/jurnal_model.dart';
import 'form_evaluasi_screen.dart';
import 'package:intl/intl.dart';

class EvaluasiListScreen extends StatefulWidget {
  const EvaluasiListScreen({super.key});

  @override
  State<EvaluasiListScreen> createState() => _EvaluasiListScreenState();
}

class _EvaluasiListScreenState extends State<EvaluasiListScreen> {
  late Future<List<EvaluasiModel>> _evaluasiList;
  bool _showInsights = true; 

  // ---> TAMBAHAN: VARIABEL STATE UNTUK FILTER <---
  String _selectedStatusFilter = 'Semua';
  bool _filterStrictOnly = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _evaluasiList = DatabaseHelper.instance.getAllEvaluasi();
      _showInsights = SharedPrefsHelper.enableSmartInsights; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Nutrisi', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<EvaluasiModel>>(
        future: _evaluasiList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          // ---> TAMBAHAN: LOGIKA FILTERING DATA <---
          final allData = snapshot.data!;
          final filteredData = allData.where((eval) {
            bool matchStatus = _selectedStatusFilter == 'Semua' || eval.status == _selectedStatusFilter;
            bool matchStrict = !_filterStrictOnly || eval.isStrict == true;
            return matchStatus && matchStrict;
          }).toList();

          int totalLangkahGagal = 0;
          int hariGagal = 0;

          // Cross-Analysis sekarang membaca data yang sudah di-filter
          for (var eval in filteredData) {
            if (eval.status == 'SURPLUS' || eval.status == 'DEFISIT') {
              totalLangkahGagal += eval.langkahKaki;
              hariGagal++;
            }
          }

          double rataLangkah = hariGagal > 0 ? (totalLangkahGagal / hariGagal) : 0;
          bool kurangGerak = rataLangkah < 3000;

          return Column(
            children: [
              // ==========================================
              // ---> TAMBAHAN: UI FITUR FILTER HISTORY <---
              // ==========================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildStatusChip('Semua', Colors.grey),
                    const SizedBox(width: 8),
                    _buildStatusChip('TERCAPAI', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatusChip('SURPLUS', Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatusChip('DEFISIT', Colors.blue),
                    const SizedBox(width: 12),
                    
                    // Garis Pemisah
                    Container(height: 25, width: 1, color: Colors.grey[300]),
                    const SizedBox(width: 12),

                    // Filter Strict Mode
                    FilterChip(
                      label: const Text('🔥 Strict', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: _filterStrictOnly,
                      onSelected: (bool selected) {
                        setState(() {
                          _filterStrictOnly = selected;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: Colors.red[50],
                      checkmarkColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: _filterStrictOnly ? Colors.redAccent : Colors.grey[300]!)
                      ),
                      labelStyle: TextStyle(color: _filterStrictOnly ? Colors.redAccent : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ==========================================
              // CEK JIKA DATA KOSONG SETELAH DIFILTER
              // ==========================================
              if (filteredData.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text("Tidak ada data dengan filter ini", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else ...[
                // JIKA ADA DATA, TAMPILKAN INSIGHT DAN LIST (KODE ASLIMU AMAN)
                if (_showInsights)
                  FutureBuilder<Map<String, int>>(
                    future: DatabaseHelper.instance.getRootCauseStats(), 
                    builder: (context, statsSnapshot) {
                      if (statsSnapshot.hasData && statsSnapshot.data!.isNotEmpty) {
                        var dominantCause = statsSnapshot.data!.entries.reduce((a, b) => a.value > b.value ? a : b);
                        
                        return GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, 
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                              builder: (context) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                    top: 24,
                                    bottom: MediaQuery.of(context).padding.bottom + 24, 
                                  ),
                                  child: SingleChildScrollView( 
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.analytics, size: 30, color: Colors.orange),
                                            const SizedBox(width: 10),
                                            const Text("Analisis Root Cause", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const Divider(height: 30),
                                        Text(
                                          "Berdasarkan pemrosesan riwayat datamu, ini adalah pola utama yang ditemukan:",
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                        ),
                                        const SizedBox(height: 15),
                                        
                                        Container(
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            children: [
                                              const Text("🔥", style: TextStyle(fontSize: 24)),
                                              const SizedBox(width: 15),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Akar Masalah Utama", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 12)),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${dominantCause.key.replaceAll('_', ' ')} (${dominantCause.value} Kejadian)",
                                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.red),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 12),

                                        if (hariGagal > 0)
                                          Container(
                                            padding: const EdgeInsets.all(15),
                                            decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(10)),
                                            child: Row(
                                              children: [
                                                const Text("🏃‍♀️", style: TextStyle(fontSize: 24)),
                                                const SizedBox(width: 15),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text("Korelasi Aktivitas Fisik", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        kurangGerak 
                                                          ? "Hati-hati! Rata-rata langkahmu saat diet gagal sangat rendah (${rataLangkah.toInt()} langkah). Kurang gerak terdeteksi sebagai pemicu pola diet berantakan!"
                                                          : "Hebat! Walau diet melenceng, aktivitas fisikmu tetap terjaga dengan rata-rata ${rataLangkah.toInt()} langkah. Tetap pertahankan!",
                                                        style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        const SizedBox(height: 25),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange, 
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                            ),
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text("Tutup Insight", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                  child: const Icon(Icons.lightbulb, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("⚠️ Smart Insight Terdeteksi!", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Dietmu gagal ${dominantCause.value} kali karena ${dominantCause.key.replaceAll('_', ' ')}. ${hariGagal > 0 && kurangGerak ? 'Ada korelasi kuat dengan kurangnya jalan kaki!' : ''} Klik untuk bedah pola datamu.",
                                        style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.orange),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      return _buildEvaluasiCard(filteredData[index]);
                    },
                  ),
                ),
              ]
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final hasil = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormEvaluasiScreen()),
          );
          if (hasil == true) {
            _refreshData();
          }
        },
        label: const Text("Catat Hari Ini"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  // ---> FUNGSI WIDGET PEMBUAT CHIP FILTER <---
  Widget _buildStatusChip(String label, MaterialColor color) {
    bool isSelected = _selectedStatusFilter == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color[700])),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedStatusFilter = selected ? label : 'Semua';
        });
      },
      backgroundColor: Colors.white,
      selectedColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? color : color[200]!)
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lotties/empty_data.json',
            width: 250,
            height: 250,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          Text("Belum ada history evaluasi.", 
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text("Yuk, mulai catat nutrisimu hari ini!", 
            style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEvaluasiCard(EvaluasiModel eval) {
    double progress = eval.kaloriAktual / eval.targetKalori;
    if (progress > 1.0) progress = 1.0; 

    Color statusColor = eval.status == "TERCAPAI" ? Colors.green : 
                        eval.status == "SURPLUS" ? Colors.orange : Colors.blue;

    DateTime date = DateTime.tryParse(eval.tanggal) ?? DateTime.now();
    String formattedDate = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.calendar_today, color: statusColor, size: 20),
        ),
        title: Text(
          formattedDate, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: statusColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "${NumberFormat.decimalPattern('id').format(eval.kaloriAktual)} / ${NumberFormat.decimalPattern('id').format(eval.targetKalori)} kkal",
                  style: TextStyle(color: Colors.grey[700], fontSize: 12)
                ),
                
                if (eval.langkahKaki > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        const Icon(Icons.directions_walk_rounded, size: 12, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          "${NumberFormat.decimalPattern('id').format(eval.langkahKaki)} langkah",
                          style: const TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eval.isStrict == true)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: eval.status == 'TERCAPAI' ? Colors.amber[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: eval.status == 'TERCAPAI' 
                        ? Colors.amber.withOpacity(0.5) 
                        : Colors.redAccent.withOpacity(0.5)
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      eval.status == 'TERCAPAI' ? Icons.star_rounded : Icons.local_fire_department, 
                      size: 10,
                      color: eval.status == 'TERCAPAI' ? Colors.amber[800] : Colors.redAccent
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "STRICT", 
                      style: TextStyle(
                        fontSize: 8, 
                        color: eval.status == 'TERCAPAI' ? Colors.amber[800] : Colors.redAccent, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ],
                ),
              ),
              
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(eval.status, 
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        children: [
          _buildMacroDetail(eval),
        ],
      ),
    );
  }

  Widget _buildMacroDetail(EvaluasiModel eval) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroItem("Protein", eval.proteinTotal, "gr", Colors.redAccent),
              _macroItem("Karbo", eval.karboTotal, "gr", Colors.orange),
              _macroItem("Lemak", eval.lemakTotal, "gr", Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 15),
          Builder(
            builder: (context) {
              String teksSelisih = "";
              Color warnaTeks = Colors.green[800]!; 

              if (eval.status == "SURPLUS") {
                teksSelisih = "Kelebihan (Surplus): +${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                warnaTeks = Colors.orange[800]!;
              } else if (eval.status == "DEFISIT") {
                teksSelisih = "Kekurangan (Defisit): -${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                warnaTeks = Colors.blue[800]!;
              } else {
                if (eval.kaloriAktual > eval.targetKalori) {
                  teksSelisih = "Lebih Sedikit (Aman): +${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                } else if (eval.kaloriAktual < eval.targetKalori) {
                  teksSelisih = "Kurang Sedikit (Aman): -${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                } else {
                  teksSelisih = "Pas Target! 🎉 (0 kkal)";
                }
              }

              return Text(teksSelisih,
                style: TextStyle(fontWeight: FontWeight.bold, color: warnaTeks, fontSize: 14));
            },
          ),
          const SizedBox(height: 15),
          FutureBuilder<JurnalModel?>(
            future: DatabaseHelper.instance.getJurnalByEvaluasiId(eval.id!),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final jurnal = snapshot.data!;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text("Root Cause: ${jurnal.rootCause.replaceAll('_', ' ')}", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[800])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('"${jurnal.catatan}"', 
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87)),
                    ],
                  ),
                );
              }
              return const SizedBox(); 
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final hasil = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FormEvaluasiScreen(evaluasiToEdit: eval),
                    ),
                  );
                  if (hasil == true) {
                    _refreshData();
                  }
                }, 
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20), 
                label: const Text("Edit", style: TextStyle(color: Colors.blue)),
              ),
              const SizedBox(width: 10),
              
              // ---> TAMBAHAN: KONFIRMASI HAPUS <---
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus Evaluasi?'),
                      ]),
                      content: const Text('Apakah kamu yakin ingin menghapus data evaluasi ini? Data yang dihapus tidak dapat dikembalikan.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context); // Tutup dialog konfirmasi
                            if (eval.id != null) {
                              await DatabaseHelper.instance.deleteEvaluasi(eval.id!);
                              _refreshData(); 
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Data berhasil dihapus! 🗑️"), backgroundColor: Colors.redAccent)
                                );
                              }
                            }
                          },
                          child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }, 
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), 
                label: const Text("Hapus", style: TextStyle(color: Colors.red)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _macroItem(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text("${value.toInt()} $unit", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}
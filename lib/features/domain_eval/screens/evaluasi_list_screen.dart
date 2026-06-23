import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui' as ui;
import '../../../core/database/db_helper.dart';
import '../../../core/utils/shared_prefs_helper.dart';
import '../models/evaluasi_model.dart';
import '../models/jurnal_model.dart';
import 'form_evaluasi_screen.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

class EvaluasiListScreen extends StatefulWidget {
  const EvaluasiListScreen({super.key});

  @override
  State<EvaluasiListScreen> createState() => _EvaluasiListScreenState();
}

class _EvaluasiListScreenState extends State<EvaluasiListScreen> {
  late Future<List<EvaluasiModel>> _evaluasiList;
  bool _showInsights = true;

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
        title: const Text('History Nutrisi',
            style: TextStyle(fontWeight: FontWeight.bold)),
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

          final allData = snapshot.data!;
          final filteredData = allData.where((eval) {
            bool matchStatus = _selectedStatusFilter == 'Semua' ||
                eval.status == _selectedStatusFilter;
            bool matchStrict = !_filterStrictOnly || eval.isStrict == true;
            return matchStatus && matchStrict;
          }).toList();

          return Column(
            children: [
              // ==========================================
              // UI FITUR FILTER HISTORY
              // ==========================================
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Container(height: 25, width: 1, color: Colors.grey[300]),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('🔥 Strict',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
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
                          side: BorderSide(
                              color: _filterStrictOnly
                                  ? Colors.redAccent
                                  : Colors.grey[300]!)),
                      labelStyle: TextStyle(
                          color: _filterStrictOnly
                              ? Colors.redAccent
                              : Colors.grey[600]),
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
                        const Icon(Icons.search_off,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text("Tidak ada data dengan filter ini",
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else ...[
                // ==========================================
                // CUSTOM WIDGET: LASSO INSIGHT EXPLORER
                // ==========================================
                if (_showInsights)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: LassoInsightExplorer(data: filteredData),
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

  Widget _buildStatusChip(String label, MaterialColor color) {
    bool isSelected = _selectedStatusFilter == label;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color[700])),
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
          side: BorderSide(color: isSelected ? color : color[200]!)),
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
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
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

    Color statusColor = eval.status == "TERCAPAI"
        ? Colors.green
        : eval.status == "SURPLUS"
            ? Colors.orange
            : Colors.blue;

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
        title: Text(formattedDate,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                if (eval.langkahKaki > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk_rounded,
                            size: 12, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          "${NumberFormat.decimalPattern('id').format(eval.langkahKaki)} langkah",
                          style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
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
                  color: eval.status == 'TERCAPAI'
                      ? Colors.amber[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: eval.status == 'TERCAPAI'
                          ? Colors.amber.withOpacity(0.5)
                          : Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        eval.status == 'TERCAPAI'
                            ? Icons.star_rounded
                            : Icons.local_fire_department,
                        size: 10,
                        color: eval.status == 'TERCAPAI'
                            ? Colors.amber[800]
                            : Colors.redAccent),
                    const SizedBox(width: 2),
                    Text("STRICT",
                        style: TextStyle(
                            fontSize: 8,
                            color: eval.status == 'TERCAPAI'
                                ? Colors.amber[800]
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold)),
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
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
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
                teksSelisih =
                    "Kelebihan (Surplus): +${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                warnaTeks = Colors.orange[800]!;
              } else if (eval.status == "DEFISIT") {
                teksSelisih =
                    "Kekurangan (Defisit): -${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                warnaTeks = Colors.blue[800]!;
              } else {
                if (eval.kaloriAktual > eval.targetKalori) {
                  teksSelisih =
                      "Lebih Sedikit (Aman): +${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                } else if (eval.kaloriAktual < eval.targetKalori) {
                  teksSelisih =
                      "Kurang Sedikit (Aman): -${NumberFormat.decimalPattern('id').format(eval.surplusDefisit)} kkal";
                } else {
                  teksSelisih = "Pas Target! 🎉 (0 kkal)";
                }
              }

              return Text(teksSelisih,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: warnaTeks,
                      fontSize: 14));
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
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 5),
                          Text(
                              "Root Cause: ${jurnal.rootCause.replaceAll('_', ' ')}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.orange[800])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('"${jurnal.catatan}"',
                          style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87)),
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
                      builder: (context) =>
                          FormEvaluasiScreen(evaluasiToEdit: eval),
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
                      content: const Text(
                          'Apakah kamu yakin ingin menghapus data evaluasi ini? Data yang dihapus tidak dapat dikembalikan.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal',
                              style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            if (eval.id != null) {
                              await DatabaseHelper.instance
                                  .deleteEvaluasi(eval.id!);
                              _refreshData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Data berhasil dihapus! 🗑️"),
                                        backgroundColor: Colors.redAccent));
                              }
                            }
                          },
                          child: const Text('Ya, Hapus',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
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
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}

// ============================================================================
// CUSTOM WIDGET: LASSO INSIGHT EXPLORER (SCATTER PLOT DENGAN RAY-CASTING)
// ============================================================================
class LassoInsightExplorer extends StatefulWidget {
  final List<EvaluasiModel> data;

  const LassoInsightExplorer({super.key, required this.data});

  @override
  State<LassoInsightExplorer> createState() => _LassoInsightExplorerState();
}

class _LassoInsightExplorerState extends State<LassoInsightExplorer> {
  Path _lassoPath = Path();
  bool _isDrawing = false;

  List<int> _selectedIndices = [];
  String _dominantRootCause = "";
  int _dominantCount = 0;
  bool _isAnalyzing = false;
  bool _isSharing = false; 

  List<Offset> _pointCoordinates = [];
  int _dayLimit = 7;

  final ScreenshotController _screenshotController = ScreenshotController();

  void _analyzeLassoSelection(List<EvaluasiModel> currentChartData) async {
    if (_selectedIndices.isEmpty) {
      setState(() {
        _dominantRootCause = "";
        _dominantCount = 0;
      });
      return;
    }

    setState(() { _isAnalyzing = true; });

    Map<String, int> causeCounts = {};
    int successCount = 0; 

    for (int idx in _selectedIndices) {
      final eval = currentChartData[idx];
      
      if (eval.status == 'TERCAPAI') {
        successCount++;
      }

      final jurnal = await DatabaseHelper.instance.getJurnalByEvaluasiId(eval.id!);
      if (jurnal != null && jurnal.rootCause.isNotEmpty) {
        String cause = jurnal.rootCause.replaceAll('_', ' ');
        causeCounts[cause] = (causeCounts[cause] ?? 0) + 1;
      }
    }

    if (causeCounts.isNotEmpty && mounted) {
      var dominant = causeCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      setState(() {
        _dominantRootCause = dominant.key;
        _dominantCount = dominant.value;
        _isAnalyzing = false;
      });
    } else if (successCount > 0 && mounted) {
      setState(() {
        _dominantRootCause = "Pola Sehat Konsisten";
        _dominantCount = successCount;
        _isAnalyzing = false;
      });
    } else {
      if (mounted) {
        setState(() {
          _dominantRootCause = "Tidak ada jurnal/catatan";
          _dominantCount = 0;
          _isAnalyzing = false;
        });
      }
    }
  }

  // 📸 METODE PENDUKUNG: MENDAPATKAN PERSONALITY DAN EMOTICON
  Map<String, String> _getPersonalityDetails(String cause) {
    String lower = cause.toLowerCase();
    
    // -- KATEGORI SUKSES --
    if (lower.contains('sehat') || lower.contains('konsisten')) {
      return {'title': 'DISCIPLINE LEGEND', 'emoji': '🏆', 'desc': 'Calorie Master! Target nutrisi tercapai sempurna.'};
    } 
    // -- KATEGORI SURPLUS --
    else if (lower.contains('unmindful') || lower.contains('snacking')) {
      return {'title': 'SNACK PREDATOR', 'emoji': '🍟', 'desc': 'Ngemil tanpa sadar bikin kalori numpuk perlahan tapi pasti.'};
    } else if (lower.contains('emotional')) {
      return {'title': 'EMOTIONAL EATER', 'emoji': '🎭', 'desc': 'Pelarian stres ke makanan bikin target harianmu jebol.'};
    } else if (lower.contains('social')) {
      return {'title': 'SOCIAL BUTTERFLY', 'emoji': '🥂', 'desc': 'Terpengaruh lingkungan atau acara, asupan kalori jadi tak terkendali.'};
    } else if (lower.contains('binge')) {
      return {'title': 'REVENGE EATER', 'emoji': '👹', 'desc': 'Makan balas dendam karena kelaparan di waktu sebelumnya.'};
    } else if (lower.contains('sugar') || lower.contains('carb')) {
      return {'title': 'SUGAR HUNTER', 'emoji': '🧋', 'desc': 'Kecanduan gula atau karbohidrat spesifik mendominasi asupanmu.'};
    } 
    // -- KATEGORI DEFISIT --
    else if (lower.contains('task overload')) {
      return {'title': 'HUSTLE ZOMBIE', 'emoji': '💻', 'desc': 'Terlalu sibuk urus tugas/kerjaan sampai menunda makan.'};
    } else if (lower.contains('time mismanagement')) {
      return {'title': 'THE PROCRASTINATOR', 'emoji': '⏳', 'desc': 'Manajemen waktu makan yang buruk bikin kalori harianmu defisit.'};
    } else if (lower.contains('physical fatigue')) {
      return {'title': 'LOW BATTERY', 'emoji': '🔋', 'desc': 'Kondisi fisik menurun atau sakit bikin asupan nutrisi kurang.'};
    } else if (lower.contains('deliberate fasting')) {
      return {'title': 'THE MONK', 'emoji': '🧘‍♀️', 'desc': 'Sengaja tidak makan (puasa), pastikan nutrisi berbukamu cukup!'};
    } else if (lower.contains('appetite loss')) {
      return {'title': 'THE APPETITELESS', 'emoji': '🥀', 'desc': 'Kehilangan nafsu makan mendadak. Jangan biarkan badanmu drop!'};
    }
    
    return {'title': 'DIET VILLAIN', 'emoji': '⚠️', 'desc': 'Tantangan nutrisi terdeteksi pada hari yang dilingkari.'};
  }

  // 📸 BLOK UI PREMIUM WRAPPED (VERSI FINAL: HANYA TIMELINE TITIK EMOJI)
  Widget _buildShareInfographic(List<EvaluasiModel> currentChartData) {
    bool isSuccess = _dominantRootCause == "Pola Sehat Konsisten";
    var personality = _getPersonalityDetails(_dominantRootCause);
    
    int totalSelected = _selectedIndices.length;
    int percentage = totalSelected > 0 ? ((_dominantCount / totalSelected) * 100).round() : 0;

    List<Color> gradientColors = isSuccess 
        ? [const Color(0xFF064E3B), const Color(0xFF0F766E)] 
        : [const Color(0xFF450A0A), const Color(0xFF7F1D1D)]; 

    Color accentColor = isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety_outlined, color: accentColor, size: 22),
                  const SizedBox(width: 8),
                  const Text("FITPLATE WRAPPED", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                child: const Text("LASSO REPORT", style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 30),
          
          Text("Diet Profile: ${SharedPrefsHelper.loggedInUserName}", style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text("Hasil Analisis Pola Spasial", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 25),

          // ==========================================
          // VISUALISASI TIMELINE TITIK BERJEJER
          // ==========================================
          const Text("TIMELINE DATA TERPILIH", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _selectedIndices.map((idx) {
                final eval = currentChartData[idx];
                String emojiDot = eval.status == 'TERCAPAI' ? '🟢' : (eval.status == 'SURPLUS' ? '🟠' : '🔵');
                return Text(emojiDot, style: const TextStyle(fontSize: 18));
              }).toList(),
            ),
          ),
          const SizedBox(height: 25),

          // Kartu Personality Premium
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            child: Column(
              children: [
                Text(personality['emoji']!, style: const TextStyle(fontSize: 45)),
                const SizedBox(height: 12),
                Text(personality['title']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(_dominantRootCause, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text("$percentage%", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const Text("Intensitas Sesi", style: TextStyle(fontSize: 10, color: Colors.white60)),
                      ],
                    ),
                    Column(
                      children: [
                        Text("$totalSelected Hari", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const Text("Rentang Lasso", style: TextStyle(fontSize: 10, color: Colors.white60)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              personality['desc']!,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 35),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 15),
          
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Generated via FitPlate Analytics", style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
              Icon(Icons.verified_user_sharp, color: Colors.white24, size: 14),
            ],
          )
        ],
      ),
    );
  }

  // 🚀 FUNGSI MERAKIT & MEMBAGIKAN GAMBAR
  Future<void> _shareInsight(List<EvaluasiModel> currentChartData) async {
    setState(() { _isSharing = true; });
    try {
      Uint8List capturedImage = await _screenshotController.captureFromWidget(
        _buildShareInfographic(currentChartData),
        delay: const Duration(milliseconds: 250),
        context: context,
      );

      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/fitplate_insight.png').create();
      await imagePath.writeAsBytes(capturedImage);

      String shareText = _dominantRootCause == "Pola Sehat Konsisten" 
          ? 'Gokil, konsistensi dietku minggu ini tembus target! 🏆 Cek raport FitPlate-ku!'
          : 'Gawat, dietku minggu ini terhambat pola buruk. 🚀 Cek analisaku!';

      await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
    } catch (e) {
      debugPrint("Gagal membagikan: $e");
    }
    setState(() { _isSharing = false; });
  }

  @override
  Widget build(BuildContext context) {
    List<EvaluasiModel> chartData;
    if (_dayLimit > 0) {
      chartData = widget.data.take(_dayLimit).toList().reversed.toList();
    } else {
      chartData = widget.data.reversed.toList();
    }

    bool isSuccess = _dominantRootCause == "Pola Sehat Konsisten";
    Color mainUiColor = isSuccess ? Colors.green[700]! : Colors.red;
    Color mainUiBg = isSuccess ? Colors.green[50]! : Colors.red[50]!;
    String mainEmoji = isSuccess ? "🏆" : "🔥";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.gesture, color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Lasso Insight Explorer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                    Text("Lingkari titik trend untuk membedah akar masalah", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              PopupMenuButton<int>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.withOpacity(0.3))
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayLimit == 0 ? "Semua" : "$_dayLimit Hari", style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 14, color: Colors.indigo)
                    ],
                  ),
                ),
                onSelected: (int value) {
                  setState(() {
                    _dayLimit = value;
                    _selectedIndices.clear(); 
                    _dominantRootCause = "";
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 7, child: Text('7 Hari Terakhir', style: TextStyle(fontSize: 12))),
                  const PopupMenuItem(value: 14, child: Text('14 Hari Terakhir', style: TextStyle(fontSize: 12))),
                  const PopupMenuItem(value: 30, child: Text('30 Hari Terakhir', style: TextStyle(fontSize: 12))),
                  const PopupMenuItem(value: 0, child: Text('Semua Data', style: TextStyle(fontSize: 12))),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),

          LayoutBuilder(builder: (context, constraints) {
            return GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isDrawing = true;
                  _lassoPath = Path()..moveTo(details.localPosition.dx, details.localPosition.dy);
                  _selectedIndices.clear();
                  _dominantRootCause = "";
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _lassoPath.lineTo(details.localPosition.dx, details.localPosition.dy);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isDrawing = false;
                  _lassoPath.close();

                  for (int i = 0; i < _pointCoordinates.length; i++) {
                    if (_lassoPath.contains(_pointCoordinates[i])) {
                      _selectedIndices.add(i);
                    }
                  }
                });
                _analyzeLassoSelection(chartData); 
              },
              child: Container(
                height: 150, 
                width: double.infinity,
                color: Colors.transparent, 
                child: CustomPaint(
                  painter: ScatterPlotPainter(
                      data: chartData, 
                      lassoPath: _lassoPath,
                      isDrawing: _isDrawing,
                      selectedIndices: _selectedIndices,
                      onCoordinatesCalculated: (coords) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _pointCoordinates.length != coords.length) {
                            _pointCoordinates = coords;
                          }
                        });
                      }),
                ),
              ),
            );
          }),

          if (_selectedIndices.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            if (_isAnalyzing)
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: mainUiBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text(mainEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${_selectedIndices.length} titik dipilih", style: TextStyle(fontWeight: FontWeight.bold, color: mainUiColor.withOpacity(0.8), fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            _dominantCount > 0 ? "$_dominantRootCause ($_dominantCount Kejadian)" : "Tidak ada data jurnal",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: mainUiColor),
                          ),
                        ],
                      ),
                    ),
                    if (_dominantCount > 0)
                      IconButton(
                        icon: _isSharing 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: mainUiColor, strokeWidth: 2))
                          : Icon(Icons.ios_share_rounded, color: mainUiColor),
                        onPressed: () => _shareInsight(chartData),
                        tooltip: "Bagikan Insight",
                      )
                  ],
                ),
              ),
          ]
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: MENGGAMBAR TITIK DATA & TALI LASSO ELEGAN
// ============================================================================
class ScatterPlotPainter extends CustomPainter {
  final List<EvaluasiModel> data;
  final Path lassoPath;
  final bool isDrawing;
  final List<int> selectedIndices;
  final Function(List<Offset>) onCoordinatesCalculated;

  ScatterPlotPainter({
    required this.data,
    required this.lassoPath,
    required this.isDrawing,
    required this.selectedIndices,
    required this.onCoordinatesCalculated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ruang ekstra di bawah untuk label tanggal tiap titik
    final double midY = (size.height - 20) / 2;
    final double paddingX = 20.0;

    // Gambar garis ekuator (Target 0%)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);

    List<Offset> coords = [];
    double stepX =
        data.length > 1 ? (size.width - (paddingX * 2)) / (data.length - 1) : 0;

    double maxDeviasi = 0.1;
    for (var eval in data) {
      if (eval.targetKalori > 0) {
        double deviasi =
            ((eval.kaloriAktual - eval.targetKalori) / eval.targetKalori).abs();
        if (deviasi > maxDeviasi) maxDeviasi = deviasi;
      }
    }

    // Gambar titik-titik data dan Label Tanggal
    for (int i = 0; i < data.length; i++) {
      final eval = data[i];
      double deviasi = 0;
      if (eval.targetKalori > 0) {
        deviasi = (eval.kaloriAktual - eval.targetKalori) / eval.targetKalori;
      }

      double posX = paddingX + (i * stepX);
      if (data.length == 1) posX = size.width / 2;

      // Semakin surplus titiknya semakin ke atas
      double posY = midY - (deviasi / maxDeviasi) * (midY - 10);
      Offset pointOffset = Offset(posX, posY);
      coords.add(pointOffset);

      // --- GAMBAR TANGGAL DI BAWAH TIAP TITIK ---
      DateTime date = DateTime.tryParse(eval.tanggal) ?? DateTime.now();
      String dateStr = DateFormat('dd/MM').format(date);

      final textSpan = TextSpan(
          text: dateStr,
          style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 8,
              fontWeight: FontWeight.bold));
      final textPainter =
          TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr)
            ..layout();
      textPainter.paint(
          canvas, Offset(posX - (textPainter.width / 2), size.height - 15));

      // --- WARNA DAN TITIK ---
      Color dotColor = eval.status == 'SURPLUS'
          ? Colors.orange
          : eval.status == 'DEFISIT'
              ? Colors.blue
              : Colors.green;

      bool isSelected = selectedIndices.contains(i);

      if (isSelected) {
        canvas.drawCircle(
            pointOffset,
            10,
            Paint()
              ..color = dotColor.withOpacity(0.3)
              ..style = PaintingStyle.fill);
      }

      canvas.drawCircle(
          pointOffset,
          isSelected ? 6 : 4,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.fill);
    }

    onCoordinatesCalculated(coords);

    // ==========================================
    // GAMBAR TALI LASSO (MINIMALIS & ELEGAN)
    // ==========================================
    if (isDrawing || selectedIndices.isNotEmpty) {
      final bounds = lassoPath.getBounds();

      // Cegah error rendering jika bounding box kosong
      if (bounds.width > 0 && bounds.height > 0) {
        // 1. Force Field Gradient (Isi Poligon Transparan 3D - Warna Senada)
        final fillPaint = Paint()
          ..shader = ui.Gradient.linear(
            bounds.topCenter,
            bounds.bottomCenter,
            [Colors.indigo.withOpacity(0.3), Colors.indigo.withOpacity(0.05)],
          )
          ..style = PaintingStyle.fill;

        // 2. Neon Glow (Pendaran Cahaya Luar - UNGU TERANG/INDIGO ACCENT)
        final glowPaint = Paint()
          ..color = Colors.indigoAccent.withOpacity(0.5)
          ..strokeWidth = 7.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        // 3. Core Line (Tulang Garis Solid - UNGU PEKAT/INDIGO)
        final corePaint = Paint()
          ..color = Colors.indigo
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        canvas.drawPath(lassoPath, fillPaint);
        canvas.drawPath(lassoPath, glowPaint);
        canvas.drawPath(lassoPath, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScatterPlotPainter oldDelegate) => true;
}

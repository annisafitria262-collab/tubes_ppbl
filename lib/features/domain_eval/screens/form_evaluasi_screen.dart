import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/db_helper.dart';
import '../../../../core/utils/shared_prefs_helper.dart';
import '../models/evaluasi_model.dart';
import '../models/jurnal_model.dart';
import '../widgets/smart_deviation_card.dart';
import '../../domain_input/repositories/log_konsumsi_repository.dart'; 

class FormEvaluasiScreen extends StatefulWidget {
  final EvaluasiModel? evaluasiToEdit;
  
  const FormEvaluasiScreen({super.key, this.evaluasiToEdit});

  @override
  State<FormEvaluasiScreen> createState() => _FormEvaluasiScreenState();
}

class _FormEvaluasiScreenState extends State<FormEvaluasiScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _targetKaloriCtrl;
  late TextEditingController _kaloriAktualCtrl;
  final _catatanCtrl = TextEditingController();
  
  late TextEditingController _proteinCtrl;
  late TextEditingController _karboCtrl;
  late TextEditingController _lemakCtrl;
  
  late TextEditingController _langkahCtrl;
  bool _isManualPedometer = false;

  String _statusPilihan = 'TERCAPAI';
  bool _isStrictMode = false;

  int _langkahKakiRealTime = 0;
  StreamSubscription<StepCount>? _stepCountStream;

  final List<String> _faktorSurplus = ['Banyak Ngemil', 'Kumpul Teman/Acara', 'Stres/Emosional', 'Utang Defisit', 'Gorengan/Manis'];
  final List<String> _faktorDefisit = ['Lupa Makan', 'Sibuk Tugas/Kerja', 'Sengaja Puasa', 'Lagi Sakit', 'Kelelahan'];
  String _selectedFaktor = '';

  Future<void> _initPedometer() async {
    if (await Permission.activityRecognition.request().isGranted) {
      _stepCountStream = Pedometer.stepCountStream.listen((StepCount event) async {
        if (mounted && !_isManualPedometer) {
          
          // RESET HARIAN (BASELINE)
          final prefs = await SharedPreferences.getInstance();
          String tanggalHariIni = DateTime.now().toString().split(' ')[0];
          String tanggalTersimpan = prefs.getString('pedometer_date') ?? '';
          int baseline = prefs.getInt('pedometer_baseline') ?? 0;

          // Jika hari berganti (Jam 12 malam lewat), jadikan langkah saat ini sebagai Titik Nol
          if (tanggalTersimpan != tanggalHariIni) {
            baseline = event.steps;
            await prefs.setString('pedometer_date', tanggalHariIni);
            await prefs.setInt('pedometer_baseline', baseline);
          }

          setState(() {
            // Langkah Aktual = Sensor Android - Titik Nol Hari Ini
            int langkahAktual = event.steps - baseline;
            
            // Jaga-jaga kalau angkanya minus (karena HP restart, dll)
            _langkahKakiRealTime = langkahAktual < 0 ? 0 : langkahAktual; 
            _langkahCtrl.text = _langkahKakiRealTime.toString();
            _generateSmartDiagnosis(); 
          });
        }
      }, onError: (error) {
        debugPrint("Sensor Pedometer Error: $error");
      });
    }
  }

  @override
  void initState() {
    super.initState();
    
    if (widget.evaluasiToEdit != null) {
      _targetKaloriCtrl = TextEditingController(text: widget.evaluasiToEdit!.targetKalori.toInt().toString());
      _kaloriAktualCtrl = TextEditingController(text: widget.evaluasiToEdit!.kaloriAktual.toInt().toString());
      _statusPilihan = widget.evaluasiToEdit!.status;
      _isStrictMode = widget.evaluasiToEdit!.isStrict;
      
      _proteinCtrl = TextEditingController(text: widget.evaluasiToEdit!.proteinTotal > 0 ? widget.evaluasiToEdit!.proteinTotal.toInt().toString() : '');
      _karboCtrl = TextEditingController(text: widget.evaluasiToEdit!.karboTotal > 0 ? widget.evaluasiToEdit!.karboTotal.toInt().toString() : '');
      _lemakCtrl = TextEditingController(text: widget.evaluasiToEdit!.lemakTotal > 0 ? widget.evaluasiToEdit!.lemakTotal.toInt().toString() : '');
      
      _langkahKakiRealTime = widget.evaluasiToEdit!.langkahKaki;
      _langkahCtrl = TextEditingController(text: _langkahKakiRealTime.toString());

      _loadCatatanLama();
    } else {
      _targetKaloriCtrl = TextEditingController();
      _kaloriAktualCtrl = TextEditingController();
      _proteinCtrl = TextEditingController();
      _karboCtrl = TextEditingController();
      _lemakCtrl = TextEditingController();
      _langkahCtrl = TextEditingController(text: '0');
      
      _isStrictMode = SharedPrefsHelper.strictEvaluationMode;
      _tarikDataAutoFill(); 
    }

    _initPedometer();

    _targetKaloriCtrl.addListener(_hitungStatusOtomatis);
    _kaloriAktualCtrl.addListener(_hitungStatusOtomatis);

    if (widget.evaluasiToEdit != null) {
      _hitungStatusOtomatis();
    }
  }

  Future<void> _tarikDataAutoFill() async {
    String tanggalHariIni = DateTime.now().toString().split(' ')[0];
    final repoAthaya = LogKonsumsiRepository();

    double targetHarian = SharedPrefsHelper.dailyCalorieTarget;
    double aktualKalori = await repoAthaya.getTotalKaloriHariIni(tanggalHariIni);
    Map<String, double> aktualMacro = await repoAthaya.getTotalMacroHariIni(tanggalHariIni);

    if (mounted) {
      setState(() {
        _targetKaloriCtrl.text = targetHarian.toInt().toString();
        
        if (aktualKalori > 0) _kaloriAktualCtrl.text = aktualKalori.toInt().toString();
        if (aktualMacro['protein']! > 0) _proteinCtrl.text = aktualMacro['protein']!.toInt().toString();
        if (aktualMacro['karbo']! > 0) _karboCtrl.text = aktualMacro['karbo']!.toInt().toString();
        if (aktualMacro['lemak']! > 0) _lemakCtrl.text = aktualMacro['lemak']!.toInt().toString();
      });
      _hitungStatusOtomatis();
    }
  }

  void _hitungStatusOtomatis() { 
    if (_targetKaloriCtrl.text.isNotEmpty && _kaloriAktualCtrl.text.isNotEmpty) {
      double target = double.tryParse(_targetKaloriCtrl.text) ?? 2000;
      double aktual = double.tryParse(_kaloriAktualCtrl.text) ?? 0;
      double batasToleransi = _isStrictMode ? 0.05 : 0.10; 
      double deviasi = (aktual - target) / target;

      setState(() {
        if (deviasi > batasToleransi) {
          _statusPilihan = 'SURPLUS'; 
        } else if (deviasi < -batasToleransi) {
          _statusPilihan = 'DEFISIT'; 
        } else {
          _statusPilihan = 'TERCAPAI'; 
        }
        _generateSmartDiagnosis(); 
      });
    }
  }

  // ==========================================================
  // 🧠 FUNGSI DIAGNOSIS: INTEGRASI TIPE DIET ACA & STRICT MODE ANNISA
  // ==========================================================
  void _generateSmartDiagnosis() {
    if (widget.evaluasiToEdit != null && !_isManualPedometer) return; 

    double karbo = double.tryParse(_karboCtrl.text) ?? 0;
    double lemak = double.tryParse(_lemakCtrl.text) ?? 0;
    double protein = double.tryParse(_proteinCtrl.text) ?? 0;
    
    String diagnosis = "";
    
    // 1. TARIK TIPE DIET DARI ACA!
    String tipeDiet = SharedPrefsHelper.defaultDietType; 

    // 2. REALISASI STRICT MODE (Jika aktif, kita jadi wasit kejam!)
    if (_isStrictMode) {
      if (tipeDiet == 'KETO' && karbo > 50) {
        diagnosis = "🚨 PELANGGARAN KETO: Asupan Karbohidrat ($karbo g) melebihi batas ketosis! Mode ketat mendeteksi kegagalan sistematis.";
      } else if (tipeDiet == 'LOW_CARB' && karbo > 100) {
        diagnosis = "🚨 PELANGGARAN LOW CARB: Karbohidrat ($karbo g) terlalu tinggi untuk program ini.";
      } else if (tipeDiet == 'HIGH_PROTEIN' && protein < 80) {
        diagnosis = "🚨 PELANGGARAN HIGH PROTEIN: Asupan Protein ($protein g) sangat rendah, waspada penyusutan massa otot massal.";
      }
    }

    // 3. JIKA TIDAK ADA PELANGGARAN STRICT MODE, GUNAKAN LOGIKA REGULAR
    if (diagnosis.isEmpty) {
      if (_statusPilihan == 'TERCAPAI') {
        _catatanCtrl.clear();
        _selectedFaktor = '';
        return; // Sempurna, tidak perlu diagnosis
      } else if (_statusPilihan == 'SURPLUS') {
        if (karbo > 150 && _langkahKakiRealTime < 3000) {
          diagnosis = "Indikasi karbohidrat berlebih dengan aktivitas fisik Sedentary (kurang gerak).";
        } else if (lemak > 70) {
          diagnosis = "Indikasi konsumsi lipid/lemak melebihi rasio aman harian.";
        } else if (_langkahKakiRealTime > 8000) {
          diagnosis = "Aktivitas fisik sudah sangat baik, namun kalori tetap surplus (indikasi porsi makan over-limit).";
        } else {
          diagnosis = "Asupan energi melampaui batas toleransi sistem.";
        }
      } else if (_statusPilihan == 'DEFISIT') {
        if (_langkahKakiRealTime > 8000) {
          diagnosis = "Aktivitas tinggi namun asupan energi rendah. Waspada penyusutan otot.";
        } else {
          diagnosis = "Asupan nutrisi di bawah ambang batas harian.";
        }
      }
    }

    String faktorTeks = _selectedFaktor.isNotEmpty ? _selectedFaktor : "";
    _catatanCtrl.text = "Analisis Sistem: $diagnosis\n\nFaktor Tambahan: $faktorTeks";
  }

  void _onFaktorSelected(String faktor) {
    setState(() {
      _selectedFaktor = faktor;
      List<String> parts = _catatanCtrl.text.split('Faktor Tambahan:');
      if (parts.isNotEmpty) {
        _catatanCtrl.text = "${parts[0]}Faktor Tambahan: $faktor";
      }
    });
  }

  void _loadCatatanLama() async {
    if (widget.evaluasiToEdit?.id != null) {
      final jurnal = await DatabaseHelper.instance.getJurnalByEvaluasiId(widget.evaluasiToEdit!.id!);
      if (jurnal != null) {
        setState(() {
          _catatanCtrl.text = jurnal.catatan ?? '';
          
          List<String> semuaFaktor = [..._faktorSurplus, ..._faktorDefisit];
          for (var faktor in semuaFaktor) {
            if (_catatanCtrl.text.contains(faktor)) {
              _selectedFaktor = faktor;
              break;
            }
          }
        });
      }
    }
  }
  
  @override
  void dispose() {
    _stepCountStream?.cancel();
    _targetKaloriCtrl.removeListener(_hitungStatusOtomatis);
    _kaloriAktualCtrl.removeListener(_hitungStatusOtomatis);
    
    _targetKaloriCtrl.dispose();
    _kaloriAktualCtrl.dispose();
    _catatanCtrl.dispose();
    _proteinCtrl.dispose();
    _karboCtrl.dispose();
    _lemakCtrl.dispose();
    _langkahCtrl.dispose();
    
    super.dispose();
  }

  void _simpanData() async {
    if (_formKey.currentState!.validate()) {
      double target = double.parse(_targetKaloriCtrl.text);
      double aktual = double.parse(_kaloriAktualCtrl.text);
      double selisih = (aktual - target).abs();

      double protein = double.tryParse(_proteinCtrl.text) ?? 0;
      double karbo = double.tryParse(_karboCtrl.text) ?? 0;
      double lemak = double.tryParse(_lemakCtrl.text) ?? 0;

      int finalLangkahKaki = _langkahKakiRealTime;

      if (widget.evaluasiToEdit != null) {
        String tanggalHariIni = DateTime.now().toString().split(' ')[0];
        if (widget.evaluasiToEdit!.tanggal != tanggalHariIni) {
          finalLangkahKaki = widget.evaluasiToEdit!.langkahKaki;
        }
      }

      final dataEvaluasi = EvaluasiModel(
        id: widget.evaluasiToEdit?.id, 
        tanggal: widget.evaluasiToEdit?.tanggal ?? DateTime.now().toString().split(' ')[0], 
        targetKalori: target,
        kaloriAktual: aktual,
        surplusDefisit: selisih,
        status: _statusPilihan,
        proteinTotal: protein,
        karboTotal: karbo,
        lemakTotal: lemak,
        isStrict: _isStrictMode,
        langkahKaki: finalLangkahKaki,
      );

      int evaluasiId;
      
      if (widget.evaluasiToEdit == null) {
        evaluasiId = await DatabaseHelper.instance.insertEvaluasi(dataEvaluasi);
      } else {
        await DatabaseHelper.instance.updateEvaluasi(dataEvaluasi);
        evaluasiId = widget.evaluasiToEdit!.id!;
      }

      if (_statusPilihan == 'SURPLUS' || _statusPilihan == 'DEFISIT') {
        final dataJurnal = JurnalModel(
          evaluasiId: evaluasiId, 
          rootCause: _selectedFaktor.isNotEmpty ? _selectedFaktor.replaceAll(' ', '_').toUpperCase() : _statusPilihan, 
          catatan: _catatanCtrl.text, 
          moodScore: 3,
          dibuatPada: DateTime.now().millisecondsSinceEpoch,
        );
        await DatabaseHelper.instance.insertJurnal(dataJurnal);
      } else {
        await DatabaseHelper.instance.deleteJurnalByEvaluasiId(evaluasiId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.evaluasiToEdit == null ? "Berhasil menyimpan laporan! 📊" : "Berhasil memperbarui data! 🔄"),
            backgroundColor: const Color(0xFF2E7D32),
          )
        );
        Navigator.pop(context, true); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.evaluasiToEdit == null ? 'Jurnal & Root Cause' : 'Edit Jurnal', 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // ---> KUNCI PERBAIKAN: Menambahkan jarak ekstra di bagian bawah biar tombol tidak tertutup <---
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 80, 
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Metrik Harian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)]),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.teal.withOpacity(0.4)),
                          boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                              child: const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Live Pedometer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text("Sensor aktif...", style: TextStyle(fontSize: 11, color: Colors.teal[800])),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 80, 
                              child: TextFormField(
                                controller: _langkahCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.teal[900]),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _isManualPedometer = true; 
                                    _langkahKakiRealTime = int.tryParse(value) ?? 0;
                                    _generateSmartDiagnosis(); 
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextFormField(
                        controller: _targetKaloriCtrl,
                        readOnly: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Target Kalori (kkal)',
                          prefixIcon: const Icon(Icons.flag, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _kaloriAktualCtrl,
                        readOnly: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Kalori Aktual (kkal)',
                          prefixIcon: const Icon(Icons.restaurant, color: Colors.orange),
                          filled: true, 
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 10),
                      const Text("Makronutrisi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 15),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _proteinCtrl,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Pro (g)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                filled: true, 
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _karboCtrl,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Karbo (g)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _lemakCtrl,
                              readOnly: true,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Lemak (g)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Analisis Deviasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 15),
                      
                      SmartDeviationCard(
                        targetKalori: double.tryParse(_targetKaloriCtrl.text) ?? 2000,
                        kaloriAktual: double.tryParse(_kaloriAktualCtrl.text) ?? 0,
                        isStrictMode: _isStrictMode,
                        status: _statusPilihan,
                      ),
                      
                      const SizedBox(height: 15),
                      
                      if (_statusPilihan == 'SURPLUS' || _statusPilihan == 'DEFISIT') ...[
                        const Text("Faktor Pemicu Keseharian:", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        
                        Builder(
                          builder: (context) {
                            List<String> currentFaktorList = _statusPilihan == 'SURPLUS' ? _faktorSurplus : _faktorDefisit;
                            
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentFaktorList.map((faktor) {
                                bool isSelected = _selectedFaktor == faktor;
                                return ChoiceChip(
                                  label: Text(faktor, style: TextStyle(color: isSelected ? Colors.white : Colors.teal[800], fontSize: 12)),
                                  selected: isSelected,
                                  selectedColor: Colors.teal,
                                  backgroundColor: Colors.teal[50],
                                  onSelected: (bool selected) {
                                    _onFaktorSelected(selected ? faktor : '');
                                  },
                                );
                              }).toList(),
                            );
                          }
                        ),
                        
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Detail Root Cause',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (value) => value!.isEmpty ? 'Tolong tuliskan alasannya!' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _simpanData,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(widget.evaluasiToEdit == null ? 'Simpan Laporan' : 'Update Jurnal', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
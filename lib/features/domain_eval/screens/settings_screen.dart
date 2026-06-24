import 'package:flutter/material.dart';
import '../../../../core/utils/shared_prefs_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isStrict = false;
  bool _enableInsights = true; // Variabel baru pengganti PDF

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load data dari SharedPreferences
  void _loadSettings() {
    setState(() {
      _isStrict = SharedPrefsHelper.strictEvaluationMode;
      _enableInsights = SharedPrefsHelper.enableSmartInsights; // Panggil Insight
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Evaluasi', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ==========================================
          // KODE ASLI ANNISA (TIDAK ADA YANG DIUBAH LAGI)
          // ==========================================
          const Text("Preferensi Evaluasi", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),
          
          // CARD 1: STRICT MODE
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              title: const Text("Mode Evaluasi Ketat", 
                style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Toleransi kalori akan diperketat hingga 5%"),
              secondary: Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
              value: _isStrict,
              onChanged: (value) async {
                await SharedPrefsHelper.setStrictEvaluationMode(value);
                setState(() => _isStrict = value);
              },
            ),
          ),
          
          const SizedBox(height: 25),
          const Text("Asisten & Analitik", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),

          // CARD 2: SMART INSIGHTS (PENGGANTI EXPORT PDF)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: SwitchListTile(
              title: const Text("Smart Insight Cards", 
                style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Tampilkan analisis Root Cause otomatis"),
              secondary: const Icon(Icons.lightbulb_outline, color: Colors.amber),
              value: _enableInsights,
              onChanged: (value) async {
                await SharedPrefsHelper.setEnableSmartInsights(value);
                setState(() => _enableInsights = value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
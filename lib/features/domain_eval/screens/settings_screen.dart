import 'package:flutter/material.dart';
import '../../../../core/utils/shared_prefs_helper.dart';
import 'login_screen.dart'; // ---> TAMBAHAN: Untuk navigasi saat Logout

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isStrict = false;
  bool _enableInsights = true; // Variabel baru pengganti PDF
  String _userName = "User";   // ---> TAMBAHAN: Penampung nama user

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
      _userName = SharedPrefsHelper.loggedInUserName;          // ---> TAMBAHAN: Panggil Nama User
    });
  }

  // ---> TAMBAHAN: FUNGSI LOGOUT <---
  void _logout() async {
    await SharedPrefsHelper.setLoggedIn(false);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
          // ---> TAMBAHAN: KARTU PROFIL & LOGOUT <---
          // ==========================================
          const Text("Akun Saya", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                  child: const Icon(Icons.person, color: Color(0xFF2E7D32), size: 30),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Halo,", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Dialog konfirmasi sebelum logout
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Keluar"),
                        content: const Text("Yakin ingin keluar dari akun ini?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Batal", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Tutup dialog
                              _logout();              // Panggil fungsi logout
                            },
                            child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                )
              ],
            ),
          ),
          const SizedBox(height: 25),

          // ==========================================
          // KODE ASLI ANNISA DI BAWAH SINI (TIDAK ADA YANG DIUBAH)
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
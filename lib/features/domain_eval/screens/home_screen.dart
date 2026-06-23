import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../../core/utils/shared_prefs_helper.dart';
import '../../../core/database/db_helper.dart';
import '../../domain_eval/models/evaluasi_model.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State API Premium (TheMealDB)
  String _mealName = "Mencari inspirasi...";
  String _mealCategory = "";
  String _mealThumb = ""; 
  bool _isLoadingMeal = true;

  // State Dinamis dari Database
  int _streakDays = 0;
  bool _isSurplusYesterday = false;
  bool _hasInsightData = false; 
  String _lastInsightCause = "";
  int _insightCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadDynamicDatabaseData();
  }

  // ==========================================
  // LOGIKA TARIK DATA DATABASE (LASSO & STREAK)
  // ==========================================
  Future<void> _loadDynamicDatabaseData() async {
    try {
      List<EvaluasiModel> evals = await DatabaseHelper.instance.getAllEvaluasi(); 
      
      if (evals.isEmpty) return;

      // 1. KUNCI UTAMA: Karena index 0 adalah yang paling baru (Hari Ini)
      final latestEval = evals.first; 
      bool isSurplus = latestEval.status == 'SURPLUS';

      // 2. Hitung Streak (Maju dari index 0 ke depan selama statusnya TERCAPAI)
      int streak = 0;
      for (int i = 0; i < evals.length; i++) {
        if (evals[i].status == 'TERCAPAI') {
          streak++;
        } else {
          break; // Streak terput as jika ketemu yang tidak tercapai
        }
      }

      // 3. Analisis Insight (Ambil 7 hari teratas karena itu yang paling baru)
      int scanLimit = evals.length < 7 ? evals.length : 7;
      Map<String, int> causeCounts = {};
      Map<String, int> recencyIndex = {}; // Pelacak hari paling baru
      
      for (int i = 0; i < scanLimit; i++) {
        final eval = evals[i];
        if (eval.status != 'TERCAPAI') { 
          final jurnal = await DatabaseHelper.instance.getJurnalByEvaluasiId(eval.id!);
          if (jurnal != null && jurnal.rootCause.isNotEmpty) {
            String cause = jurnal.rootCause.replaceAll('_', ' ');
            causeCounts[cause] = (causeCounts[cause] ?? 0) + 1;
            
            // Karena index 0 adalah yang paling baru, kita simpan index terkecil
            // sebagai tanda bahwa dialah yang paling dekat dengan hari ini
            if (!recencyIndex.containsKey(cause)) {
              recencyIndex[cause] = i; 
            }
          }
        }
      }

      if (mounted) {
        if (causeCounts.isNotEmpty) {
          String dominantCause = "";
          int maxCount = -1;
          int minIndex = 999999; // Semakin kecil index, semakin baru datanya (dekat ke hari ini)

          causeCounts.forEach((cause, count) {
            if (count > maxCount) {
              maxCount = count;
              dominantCause = cause;
              minIndex = recencyIndex[cause]!;
            } else if (count == maxCount) {
              // KALAU SERI: Menangkan data yang index-nya LEBIH KECIL (artinya lebih baru/dekat ke hari ini)
              if (recencyIndex[cause]! < minIndex) {
                dominantCause = cause;
                minIndex = recencyIndex[cause]!;
              }
            }
          });

          setState(() {
            _hasInsightData = true;
            _lastInsightCause = dominantCause;
            _insightCount = maxCount;
            _streakDays = streak;
            _isSurplusYesterday = isSurplus;
          });
        } else {
          setState(() {
            _hasInsightData = false;
            _streakDays = streak;
            _isSurplusYesterday = isSurplus;
          });
        }
      }
    } catch (e) {
      debugPrint("Error load DB Home: $e");
    }
  }

  // ==========================================
  // LOGIKA WAKTU DINAMIS & QUOTE
  // ==========================================
  Map<String, String> _getDynamicGreeting() {
    int hour = DateTime.now().hour;
    if (hour >= 3 && hour < 11) {
      return {'text': 'Selamat Pagi,', 'icon': '☀️', 'sub': 'Awali hari dengan sarapan bergizi.'};
    } else if (hour >= 11 && hour < 15) {
      return {'text': 'Selamat Siang,', 'icon': '🌤️', 'sub': 'Jaga porsi dan tetap terhidrasi.'};
    } else if (hour >= 15 && hour < 18) {
      return {'text': 'Selamat Sore,', 'icon': '🌥️', 'sub': 'Waktunya camilan sehat.'};
    } else {
      return {'text': 'Selamat Malam,', 'icon': '🌙', 'sub': 'Istirahat cukup untuk esok hari.'};
    }
  }

  String _getCurrentPeriod() {
    int hour = DateTime.now().hour;
    if (hour >= 3 && hour < 11) return "PAGI";
    if (hour >= 11 && hour < 17) return "SIANG";
    return "MALAM";
  }

  // FUNGSI INI SEKARANG DIPAKAI! (Biar gak kuning)
  String _getMealTitle() {
    String period = _getCurrentPeriod();
    if (period == "PAGI") return "Inspirasi Sarapan";
    if (period == "SIANG") return "Inspirasi Makan Siang";
    return "Inspirasi Makan Malam";
  }

  Future<void> _loadDashboardData() async {
    String today = DateTime.now().toString().split(' ')[0];
    String periodKey = "$today-${_getCurrentPeriod()}";

    String lastSavedKey = SharedPrefsHelper.lastApiDate;
    
    if (lastSavedKey == periodKey && SharedPrefsHelper.cachedMealName.isNotEmpty) { 
      setState(() {
        _mealName = SharedPrefsHelper.cachedMealName;
        _mealCategory = SharedPrefsHelper.cachedMealCategory;
        _mealThumb = SharedPrefsHelper.cachedMealThumb; 
        _isLoadingMeal = false;
      });
    } else {
      await _fetchRandomMeal(periodKey);
    }
  }

  Future<void> _fetchRandomMeal(String periodKey) async {
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meal = data['meals'][0];
        
        await SharedPrefsHelper.setLastApiDate(periodKey);
        await SharedPrefsHelper.setCachedMealName(meal['strMeal']);
        await SharedPrefsHelper.setCachedMealCategory(meal['strCategory']);
        await SharedPrefsHelper.setCachedMealThumb(meal['strMealThumb']);

        if (mounted) {
          setState(() {
            _mealName = meal['strMeal'];
            _mealCategory = meal['strCategory'];
            _mealThumb = meal['strMealThumb']; 
            _isLoadingMeal = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mealName = "Oatmeal Cokelat Pisang";
          _mealCategory = "Menu Darurat";
          _mealThumb = ""; 
          _isLoadingMeal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String userName = SharedPrefsHelper.loggedInUserName;
    var greeting = _getDynamicGreeting();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. HERO HEADER (HIJAU GRADIENT)
            // ==========================================
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${greeting['icon']} ${greeting['text']}", style: TextStyle(fontSize: 14, color: Colors.green[100])),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                      ),
                    ],
                  ),
                  Text(userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 15),
                  
                  // Badge Personalisasi Dinamis
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_isSurplusYesterday ? "⚠️" : "🔥", style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          _isSurplusYesterday 
                            ? "Kemarin surplus kalori!" 
                            : (_streakDays > 0 ? "$_streakDays hari konsisten diet" : "Yuk mulai target dietmu hari ini!"),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 25), 

            // ==========================================
            // 2. INSIGHT CARD (INDIGO/BIRU DINAMIS)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF283593), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF283593).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.insights, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text("Lasso Insight Mingguan", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    if (_hasInsightData) ...[
                      const Text("Penyebab utama anomali diet:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 5),
                      Text("🎯 $_lastInsightCause", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text("Terdeteksi pada $_insightCount kejadian.", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ] else ...[
                      const Text("Belum ada insight", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text("Catat jurnal dan lingkari titik pada halaman evaluasi untuk menemukan pola dietmu.", style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => widget.onNavigate(3), 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF283593),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text("Analisis Detail", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ==========================================
            // 3. MEAL CARD (ORANGE WARM)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DI SINI FUNGSI _getMealTitle() DIPANGGIL BIAR GAK KUNING!
                  Text(_getMealTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: _isLoadingMeal
                            ? Container(height: 140, width: double.infinity, color: Colors.orange[100], child: const Center(child: CircularProgressIndicator(color: Colors.orange)))
                            : _mealThumb.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _mealThumb,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(height: 140, width: double.infinity, color: Colors.orange[100]),
                                    errorWidget: (context, url, error) => Container(height: 140, width: double.infinity, color: Colors.orange[100], child: const Icon(Icons.restaurant, color: Colors.orange)),
                                  )
                                : Container(height: 140, width: double.infinity, color: Colors.orange[100], child: const Icon(Icons.restaurant, color: Colors.orange, size: 40)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                                child: Text(_mealCategory.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                              const SizedBox(height: 8),
                              Text(_mealName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // ==========================================
            // 4. ACTION CARDS (PUTIH BERSIH)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Akses Cepat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard(context, "Jurnal Nutrisi", "Catat asupan", Icons.restaurant_menu, Colors.teal, () => widget.onNavigate(1))),
                      const SizedBox(width: 15),
                      Expanded(child: _buildActionCard(context, "Meal Plan", "Jadwal diet", Icons.calendar_month, Colors.blue, () => widget.onNavigate(2))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard(context, "Evaluasi Diet", "Lasso Analytics", Icons.analytics, Colors.indigo, () => widget.onNavigate(3))),
                      const SizedBox(width: 15),
                      Expanded(child: _buildActionCard(context, "Pengaturan", "Sistem diet", Icons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())))),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
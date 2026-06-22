import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../../core/utils/shared_prefs_helper.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State untuk API Premium
  String _mealName = "Mencari inspirasi...";
  String _mealCategory = "";
  String _mealThumb = ""; 
  bool _isLoadingMeal = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // LOGIKA WAKTU DINAMIS
  String _getCurrentPeriod() {
    int hour = DateTime.now().hour;
    if (hour >= 3 && hour < 11) return "PAGI";
    if (hour >= 11 && hour < 17) return "SIANG";
    return "MALAM";
  }

  String _getMealTitle() {
    String period = _getCurrentPeriod();
    if (period == "PAGI") return "Inspirasi Sarapan";
    if (period == "SIANG") return "Inspirasi Makan Siang";
    return "Inspirasi Makan Malam";
  }

  Future<void> _loadDashboardData() async {
    String today = DateTime.now().toString().split(' ')[0];
    String currentPeriod = _getCurrentPeriod();
    String periodKey = "$today-$currentPeriod"; // Contoh: 2026-06-22-SIANG

    // CEK INGATAN API & FOTO (Anti Amnesia, tapi peka waktu!)
    String lastSavedKey = SharedPrefsHelper.lastApiDate;
    
    if (lastSavedKey == periodKey && 
        SharedPrefsHelper.cachedMealName.isNotEmpty &&
        SharedPrefsHelper.cachedMealThumb.isNotEmpty) { 
      setState(() {
        _mealName = SharedPrefsHelper.cachedMealName;
        _mealCategory = SharedPrefsHelper.cachedMealCategory;
        _mealThumb = SharedPrefsHelper.cachedMealThumb; 
        _isLoadingMeal = false;
      });
    } else {
      await _fetchRandomMeal(periodKey); // Tarik API baru untuk sesi ini
    }
  }

  // Fungsi API dengan Penyimpanan Gambar & Sesi Waktu
  Future<void> _fetchRandomMeal(String periodKey) async {
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meal = data['meals'][0];
        
        await SharedPrefsHelper.setLastApiDate(periodKey); // Simpan Kunci Waktu
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // HEADER LENGKUNG ELEGAN 
            // ==========================================
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Selamat Datang,", style: TextStyle(fontSize: 14, color: Colors.green[100])),
                      const SizedBox(height: 4),
                      Text(userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 35), 

            // ==========================================
            // KARTU API PREMIUM (TheMealDB dgn Gambar & Waktu)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getMealTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 15),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                          child: _isLoadingMeal
                            ? Container(width: 110, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))))
                            : _mealThumb.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _mealThumb,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.restaurant, color: Colors.grey)),
                                  )
                                : Container(width: 110, color: Colors.orange[100], child: const Icon(Icons.restaurant, color: Colors.orange, size: 40)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 15, bottom: 15, right: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(5)),
                                  child: Text(_mealCategory.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _mealName, 
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87), 
                                  maxLines: 2, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 35),

            // ==========================================
            // PREVIEW: TEMPAT "LASSO INSIGHT EXPLORER" NANTI
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Analisis Root Cause", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2), width: 2), 
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.insights, size: 40, color: const Color(0xFF2E7D32).withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text(
                          "Area Custom Widget Lasso Segera Dibangun!", 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // ==========================================
            // MENU NAVIGASI CEPAT 
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Akses Fitur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
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
                      Expanded(child: _buildActionCard(context, "Evaluasi Diet", "Cek deviasi", Icons.analytics, Colors.orange, () => widget.onNavigate(3))),
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
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 20, child: Icon(icon, color: color, size: 20)),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import Core
import 'core/theme/theme.dart';
import 'core/utils/shared_prefs_helper.dart';

// Import Services (Milik Temanmu)
import 'features/domain_plan/services/notification_service.dart';

// Import Screens (Milik Athaya, Aca, dan Annisa)
import 'features/domain_input/screens/input_makanan_screen.dart';
import 'features/domain_plan/screens/rencana_makan_screen.dart';
import 'features/domain_eval/screens/evaluasi_list_screen.dart';
import 'features/domain_eval/screens/settings_screen.dart'; // Tetap di-import meski tidak di nav bawah
import 'features/domain_eval/screens/home_screen.dart';
import 'features/domain_eval/screens/login_screen.dart';
import 'features/profile/screens/profile_screen.dart';

void main() async {
  // Wajib dipanggil sebelum mengeksekusi kode async (await) di main
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi memori dan notifikasi
  await SharedPrefsHelper.init();
  await NotificationService.init();

  // Inisialisasi format tanggal (id_ID)
  await initializeDateFormatting('id_ID', null);

  runApp(const FitPlateApp());
}

class FitPlateApp extends StatelessWidget {
  const FitPlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPlate',
      debugShowCheckedModeBanner: false,
      
      // Memanggil tema kustom dengan warna utama Fresh Green
      theme: AppTheme.lightTheme, 
      
      // ---> SAKELAR PINTU MASUK (Logika Annisa dipertahankan) <---
      home: SharedPrefsHelper.isLoggedIn ? const MainNavigator() : const LoginScreen(), 
    );
  }
}

// Widget Navigator untuk menyatukan semua domain
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  // FUNGSI PINDAH TAB
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Daftar screens di dalam build() agar bisa mem-passing _onItemTapped
    final List<Widget> screens = [
      HomeScreen(onNavigate: _onItemTapped),  // Index 0: Tampilan Awal
      const InputMakananScreen(),             // Index 1: Jurnal Makanan (Teman)
      const RencanaMakanScreen(),             // Index 2: Meal Plan (Teman)
      const EvaluasiListScreen(),             // Index 3: Evaluasi (Annisa)
      const ProfileScreen(),                  // Index 4: Profil Pengguna (Teman)
    ];

    return Scaffold(
      body: screens[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Mencegah bug visual jika tab >= 4
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Beranda', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Jurnal', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Meal Plan', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Evaluasi', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
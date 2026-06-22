import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/domain_eval/screens/home_screen.dart';

// Import Core
import 'core/theme/theme.dart';
import 'core/utils/shared_prefs_helper.dart';

// Import Services
import 'features/domain_plan/services/notification_service.dart';

// Import Screens (Milik Athaya, Aca, dan Annisa)
import 'features/domain_input/screens/input_makanan_screen.dart';
import 'features/domain_plan/screens/rencana_makan_screen.dart';
import 'features/domain_eval/screens/evaluasi_list_screen.dart'; // 2. Kabel disambung ke layar baru Annisa
import 'features/domain_eval/screens/settings_screen.dart';      // 3. Kabel disambung ke pengaturan Annisa

// ---> TAMBAHAN: IMPORT LAYAR LOGIN <---
import 'features/domain_eval/screens/login_screen.dart'; 

void main() async {
  // Wajib dipanggil sebelum mengeksekusi kode async (await) di main
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi bawaan temanmu (Aman!)
  await SharedPrefsHelper.init();
  await NotificationService.init();

  // Inisialisasi bawaan Annisa (Aman!)
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
      
      // Memanggil tema kustom dengan warna utama Fresh Green (#2E7D32)
      theme: AppTheme.lightTheme, 
      
      // ---> SAKELAR PINTU MASUK <---
      // Jika sudah login, masuk ke MainNavigator. Jika belum, lempar ke LoginScreen.
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
    // Daftar screens diPINDAHKAN ke dalam fungsi build()!
    // Karena di dalam sini, fungsi _onItemTapped sudah "hidup" dan siap dipanggil.
    final List<Widget> screens = [
      HomeScreen(onNavigate: _onItemTapped),  // Index 0: Tampilan Awal
      const InputMakananScreen(),             // Index 1: Jurnal Makanan
      const RencanaMakanScreen(),             // Index 2: Meal Plan
      const EvaluasiListScreen(),             // Index 3: Evaluasi
    ];

    return Scaffold(
      // Manggil layarnya sekarang pakai 'screens' (tanpa underscore)
      body: screens[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
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
        ],
      ),
    );
  }
}
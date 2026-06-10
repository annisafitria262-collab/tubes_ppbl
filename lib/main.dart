import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 1. Tambahan Annisa (Wajib untuk format tanggal)

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

  // List layar untuk masing-masing domain (Sekarang ada 4 halaman)
  final List<Widget> _screens = [
    const InputMakananScreen(),   // Index 0: Domain 1 (Input & Makanan temanmu)
    const RencanaMakanScreen(),   // Index 1: Domain 2 (Planning & Logistik temanmu)
    const EvaluasiListScreen(),   // Index 2: Domain 3 (Karya Masterpiece Annisa)
    const SettingsScreen(),       // Index 3: Fitur Strict Mode Annisa
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // WAJIB DITAMBAHKAN biar menu >= 4 tidak bug/bergeser
        selectedItemColor: const Color(0xFF2E7D32), // Fresh Green
        unselectedItemColor: Colors.grey,
        items: const [
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
          // Tambahan menu tab ke-4 khusus untuk pengaturanmu
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan', 
          ),
        ],
      ),
    );
  }
}
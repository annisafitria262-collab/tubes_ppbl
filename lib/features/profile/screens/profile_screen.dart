import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/utils/shared_prefs_helper.dart';
import '../widgets/profile_avatar_painter.dart';
import '../widgets/achievement_badge_widget.dart';
import '../../domain_eval/screens/login_screen.dart';

/// ============================================================
/// ProfileScreen
/// ============================================================
/// Halaman profil lengkap pengguna FitPlate.
///
/// Fitur:
/// 1. AnimatedProfileAvatar (CustomPainter ring XP/streak/akurasi)
/// 2. Stats summary (total log, streak, akurasi)
/// 3. Weekly calorie chart (fl_chart BarChart, library yang ada)
/// 4. AchievementBadgeGrid (flip widget, hex CustomPainter)
/// 5. Edit profil inline (ubah nama, target kalori)
/// 6. Logout dengan konfirmasi
/// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State data profil
  String _userName = '';
  int _totalLogs = 0;
  int _currentStreak = 0;
  int _totalActiveDays = 0;
  double _avgAccuracy = 0.0;
  List<double> _weeklyCalories = List.filled(7, 0.0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final name = SharedPrefsHelper.loggedInUserName;
    final target = SharedPrefsHelper.dailyCalorieTarget;

    // Ambil statistik dari SQLite
    final db = await DatabaseHelper.instance.database;

    // Total log entry
    final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as c FROM log_konsumsi');
    final total = (totalResult.first['c'] as int?) ?? 0;

    // Total hari aktif (hari yang punya setidaknya 1 log)
    final daysResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT tanggal) as d FROM log_konsumsi');
    final days = (daysResult.first['d'] as int?) ?? 0;

    // Kalori 7 hari terakhir
    final weekly = await _fetchWeeklyCalories(db);

    // Streak sederhana: hitung mundur dari hari ini
    final streak = await _calculateStreak(db);

    // Rata-rata akurasi: kalori aktual / target × 100, diambil reratanya
    final accuracy = await _calculateAvgAccuracy(db, target);

    if (mounted) {
      setState(() {
        _userName = name;
        _totalLogs = total;
        _totalActiveDays = days;
        _weeklyCalories = weekly;
        _currentStreak = streak;
        _avgAccuracy = accuracy;
        _isLoading = false;
      });
    }
  }

  Future<List<double>> _fetchWeeklyCalories(Database db) async {
    final result = List<double>.filled(7, 0.0);
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final r = await db.rawQuery(
        'SELECT SUM(kalori_total) as s FROM log_konsumsi WHERE tanggal = ?',
        [dateStr],
      );
      result[6 - i] = (r.first['s'] as num?)?.toDouble() ?? 0.0;
    }
    return result;
  }

  Future<int> _calculateStreak(Database db) async {
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM log_konsumsi WHERE tanggal = ?',
        [dateStr],
      );
      final count = (r.first['c'] as int?) ?? 0;
      if (count > 0) {
        streak++;
      } else if (i > 0) {
        break; // Rantai terputus
      }
    }
    return streak;
  }

  Future<double> _calculateAvgAccuracy(Database db, double target) async {
    if (target <= 0) return 0.0;
    final r = await db.rawQuery(
      'SELECT tanggal, SUM(kalori_total) as total FROM log_konsumsi GROUP BY tanggal ORDER BY tanggal DESC LIMIT 14',
    );
    if (r.isEmpty) return 0.0;
    double sumAcc = 0.0;
    for (final row in r) {
      final actual = (row['total'] as num?)?.toDouble() ?? 0.0;
      final acc = 1.0 - ((actual - target).abs() / target).clamp(0.0, 1.0);
      sumAcc += acc;
    }
    return sumAcc / r.length;
  }

  void _showEditProfileDialog() async {
    final nameCtrl =
        TextEditingController(text: SharedPrefsHelper.loggedInUserName);
    final targetCtrl = TextEditingController(
        text: SharedPrefsHelper.dailyCalorieTarget.toInt().toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.edit, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Text('Edit Profil'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Kalori Harian',
                  prefixIcon: const Icon(Icons.local_fire_department),
                  suffixText: 'kkal',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newTarget =
                  double.tryParse(targetCtrl.text) ?? 2000.0;
              if (newName.isNotEmpty) {
                await SharedPrefsHelper.setLoggedInUserName(newName);
              }
              await SharedPrefsHelper.setDailyCalorieTarget(newTarget);
              // Juga update di tabel users
              final db = await DatabaseHelper.instance.database;
              await db.update(
                'users',
                {'nama': newName},
                where: 'id = ?',
                whereArgs: [SharedPrefsHelper.loggedInUserId],
              );
              if (mounted) {
                Navigator.pop(ctx);
                await _loadProfileData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil berhasil diperbarui ✅'),
                    backgroundColor: Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await SharedPrefsHelper.clearAuthData();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profil',
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Achievement'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildAchievementTab(),
              ],
            ),
    );
  }

  // ─── Tab 1: Ringkasan ─────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: const Color(0xFF2E7D32),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar dengan ring CustomPainter
            AnimatedProfileAvatar(
              userName: _userName,
              totalLogsAllTime: _totalLogs,
              currentStreak: _currentStreak,
              avgCalorieAccuracy: _avgAccuracy,
            ),
            const SizedBox(height: 12),

            // Nama & level
            Text(
              _userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _levelTitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 20),

            // Ring legend
            _buildRingLegend(),

            const SizedBox(height: 24),

            // Stats Row
            _buildStatsRow(),

            const SizedBox(height: 24),

            // Weekly Calorie Chart (fl_chart)
            _buildWeeklyChart(),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String get _levelTitle {
    final level = (_totalLogs ~/ 10).clamp(1, 10);
    if (level >= 8) return '🏆 Master FitPlate';
    if (level >= 5) return '⭐ Expert Nutrisionist';
    if (level >= 3) return '📈 Intermediate';
    return '🌱 Beginner — Terus semangat!';
  }

  Widget _buildRingLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ringLegendItem(
          color: _levelColor,
          label: 'XP Level',
          value: '${_totalLogs % 10}/10',
        ),
        const SizedBox(width: 16),
        _ringLegendItem(
          color: const Color(0xFF2E7D32),
          label: 'Streak',
          value: '$_currentStreak hari',
        ),
        const SizedBox(width: 16),
        _ringLegendItem(
          color: const Color(0xFF1565C0),
          label: 'Akurasi',
          value: '${(_avgAccuracy * 100).toInt()}%',
        ),
      ],
    );
  }

  Color get _levelColor {
    final level = (_totalLogs ~/ 10).clamp(1, 10);
    if (level >= 8) return const Color(0xFFFFD700);
    if (level >= 5) return const Color(0xFF9C27B0);
    if (level >= 3) return const Color(0xFF1565C0);
    return const Color(0xFF2E7D32);
  }

  Widget _ringLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
          icon: Icons.restaurant,
          label: 'Total Log',
          value: '$_totalLogs',
          unit: 'entri',
          color: const Color(0xFF2E7D32),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.local_fire_department,
          label: 'Streak',
          value: '$_currentStreak',
          unit: 'hari',
          color: const Color(0xFFFF6D00),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
          icon: Icons.calendar_today,
          label: 'Hari Aktif',
          value: '$_totalActiveDays',
          unit: 'hari',
          color: const Color(0xFF1565C0),
        )),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final target = SharedPrefsHelper.dailyCalorieTarget;
    final maxY = [
      ..._weeklyCalories,
      target * 1.3
    ].reduce((a, b) => a > b ? a : b);

    final dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final today = DateTime.now().weekday; // 1=Mon..7=Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Kalori 7 Hari Terakhir',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                width: 12,
                height: 3,
                color: Colors.red.shade300,
                margin: const EdgeInsets.only(right: 4),
              ),
              Text('Target',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY > 0 ? maxY : 2500,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '${rod.toY.toInt()} kkal',
                      const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        // Hitung index hari berdasarkan hari ini
                        // weeklyCalories[0] = 6 hari lalu, [6] = hari ini
                        final daysAgo = 6 - idx;
                        final d =
                            DateTime.now().subtract(Duration(days: daysAgo));
                        return Text(
                          dayLabels[(d.weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 10,
                            color: daysAgo == 0
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.shade500,
                            fontWeight: daysAgo == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}',
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey.shade400),
                      ),
                      interval: maxY > 0 ? (maxY / 4).ceilToDouble() : 500,
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval:
                      maxY > 0 ? (maxY / 4).ceilToDouble() : 500,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target,
                      color: Colors.red.shade300,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                    ),
                  ],
                ),
                barGroups: List.generate(
                  _weeklyCalories.length,
                  (i) {
                    final kal = _weeklyCalories[i];
                    final isToday = i == 6;
                    final isOver = kal > target;
                    Color barColor;
                    if (isOver) {
                      barColor = Colors.red.shade400;
                    } else if (isToday) {
                      barColor = const Color(0xFF2E7D32);
                    } else {
                      barColor = const Color(0xFF81C784);
                    }
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: kal,
                          color: barColor,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: Colors.grey.shade100,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab 2: Achievement ──────────────────────────────────────────────────

  Widget _buildAchievementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar level
          _buildLevelProgressCard(),
          const SizedBox(height: 20),

          // Badge grid
          AchievementBadgeGrid(
            totalLogs: _totalLogs,
            currentStreak: _currentStreak,
            totalDays: _totalActiveDays,
            avgAccuracy: _avgAccuracy,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgressCard() {
    final level = (_totalLogs ~/ 10).clamp(1, 10);
    final xpInLevel = _totalLogs % 10;
    final nextLevelXp = 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_levelColor, _levelColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Level $level — $_levelTitle',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpInLevel / nextLevelXp,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'XP: $xpInLevel / $nextLevelXp  •  Total $totalLogsStr log',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String get totalLogsStr => _totalLogs.toString();
}

// ─────────────────────────── Stat Card ─────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math';

/// ============================================================
/// AchievementBadgeWidget
/// ============================================================
/// Widget interaktif untuk menampilkan badge achievement pengguna.
/// - Tap badge → flip animasi + tampilkan deskripsi dan progress
/// - CustomPainter untuk ikon badge berbentuk hexagonal
/// - Menggunakan AnimationController untuk efek shimmer pada badge
///   yang sudah terbuka (unlocked)
/// ============================================================

enum BadgeStatus { locked, inProgress, unlocked }

class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String requirement;
  final IconData icon;
  final Color color;
  final BadgeStatus status;
  final double progress; // 0.0 – 1.0
  final int currentValue;
  final int targetValue;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.requirement,
    required this.icon,
    required this.color,
    required this.status,
    required this.progress,
    required this.currentValue,
    required this.targetValue,
  });
}

class AchievementBadgeGrid extends StatelessWidget {
  final int totalLogs;
  final int currentStreak;
  final int totalDays;
  final double avgAccuracy;

  const AchievementBadgeGrid({
    super.key,
    required this.totalLogs,
    required this.currentStreak,
    required this.totalDays,
    required this.avgAccuracy,
  });

  List<AchievementBadge> _buildBadges() {
    return [
      AchievementBadge(
        id: 'first_log',
        title: 'Langkah Pertama',
        description: 'Catat makanan pertamamu ke jurnal FitPlate!',
        requirement: '1 entri log',
        icon: Icons.restaurant,
        color: const Color(0xFF2E7D32),
        status: totalLogs >= 1 ? BadgeStatus.unlocked : BadgeStatus.locked,
        progress: (totalLogs / 1).clamp(0.0, 1.0),
        currentValue: totalLogs.clamp(0, 1),
        targetValue: 1,
      ),
      AchievementBadge(
        id: 'log_10',
        title: 'Konsisten!',
        description: 'Kamu sudah mencatat 10 makanan. Terus semangat!',
        requirement: '10 entri log',
        icon: Icons.emoji_events,
        color: const Color(0xFF1565C0),
        status: totalLogs >= 10
            ? BadgeStatus.unlocked
            : totalLogs > 0
                ? BadgeStatus.inProgress
                : BadgeStatus.locked,
        progress: (totalLogs / 10).clamp(0.0, 1.0),
        currentValue: totalLogs.clamp(0, 10),
        targetValue: 10,
      ),
      AchievementBadge(
        id: 'streak_3',
        title: 'Streak 3 Hari',
        description: 'Log makanan 3 hari berturut-turut. Habituasi dimulai!',
        requirement: '3 hari berturut-turut',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF6D00),
        status: currentStreak >= 3
            ? BadgeStatus.unlocked
            : currentStreak > 0
                ? BadgeStatus.inProgress
                : BadgeStatus.locked,
        progress: (currentStreak / 3).clamp(0.0, 1.0),
        currentValue: currentStreak.clamp(0, 3),
        targetValue: 3,
      ),
      AchievementBadge(
        id: 'streak_7',
        title: 'Seminggu Penuh',
        description: '7 hari berturut-turut! Kamu sudah punya habit sehat.',
        requirement: '7 hari streak',
        icon: Icons.whatshot,
        color: const Color(0xFFE53935),
        status: currentStreak >= 7
            ? BadgeStatus.unlocked
            : currentStreak > 0
                ? BadgeStatus.inProgress
                : BadgeStatus.locked,
        progress: (currentStreak / 7).clamp(0.0, 1.0),
        currentValue: currentStreak.clamp(0, 7),
        targetValue: 7,
      ),
      AchievementBadge(
        id: 'accuracy',
        title: 'Akurat!',
        description: 'Rata-rata akurasi kalori harian di atas 80%.',
        requirement: 'Akurasi ≥ 80%',
        icon: Icons.gps_fixed,
        color: const Color(0xFF9C27B0),
        status: avgAccuracy >= 0.8
            ? BadgeStatus.unlocked
            : avgAccuracy > 0
                ? BadgeStatus.inProgress
                : BadgeStatus.locked,
        progress: avgAccuracy.clamp(0.0, 1.0),
        currentValue: (avgAccuracy * 100).toInt().clamp(0, 100),
        targetValue: 80,
      ),
      AchievementBadge(
        id: 'explorer',
        title: 'Explorer',
        description: 'Sudah mencatat makanan selama 30 hari berbeda.',
        requirement: '30 hari aktif',
        icon: Icons.explore,
        color: const Color(0xFF00838F),
        status: totalDays >= 30
            ? BadgeStatus.unlocked
            : totalDays > 0
                ? BadgeStatus.inProgress
                : BadgeStatus.locked,
        progress: (totalDays / 30).clamp(0.0, 1.0),
        currentValue: totalDays.clamp(0, 30),
        targetValue: 30,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _buildBadges();
    final unlockedCount = badges.where((b) => b.status == BadgeStatus.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech,
                color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 6),
            const Text(
              'Achievement',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$unlockedCount / ${badges.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: badges.length,
          itemBuilder: (context, i) =>
              _BadgeCard(badge: badges[i]),
        ),
      ],
    );
  }
}

// ─────────────────────────── Badge Card (Flip Widget) ──────────────────────

class _BadgeCard extends StatefulWidget {
  final AchievementBadge badge;
  const _BadgeCard({required this.badge});

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnim;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.badge.status == BadgeStatus.locked) return;
    setState(() => _isFlipped = !_isFlipped);
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, child) {
          final isShowingBack = _flipAnim.value > pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnim.value),
            child: isShowingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    final badge = widget.badge;
    final isLocked = badge.status == BadgeStatus.locked;
    final isUnlocked = badge.status == BadgeStatus.unlocked;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.shade100 : badge.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocked
              ? Colors.grey.shade300
              : isUnlocked
                  ? badge.color
                  : badge.color.withOpacity(0.4),
          width: isUnlocked ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // CustomPainter hexagon badge
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _HexBadgePainter(
                color: isLocked ? Colors.grey : badge.color,
                progress: badge.progress,
                isUnlocked: isUnlocked,
              ),
              child: Center(
                child: Icon(
                  badge.icon,
                  size: 22,
                  color: isLocked ? Colors.grey.shade400 : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isLocked ? Colors.grey : Colors.black87,
            ),
          ),
          const SizedBox(height: 3),
          if (!isUnlocked)
            Text(
              '${badge.currentValue}/${badge.targetValue}',
              style: TextStyle(
                fontSize: 9,
                color: isLocked ? Colors.grey.shade400 : badge.color,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            const Icon(Icons.check_circle,
                size: 12, color: Color(0xFF2E7D32)),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final badge = widget.badge;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(badge.icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              height: 1.3,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap lagi →',
            style: TextStyle(
              fontSize: 8,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Hexagon Badge Painter ─────────────────────────

class _HexBadgePainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool isUnlocked;

  _HexBadgePainter({
    required this.color,
    required this.progress,
    required this.isUnlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Gambar hexagon
    final hexPath = _hexagonPath(center, radius);

    // Background hexagon
    canvas.drawPath(
      hexPath,
      Paint()..color = color.withOpacity(isUnlocked ? 1.0 : 0.5),
    );

    // Shimmer border saat unlocked
    if (isUnlocked) {
      canvas.drawPath(
        hexPath,
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Progress arc (saat in-progress)
    if (!isUnlocked && progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 3),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  Path _hexagonPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * pi / 3) - pi / 6;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_HexBadgePainter old) =>
      old.progress != progress || old.isUnlocked != isUnlocked;
}

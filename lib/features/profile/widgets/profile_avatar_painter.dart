import 'package:flutter/material.dart';
import 'dart:math';

/// ============================================================
/// ProfileAvatarPainter
/// ============================================================
/// CustomPainter untuk avatar profil dengan:
/// - Ring XP animasi (arc progress level pengguna)
/// - Badge level teks di pojok kanan bawah
/// - Tiga ring konsentris menunjukkan streak/achievement
/// Digunakan di ProfileScreen sebagai visual utama profil.
/// ============================================================

class AnimatedProfileAvatar extends StatefulWidget {
  final String userName;
  final int totalLogsAllTime;   // Total log masuk = XP
  final int currentStreak;      // Hari berturut-turut log masuk
  final double avgCalorieAccuracy; // 0.0–1.0

  const AnimatedProfileAvatar({
    super.key,
    required this.userName,
    required this.totalLogsAllTime,
    required this.currentStreak,
    required this.avgCalorieAccuracy,
  });

  @override
  State<AnimatedProfileAvatar> createState() =>
      _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  // Level system: setiap 10 log = 1 level (maks level 10)
  int get _level => (widget.totalLogsAllTime ~/ 10).clamp(1, 10);
  double get _xpProgress =>
      (widget.totalLogsAllTime % 10) / 10.0;

  // Streak progress (maks 7 hari untuk ring hijau)
  double get _streakProgress =>
      (widget.currentStreak / 7.0).clamp(0.0, 1.0);

  // Akurasi kalori untuk ring biru
  double get _accuracyProgress =>
      widget.avgCalorieAccuracy.clamp(0.0, 1.0);

  Color get _levelColor {
    if (_level >= 8) return const Color(0xFFFFD700); // Gold
    if (_level >= 5) return const Color(0xFF9C27B0); // Purple
    if (_level >= 3) return const Color(0xFF1565C0); // Blue
    return const Color(0xFF2E7D32); // Green
  }

  String get _levelTitle {
    if (_level >= 8) return 'Master';
    if (_level >= 5) return 'Expert';
    if (_level >= 3) return 'Intermediate';
    return 'Beginner';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.userName.isNotEmpty
        ? widget.userName
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // CustomPainter: 3 ring konsentris
              CustomPaint(
                size: const Size(160, 160),
                painter: _AvatarRingPainter(
                  xpProgress: _xpProgress * _anim.value,
                  streakProgress: _streakProgress * _anim.value,
                  accuracyProgress: _accuracyProgress * _anim.value,
                  levelColor: _levelColor,
                ),
              ),

              // Avatar Circle (inisial)
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _levelColor,
                      _levelColor.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _levelColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Badge Level (pojok kanan bawah)
              Positioned(
                right: 8,
                bottom: 8,
                child: Transform.scale(
                  scale: _anim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _levelColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _levelColor.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Lv.$_level',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Avatar Ring Painter ───────────────────────────

class _AvatarRingPainter extends CustomPainter {
  final double xpProgress;        // Ring terluar: XP/Level
  final double streakProgress;    // Ring tengah: Streak
  final double accuracyProgress;  // Ring dalam: Akurasi kalori
  final Color levelColor;

  _AvatarRingPainter({
    required this.xpProgress,
    required this.streakProgress,
    required this.accuracyProgress,
    required this.levelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const startAngle = -pi / 2;

    // ── Ring 1 (Terluar): XP Level ─────────────────────────────────
    _drawRing(
      canvas, center,
      radius: 76,
      strokeWidth: 8,
      progress: xpProgress,
      color: levelColor,
      bgColor: levelColor.withOpacity(0.15),
    );

    // ── Ring 2 (Tengah): Streak ─────────────────────────────────────
    _drawRing(
      canvas, center,
      radius: 60,
      strokeWidth: 7,
      progress: streakProgress,
      color: const Color(0xFF2E7D32),
      bgColor: const Color(0xFF2E7D32).withOpacity(0.12),
    );

    // ── Ring 3 (Dalam): Akurasi Kalori ──────────────────────────────
    _drawRing(
      canvas, center,
      radius: 46,
      strokeWidth: 6,
      progress: accuracyProgress,
      color: const Color(0xFF1565C0),
      bgColor: const Color(0xFF1565C0).withOpacity(0.12),
    );
  }

  void _drawRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double strokeWidth,
    required double progress,
    required Color color,
    required Color bgColor,
  }) {
    const startAngle = -pi / 2;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_AvatarRingPainter old) =>
      old.xpProgress != xpProgress ||
      old.streakProgress != streakProgress ||
      old.accuracyProgress != accuracyProgress;
}

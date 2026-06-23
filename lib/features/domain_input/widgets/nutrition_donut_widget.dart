import 'package:flutter/material.dart';
import 'dart:math';

/// ============================================================
/// NutritionDonutWidget
/// ============================================================
/// Custom widget INTERAKTIF dengan CustomPainter.
/// - Tap segmen donut → highlight & tampilkan detail makro
/// - Animasi fill saat pertama kali muncul (AnimationController)
/// - Segmen per waktu makan (Sarapan/Siang/Malam/Camilan)
/// ============================================================

class MacroSegment {
  final String label;
  final double value; // gram
  final double target; // gram target
  final Color color;
  final IconData icon;

  const MacroSegment({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    required this.icon,
  });

  double get percentage => target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
  double get percentageDisplay => target > 0 ? (value / target * 100) : 0.0;
  bool get isOver => value > target;
}

class NutritionDonutWidget extends StatefulWidget {
  final double kaloriAktual;
  final double kaloriTarget;
  final double proteinAktual;
  final double proteinTarget;
  final double karboAktual;
  final double karboTarget;
  final double lemakAktual;
  final double lemakTarget;

  const NutritionDonutWidget({
    super.key,
    required this.kaloriAktual,
    required this.kaloriTarget,
    required this.proteinAktual,
    required this.proteinTarget,
    required this.karboAktual,
    required this.karboTarget,
    required this.lemakAktual,
    required this.lemakTarget,
  });

  @override
  State<NutritionDonutWidget> createState() => _NutritionDonutWidgetState();
}

class _NutritionDonutWidgetState extends State<NutritionDonutWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fillAnimation;
  int _selectedIndex = -1; // -1 = tidak ada yang dipilih, 0/1/2 = index makro

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fillAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(NutritionDonutWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jalankan ulang animasi kalau data berubah
    if (oldWidget.kaloriAktual != widget.kaloriAktual) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<MacroSegment> get _segments => [
        MacroSegment(
          label: 'Protein',
          value: widget.proteinAktual,
          target: widget.proteinTarget,
          color: const Color(0xFF1565C0),
          icon: Icons.fitness_center,
        ),
        MacroSegment(
          label: 'Karbo',
          value: widget.karboAktual,
          target: widget.karboTarget,
          color: const Color(0xFFEF9F27),
          icon: Icons.grain,
        ),
        MacroSegment(
          label: 'Lemak',
          value: widget.lemakAktual,
          target: widget.lemakTarget,
          color: const Color(0xFFE53935),
          icon: Icons.opacity,
        ),
      ];

  void _onTapSegment(int index) {
    setState(() {
      _selectedIndex = (_selectedIndex == index) ? -1 : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    final overallProgress =
        widget.kaloriTarget > 0
            ? (widget.kaloriAktual / widget.kaloriTarget).clamp(0.0, 1.0)
            : 0.0;
    final sisa = widget.kaloriTarget - widget.kaloriAktual;
    final isOver = widget.kaloriAktual > widget.kaloriTarget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Donut + Tap Target ──────────────────────────────────
        GestureDetector(
          onTapUp: (details) {
            // Deteksi tap pada segmen donut menggunakan hitTest sederhana
            // Untuk UX, cukup toggle selected index via tombol bawah
          },
          child: AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, _) {
              return SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: _DonutPainter(
                        segments: segments,
                        animationValue: _fillAnimation.value,
                        selectedIndex: _selectedIndex,
                        overallProgress: overallProgress,
                        isOver: isOver,
                      ),
                    ),
                    // Teks tengah
                    _buildCenterText(sisa, isOver, overallProgress),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Chip Makro Interaktif ───────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(segments.length, (i) {
            final seg = segments[i];
            final isSelected = _selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _MacroTapChip(
                segment: seg,
                isSelected: isSelected,
                onTap: () => _onTapSegment(i),
              ),
            );
          }),
        ),

        const SizedBox(height: 12),

        // ── Panel Detail (muncul saat makro di-tap) ────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _selectedIndex >= 0
              ? _DetailPanel(
                  key: ValueKey(_selectedIndex),
                  segment: segments[_selectedIndex],
                )
              : const SizedBox.shrink(key: ValueKey(-1)),
        ),
      ],
    );
  }

  Widget _buildCenterText(double sisa, bool isOver, double overallProgress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.kaloriAktual.toInt()}',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: isOver ? Colors.red : const Color(0xFF2E7D32),
            height: 1.0,
          ),
        ),
        Text(
          'dari ${widget.kaloriTarget.toInt()} kkal',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isOver
                ? Colors.red.withOpacity(0.12)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isOver
                ? '⚠️ +${(-sisa).toInt()} kkal'
                : '${(overallProgress * 100).toInt()}% terpenuhi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isOver ? Colors.red.shade700 : const Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── DonutPainter ──────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<MacroSegment> segments;
  final double animationValue;
  final int selectedIndex;
  final double overallProgress;
  final bool isOver;

  _DonutPainter({
    required this.segments,
    required this.animationValue,
    required this.selectedIndex,
    required this.overallProgress,
    required this.isOver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Ring terluar: Progress Kalori Keseluruhan ──────────────────
    _drawRing(
      canvas,
      center,
      radius: 110,
      strokeWidth: 10,
      progress: overallProgress * animationValue,
      color: isOver ? Colors.red : const Color(0xFF2E7D32),
      bgColor: Colors.grey.shade200,
    );

    // ── 3 Segmen Donut (Protein, Karbo, Lemak) ─────────────────────
    // Distribusi: setiap segmen menempati 120° (sepertiga lingkaran)
    // dengan gap 8° antar segmen
    const gapDeg = 8.0;
    const segDeg = (360.0 - gapDeg * 3) / 3;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startDeg = -90.0 + i * (segDeg + gapDeg);
      final startRad = startDeg * pi / 180;
      final sweepRad = segDeg * pi / 180;

      final isSelected = selectedIndex == i;
      final radius = isSelected ? 88.0 : 82.0;
      final strokeWidth = isSelected ? 18.0 : 14.0;

      // Background track
      _drawArc(
        canvas,
        center,
        radius: radius,
        strokeWidth: strokeWidth,
        startAngle: startRad,
        sweepAngle: sweepRad,
        color: seg.color.withOpacity(0.15),
      );

      // Progress fill (animasi)
      final fillSweep = sweepRad * seg.percentage * animationValue;
      if (fillSweep > 0) {
        _drawArc(
          canvas,
          center,
          radius: radius,
          strokeWidth: strokeWidth,
          startAngle: startRad,
          sweepAngle: fillSweep,
          color: seg.isOver ? Colors.red : seg.color,
          cap: StrokeCap.round,
        );
      }

      // Highlight glow saat selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = seg.color.withOpacity(0.2)
          ..strokeWidth = strokeWidth + 8
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startRad,
          sweepRad,
          false,
          glowPaint,
        );
      }
    }
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
    // Background
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground
    if (progress > 0) {
      _drawArc(
        canvas,
        center,
        radius: radius,
        strokeWidth: strokeWidth,
        startAngle: -pi / 2,
        sweepAngle: 2 * pi * progress,
        color: color,
        cap: StrokeCap.round,
      );
    }
  }

  void _drawArc(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double strokeWidth,
    required double startAngle,
    required double sweepAngle,
    required Color color,
    StrokeCap cap = StrokeCap.butt,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = cap;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.animationValue != animationValue ||
      old.selectedIndex != selectedIndex ||
      old.overallProgress != overallProgress ||
      old.isOver != isOver;
}

// ─────────────────────────── Macro Tap Chip ────────────────────────────────

class _MacroTapChip extends StatelessWidget {
  final MacroSegment segment;
  final bool isSelected;
  final VoidCallback onTap;

  const _MacroTapChip({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? segment.color.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? segment.color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: segment.color.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              segment.icon,
              size: 16,
              color: isSelected ? segment.color : Colors.grey,
            ),
            const SizedBox(height: 3),
            Text(
              segment.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? segment.color : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${segment.value.toStringAsFixed(1)}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? segment.color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Detail Panel ──────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final MacroSegment segment;

  const _DetailPanel({super.key, required this.segment});

  @override
  Widget build(BuildContext context) {
    final percent = segment.percentageDisplay;
    final isOver = segment.isOver;
    final remaining = segment.target - segment.value;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: segment.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOver ? Colors.red.shade300 : segment.color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(segment.icon, color: segment.color, size: 18),
              const SizedBox(width: 8),
              Text(
                segment.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: segment.color,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOver
                      ? Colors.red.withOpacity(0.1)
                      : segment.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOver ? '⚠️ Over!' : '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOver ? Colors.red.shade700 : segment.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: segment.percentage,
              minHeight: 8,
              backgroundColor: segment.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver ? Colors.red : segment.color,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Aktual', '${segment.value.toStringAsFixed(1)}g',
                  segment.color),
              _statItem(
                  'Target', '${segment.target.toStringAsFixed(0)}g', Colors.grey),
              _statItem(
                isOver ? 'Kelebihan' : 'Sisa',
                isOver
                    ? '+${(-remaining).toStringAsFixed(1)}g'
                    : '${remaining.toStringAsFixed(1)}g',
                isOver ? Colors.red : Colors.green.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

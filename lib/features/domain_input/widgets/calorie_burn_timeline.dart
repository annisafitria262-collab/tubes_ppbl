import 'package:flutter/material.dart';
import 'dart:math';
import '../models/log_konsumsi_model.dart';

/// ============================================================
/// CalorieBurnTimeline
/// ============================================================
/// Custom widget interaktif yang memvisualisasikan distribusi
/// kalori per waktu makan sepanjang hari.
///
/// Fitur:
/// - CustomPainter: garis waktu dengan "bubble" kalori per sesi
/// - Tap bubble → expand detail log per waktu makan
/// - Animasi masuk setiap bubble saat widget dibuild
/// - Warna per waktu makan (Sarapan=kuning, Siang=hijau, dll)
/// ============================================================

class MealTimeEntry {
  final String waktu;
  final String label;
  final String timeRange;
  final Color color;
  final IconData icon;
  final List<LogKonsumsiModel> logs;

  const MealTimeEntry({
    required this.waktu,
    required this.label,
    required this.timeRange,
    required this.color,
    required this.icon,
    required this.logs,
  });

  double get totalKalori =>
      logs.fold(0.0, (sum, l) => sum + l.kaloriTotal);

  bool get hasLogs => logs.isNotEmpty;
}

class CalorieBurnTimeline extends StatefulWidget {
  final List<LogKonsumsiModel> allLogs;
  final double kaloriTarget;

  const CalorieBurnTimeline({
    super.key,
    required this.allLogs,
    required this.kaloriTarget,
  });

  @override
  State<CalorieBurnTimeline> createState() => _CalorieBurnTimelineState();
}

class _CalorieBurnTimelineState extends State<CalorieBurnTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int _expandedIndex = -1;

  static const _waktuOrder = [
    'SARAPAN',
    'MAKAN_SIANG',
    'MAKAN_MALAM',
    'CAMILAN',
  ];

  static const _waktuConfig = {
    'SARAPAN': {
      'label': 'Sarapan',
      'time': '06:00 – 09:00',
      'color': Color(0xFFFFB300),
      'icon': Icons.wb_sunny,
    },
    'MAKAN_SIANG': {
      'label': 'Makan Siang',
      'time': '11:00 – 14:00',
      'color': Color(0xFF2E7D32),
      'icon': Icons.wb_cloudy,
    },
    'MAKAN_MALAM': {
      'label': 'Makan Malam',
      'time': '18:00 – 21:00',
      'color': Color(0xFF1565C0),
      'icon': Icons.nights_stay,
    },
    'CAMILAN': {
      'label': 'Camilan',
      'time': 'Sewaktu-waktu',
      'color': Color(0xFFAD1457),
      'icon': Icons.cookie,
    },
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<MealTimeEntry> _buildEntries() {
    final grouped = <String, List<LogKonsumsiModel>>{};
    for (final w in _waktuOrder) {
      grouped[w] = [];
    }
    for (final log in widget.allLogs) {
      if (grouped.containsKey(log.waktuMakan)) {
        grouped[log.waktuMakan]!.add(log);
      }
    }
    return _waktuOrder.map((w) {
      final cfg = _waktuConfig[w]!;
      return MealTimeEntry(
        waktu: w,
        label: cfg['label'] as String,
        timeRange: cfg['time'] as String,
        color: cfg['color'] as Color,
        icon: cfg['icon'] as IconData,
        logs: grouped[w]!,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    final totalKalori =
        entries.fold(0.0, (s, e) => s + e.totalKalori);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.timeline,
                color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 6),
            const Text(
              'Timeline Makan Hari Ini',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${totalKalori.toInt()} kkal',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Timeline Items
        ...List.generate(entries.length, (i) {
          final entry = entries[i];
          final isLast = i == entries.length - 1;
          final isExpanded = _expandedIndex == i;

          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              // Stagger: setiap item muncul dengan delay berbeda
              final staggeredValue = Curves.easeOut.transform(
                (((_animation.value * 4) - i).clamp(0.0, 1.0)),
              );
              return Opacity(
                opacity: staggeredValue,
                child: Transform.translate(
                  offset: Offset((1 - staggeredValue) * 30, 0),
                  child: child,
                ),
              );
            },
            child: _TimelineItem(
              entry: entry,
              isLast: isLast,
              isExpanded: isExpanded,
              kaloriTarget: widget.kaloriTarget,
              onTap: () {
                setState(() {
                  _expandedIndex = isExpanded ? -1 : i;
                });
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────── Timeline Item ─────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final MealTimeEntry entry;
  final bool isLast;
  final bool isExpanded;
  final double kaloriTarget;
  final VoidCallback onTap;

  const _TimelineItem({
    required this.entry,
    required this.isLast,
    required this.isExpanded,
    required this.kaloriTarget,
    required this.onTap,
  });

  // Target per sesi = 25% dari total (distribusi merata)
  double get _sessionTarget => kaloriTarget * 0.25;
  double get _fillRatio =>
      _sessionTarget > 0
          ? (entry.totalKalori / _sessionTarget).clamp(0.0, 1.5)
          : 0.0;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Garis Waktu & Bubble ────────────────────────────
          SizedBox(
            width: 56,
            child: Column(
              children: [
                // Bubble interaktif
                GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isExpanded ? 46 : 40,
                    height: isExpanded ? 46 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.hasLogs
                          ? entry.color
                          : Colors.grey.shade200,
                      boxShadow: isExpanded
                          ? [
                              BoxShadow(
                                color: entry.color.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      entry.icon,
                      color: entry.hasLogs ? Colors.white : Colors.grey,
                      size: isExpanded ? 22 : 18,
                    ),
                  ),
                ),
                // Garis bawah
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin:
                          const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: entry.hasLogs
                            ? entry.color.withOpacity(0.3)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                if (isLast) const SizedBox(height: 12),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Konten Kartu ────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? entry.color.withOpacity(0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpanded
                        ? entry.color.withOpacity(0.5)
                        : Colors.grey.shade200,
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris label + kalori
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isExpanded
                                    ? entry.color
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              entry.timeRange,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              entry.hasLogs
                                  ? '${entry.totalKalori.toInt()} kkal'
                                  : 'Belum ada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: entry.hasLogs
                                    ? entry.color
                                    : Colors.grey,
                              ),
                            ),
                            Text(
                              entry.hasLogs
                                  ? '${entry.logs.length} item'
                                  : 'Kosong',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Mini progress bar kalori sesi
                    if (entry.hasLogs) ...[
                      const SizedBox(height: 8),
                      _SessionProgressBar(
                        fillRatio: _fillRatio,
                        color: entry.color,
                        sessionTarget: _sessionTarget,
                        aktual: entry.totalKalori,
                      ),
                    ],

                    // Detail logs saat expanded
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: isExpanded && entry.hasLogs
                          ? Column(
                              children: [
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                ...entry.logs.map(
                                  (log) => _LogRow(
                                      log: log, color: entry.color),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Session Progress Bar ──────────────────────────

class _SessionProgressBar extends StatelessWidget {
  final double fillRatio;
  final Color color;
  final double sessionTarget;
  final double aktual;

  const _SessionProgressBar({
    required this.fillRatio,
    required this.color,
    required this.sessionTarget,
    required this.aktual,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = fillRatio > 1.0;
    return CustomPaint(
      size: const Size(double.infinity, 12),
      painter: _SessionBarPainter(
        fillRatio: fillRatio.clamp(0.0, 1.5),
        color: isOver ? Colors.red : color,
        bgColor: color.withOpacity(0.12),
      ),
    );
  }
}

class _SessionBarPainter extends CustomPainter {
  final double fillRatio;
  final Color color;
  final Color bgColor;

  const _SessionBarPainter({
    required this.fillRatio,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // Background
    canvas.drawRRect(rrect, Paint()..color = bgColor);

    // Fill
    final fillWidth = size.width * fillRatio.clamp(0.0, 1.0);
    if (fillWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, size.height),
        Radius.circular(radius),
      );
      canvas.drawRRect(fillRect, Paint()..color = color);
    }

    // Over indicator (garis merah di ujung)
    if (fillRatio > 1.0) {
      final overPaint = Paint()
        ..color = Colors.red.shade700
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        overPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SessionBarPainter old) =>
      old.fillRatio != fillRatio;
}

// ─────────────────────────── Log Row ──────────────────────────────────────

class _LogRow extends StatelessWidget {
  final LogKonsumsiModel log;
  final Color color;

  const _LogRow({required this.log, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.namaMakanan ?? 'Unknown',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${log.jumlahGram.toInt()}g',
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 8),
          Text(
            '${log.kaloriTotal.toInt()} kkal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

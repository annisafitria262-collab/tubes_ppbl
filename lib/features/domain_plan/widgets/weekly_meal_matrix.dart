import 'package:flutter/material.dart';

class WeeklyMealMatrix extends StatelessWidget {
  final List<List<int>> matrixData;
  final List<String> hariList;
  final List<String> waktuList;
  final void Function(String hari, String waktu)? onCellTapped;
  final void Function(String hari, String waktu)? onCellDoubleTapped;

  const WeeklyMealMatrix({
    super.key,
    required this.matrixData,
    this.hariList = const [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ],
    this.waktuList = const [
      'SARAPAN', 'MAKAN_SIANG', 'MAKAN_MALAM', 'CAMILAN'
    ],
    this.onCellTapped,
    this.onCellDoubleTapped,
  });

  String _shortWaktu(String w) {
    switch (w) {
      case 'SARAPAN': return 'Pagi';
      case 'MAKAN_SIANG': return 'Siang';
      case 'MAKAN_MALAM': return 'Malam';
      case 'CAMILAN': return 'Camil';
      default: return w.length > 5 ? w.substring(0, 5) : w;
    }
  }

  String _shortHari(String h) => h.length > 3 ? h.substring(0, 3) : h;

  // Hitung stats dari matrixData
  int get _totalTerisi {
    int count = 0;
    for (var row in matrixData) {
      for (var cell in row) {
        if (cell > 0) count++;
      }
    }
    return count;
  }

  int get _totalAktif {
    int count = 0;
    for (var row in matrixData) {
      for (var cell in row) {
        if (cell == 2) count++;
      }
    }
    return count;
  }

  int get _totalSlot => (matrixData.isNotEmpty ? matrixData.length : 4) * 7;

  @override
  Widget build(BuildContext context) {
    final persen = _totalSlot > 0 ? _totalTerisi / _totalSlot : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(children: [
              Icon(Icons.grid_view, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 6),
              Text(
                'Weekly Meal Matrix',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
            // Stats chip
            Row(children: [
              _statBadge('$_totalTerisi/$_totalSlot', 'Terisi', const Color(0xFF0D47A1)),
              const SizedBox(width: 6),
              _statBadge('$_totalAktif', 'Aktif', const Color(0xFF2E7D32)),
            ]),
          ],
        ),
        const SizedBox(height: 8),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Progress bar kelengkapan
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kelengkapan Rencana',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${(persen * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: persen,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E7D32)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Header hari
                Row(
                  children: [
                    const SizedBox(width: 50),
                    ...List.generate(7, (col) {
                      final hari = col < hariList.length
                          ? _shortHari(hariList[col])
                          : '-';
                      // Tandai hari ini
                      final today = DateTime.now();
                      final todayIdx = today.weekday - 1;
                      final isToday = col == todayIdx;

                      return Expanded(
                        child: Center(
                          child: Container(
                            padding: isToday
                                ? const EdgeInsets.symmetric(
                                    horizontal: 2, vertical: 1)
                                : null,
                            decoration: isToday
                                ? BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  )
                                : null,
                            child: Text(
                              hari,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isToday
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 6),

                // Matrix rows + CustomPaint
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label waktu kiri
                    Column(
                      children: List.generate(4, (row) {
                        final waktu = row < waktuList.length
                            ? _shortWaktu(waktuList[row])
                            : '-';
                        return SizedBox(
                          height: 32,
                          width: 50,
                          child: Center(
                            child: Text(
                              waktu,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // CustomPaint grid wrapped with GestureDetector for tap/double-tap gestures
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth = constraints.maxWidth / 7;
                          const cellHeight = 128.0 / 4;

                          return GestureDetector(
                            onTapUp: (details) {
                              if (onCellTapped != null) {
                                final x = details.localPosition.dx;
                                final y = details.localPosition.dy;
                                int col = (x / cellWidth).floor().clamp(0, 6);
                                int row = (y / cellHeight).floor().clamp(0, 3);
                                if (col < hariList.length && row < waktuList.length) {
                                  onCellTapped!(hariList[col], waktuList[row]);
                                }
                              }
                            },
                            onDoubleTapDown: (details) {
                              if (onCellDoubleTapped != null) {
                                final x = details.localPosition.dx;
                                final y = details.localPosition.dy;
                                int col = (x / cellWidth).floor().clamp(0, 6);
                                int row = (y / cellHeight).floor().clamp(0, 3);
                                if (col < hariList.length && row < waktuList.length) {
                                  onCellDoubleTapped!(hariList[col], waktuList[row]);
                                }
                              }
                            },
                            child: SizedBox(
                              height: 128,
                              child: CustomPaint(
                                painter: MealMatrixPainter(matrixData: matrixData),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegend(Colors.grey.shade200, '⬜ Kosong'),
                    const SizedBox(width: 16),
                    _buildLegend(
                        Colors.blue.shade300, '🔵 Direncanakan'),
                    const SizedBox(width: 16),
                    _buildLegend(
                        const Color(0xFF4CAF50), '✅ Aktif'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
      ]),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}

/// CustomPainter: Render grid warna berdasarkan matrixData dari SQLite
class MealMatrixPainter extends CustomPainter {
  final List<List<int>> matrixData;

  const MealMatrixPainter({required this.matrixData});

  @override
  void paint(Canvas canvas, Size size) {
    final double cellWidth = size.width / 7;
    final double cellHeight = size.height / 4;

    // Today highlight
    final todayIdx = DateTime.now().weekday - 1; // 0=Senin ... 6=Minggu

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 7; col++) {
        int status = 0;
        if (row < matrixData.length && col < matrixData[row].length) {
          status = matrixData[row][col];
        }

        // Background today column (subtle highlight)
        if (col == todayIdx) {
          final bgPaint = Paint()
            ..color = const Color(0xFFE8F5E9)
            ..style = PaintingStyle.fill;
          final bgRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              col * cellWidth,
              row * cellHeight,
              cellWidth,
              cellHeight,
            ).deflate(1),
            const Radius.circular(6),
          );
          canvas.drawRRect(bgRect, bgPaint);
        }

        // Cell fill color
        Color cellColor;
        if (status == 2) {
          cellColor = const Color(0xFF4CAF50); // Aktif — hijau
        } else if (status == 1) {
          cellColor = Colors.blue.shade300; // DRAFT — biru
        } else {
          cellColor = Colors.grey.shade200; // Kosong
        }

        final Paint cellPaint = Paint()
          ..color = cellColor
          ..style = PaintingStyle.fill;

        final RRect paddedRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
          ).deflate(2.5),
          const Radius.circular(5),
        );
        canvas.drawRRect(paddedRect, cellPaint);

        // Tanda di dalam cell
        if (status > 0) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: status == 2 ? '✓' : '·',
              style: TextStyle(
                color: status == 2
                    ? Colors.white
                    : Colors.blue.shade700,
                fontSize: cellHeight * 0.45,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              col * cellWidth +
                  (cellWidth - textPainter.width) / 2,
              row * cellHeight +
                  (cellHeight - textPainter.height) / 2,
            ),
          );
        }

        // Border today column
        if (col == todayIdx && status == 0) {
          final borderPaint = Paint()
            ..color = const Color(0xFF81C784)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          canvas.drawRRect(paddedRect, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MealMatrixPainter oldDelegate) {
    // Deep compare
    if (oldDelegate.matrixData.length != matrixData.length) return true;
    for (int i = 0; i < matrixData.length; i++) {
      for (int j = 0; j < matrixData[i].length; j++) {
        if (i >= oldDelegate.matrixData.length ||
            j >= oldDelegate.matrixData[i].length ||
            oldDelegate.matrixData[i][j] != matrixData[i][j]) {
          return true;
        }
      }
    }
    return false;
  }
}
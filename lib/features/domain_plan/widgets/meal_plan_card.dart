import 'package:flutter/material.dart';
import '../models/rencana_makan_model.dart';

/// [MealPlanCard] is a reusable card widget to display a single [RencanaMakanModel].
/// It supports gestures like Swipe (for dismissal/deletion), Tap, Double Tap (quick toggle status),
/// and Long Press (actions menu bottom sheet).
class MealPlanCard extends StatelessWidget {
  final RencanaMakanModel rencana;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onToggleStatus;
  final VoidCallback onLongPress;

  const MealPlanCard({
    super.key,
    required this.rencana,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onToggleStatus,
    required this.onLongPress,
  });

  String _formatWaktu(String w) {
    switch (w) {
      case 'SARAPAN':
        return 'Sarapan';
      case 'MAKAN_SIANG':
        return 'Makan Siang';
      case 'MAKAN_MALAM':
        return 'Makan Malam';
      case 'CAMILAN':
        return 'Camilan';
      default:
        return w;
    }
  }

  Color _statusColor(String status) =>
      status == 'AKTIF' ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1);

  IconData _statusIcon(String status) =>
      status == 'AKTIF' ? Icons.check_circle : Icons.pending;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(rencana.status);

    return Dismissible(
      key: Key('meal_plan_${rencana.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Confirmation is handled by trigger onDeletePressed
        onDeletePressed();
        return false; // Let the screen handle list state update and deletion confirmation dialog
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          // ignore: deprecated_member_use
          side: BorderSide(color: statusColor.withOpacity(0.3)),
        ),
        child: InkWell(
          onDoubleTap: onToggleStatus,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rencana.hari.substring(0, 3),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Icon(_statusIcon(rencana.status), size: 14, color: statusColor),
              ],
            ),
            title: Text(
              rencana.namaMakanan ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatWaktu(rencana.waktuMakan)}  •  ${rencana.jumlahGram.toStringAsFixed(0)}g',
                  style: const TextStyle(fontSize: 12),
                ),
                if (rencana.kaloriPer100g != null)
                  Text(
                    '${((rencana.kaloriPer100g! * rencana.jumlahGram) / 100).toStringAsFixed(0)} kkal',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rencana.status,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF0D47A1), size: 18),
                  onPressed: onEditPressed,
                  tooltip: 'Edit Rencana',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 18),
                  onPressed: onDeletePressed,
                  tooltip: 'Hapus Rencana',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

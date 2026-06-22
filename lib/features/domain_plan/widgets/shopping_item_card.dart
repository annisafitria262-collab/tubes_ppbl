import 'package:flutter/material.dart';
import '../models/daftar_belanja_model.dart';

/// [ShoppingItemCard] is a reusable card widget to display a single [DaftarBelanjaModel].
/// It supports gestures like Swipe (for deletion) and Long Press (for actions),
/// and displays checkbox status toggles.
class ShoppingItemCard extends StatelessWidget {
  final DaftarBelanjaModel item;
  final ValueChanged<bool?> onToggleChecked;
  final VoidCallback onDeletePressed;
  final VoidCallback onLongPress;

  const ShoppingItemCard({
    super.key,
    required this.item,
    required this.onToggleChecked,
    required this.onDeletePressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isBeli = item.sudahDibeli == 1;

    return Dismissible(
      key: Key('shopping_item_${item.id}'),
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
        elevation: isBeli ? 0 : 1,
        color: isBeli ? Colors.grey.shade100 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isBeli
                ? Colors.grey.shade300
                : item.sumber == 'auto'
                    ? const Color(0xFF81C784)
                    : Colors.blue.shade200,
          ),
        ),
        child: InkWell(
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            leading: Checkbox(
              value: isBeli,
              activeColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: onToggleChecked,
            ),
            title: Text(
              item.namaItem,
              style: TextStyle(
                decoration: isBeli ? TextDecoration.lineThrough : null,
                color: isBeli ? Colors.grey : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  '${item.jumlahTotal.toStringAsFixed(0)} ${item.satuan}',
                  style: TextStyle(
                    color: isBeli ? Colors.grey.shade400 : null,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: item.sumber == 'auto' ? const Color(0xFFE8F5E9) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.sumber == 'auto' ? '🔄 Auto' : '✏️ Manual',
                    style: TextStyle(
                      fontSize: 10,
                      color: item.sumber == 'auto' ? const Color(0xFF2E7D32) : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
              tooltip: 'Hapus item',
              onPressed: onDeletePressed,
            ),
          ),
        ),
      ),
    );
  }
}

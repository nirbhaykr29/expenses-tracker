import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../utils/formatters.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;
    final color = isCredit ? const Color(0xFF087F5B) : const Color(0xFFD64545);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        child: Icon(
          isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 20,
        ),
      ),
      title: Text(
        transaction.category,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        transaction.note?.isNotEmpty == true
            ? '${formatDate(transaction.date)} · ${transaction.note}'
            : formatDate(transaction.date),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isCredit ? '+' : '−'}${formatRupees(transaction.amountPaise)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'Transaction options',
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}

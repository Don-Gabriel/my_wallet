import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../shared/formatters.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDuplicate,
    this.onRefund,
    this.onSplit,
    this.onMakeRecurring,
    this.onDelete,
  });

  final WalletTransaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onRefund;
  final VoidCallback? onSplit;
  final VoidCallback? onMakeRecurring;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final impact = transaction.balanceImpact;
    final amountColor = transaction.type == WalletTransactionType.transfer
        ? Theme.of(context).colorScheme.tertiary
        : impact < 0
        ? const Color(0xFFC84B31)
        : const Color(0xFF1A7F64);
    final amountText = transaction.type == WalletTransactionType.transfer
        ? formatMoney(transaction.amount)
        : formatMoney(impact, signed: true);
    final subtitleParts = [
      transaction.type.label,
      formatDate(transaction.date),
      if (transaction.notes.isNotEmpty) transaction.notes,
    ];

    return ListTile(
      dense: true,
      minVerticalPadding: 6,
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: amountColor.withValues(alpha: 0.12),
            child: Icon(transaction.type.icon, color: amountColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amountText,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (onEdit != null ||
              onDuplicate != null ||
              onRefund != null ||
              onSplit != null ||
              onMakeRecurring != null ||
              onDelete != null) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              tooltip: 'Transaction actions',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                }
                if (value == 'duplicate') {
                  onDuplicate?.call();
                }
                if (value == 'refund') {
                  onRefund?.call();
                }
                if (value == 'split') {
                  onSplit?.call();
                }
                if (value == 'recurring') {
                  onMakeRecurring?.call();
                }
                if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onDuplicate != null)
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                if (onRefund != null &&
                    transaction.type == WalletTransactionType.expense)
                  const PopupMenuItem(value: 'refund', child: Text('Refund')),
                if (onSplit != null)
                  const PopupMenuItem(value: 'split', child: Text('Split')),
                if (onMakeRecurring != null &&
                    transaction.type != WalletTransactionType.transfer)
                  const PopupMenuItem(
                    value: 'recurring',
                    child: Text('Make recurring'),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

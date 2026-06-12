import '../models/transaction.dart';
import '../models/wallet_account.dart';

class CsvImportResult {
  const CsvImportResult({required this.drafts, required this.skippedRows});

  final List<TransactionDraft> drafts;
  final int skippedRows;
}

String transactionsToCsv(
  List<WalletTransaction> transactions,
  List<WalletAccount> wallets,
) {
  final walletNames = {for (final wallet in wallets) wallet.id: wallet.name};
  final buffer = StringBuffer(
    'date,type,category,amount,notes,paymentMethod,wallet,walletId,transferWalletId\n',
  );

  for (final transaction in transactions) {
    buffer.writeln(
      [
        transaction.date.toIso8601String(),
        transaction.type.name,
        transaction.category,
        transaction.amount.toStringAsFixed(2),
        transaction.notes,
        transaction.paymentMethod,
        walletNames[transaction.walletId] ?? 'Main wallet',
        transaction.walletId,
        transaction.transferWalletId ?? '',
      ].map(_escapeCsv).join(','),
    );
  }

  return buffer.toString();
}

CsvImportResult parseTransactionsCsv(
  String input, {
  required List<String> categories,
  required List<WalletAccount> wallets,
}) {
  final rows = _parseRows(input);
  if (rows.isEmpty) {
    return const CsvImportResult(drafts: [], skippedRows: 0);
  }

  final header = rows.first.map((cell) => cell.trim().toLowerCase()).toList();
  final hasHeader = header.contains('amount') && header.contains('type');
  final dataRows = hasHeader ? rows.skip(1) : rows;
  final indexes = hasHeader
      ? {for (var i = 0; i < header.length; i++) header[i]: i}
      : const <String, int>{
          'date': 0,
          'type': 1,
          'category': 2,
          'amount': 3,
          'notes': 4,
          'paymentmethod': 5,
          'wallet': 6,
          'walletid': 7,
          'transferwalletid': 8,
        };

  final walletIds = {for (final wallet in wallets) wallet.id: wallet.id};
  final walletNames = {
    for (final wallet in wallets) wallet.name.toLowerCase(): wallet.id,
  };
  var skippedRows = 0;
  final drafts = <TransactionDraft>[];

  for (final row in dataRows) {
    final amount = double.tryParse(_cell(row, indexes, 'amount'));
    final type = transactionTypeFromStorage(_cell(row, indexes, 'type'));
    final date = _parseDate(_cell(row, indexes, 'date'));
    final rawCategory = _cell(row, indexes, 'category').trim();
    if (amount == null || amount <= 0 || date == null) {
      skippedRows++;
      continue;
    }

    final rawWalletId = _cell(row, indexes, 'walletid').trim();
    final rawWalletName = _cell(row, indexes, 'wallet').trim().toLowerCase();
    final walletId =
        walletIds[rawWalletId] ?? walletNames[rawWalletName] ?? defaultWalletId;
    final transferWalletId = _cell(row, indexes, 'transferwalletid').trim();

    drafts.add(
      TransactionDraft(
        amount: amount,
        category: rawCategory.isEmpty
            ? (categories.contains('Other') ? 'Other' : categories.first)
            : rawCategory,
        type: type,
        date: date,
        walletId: walletId,
        notes: _cell(row, indexes, 'notes').trim(),
        paymentMethod: _cell(row, indexes, 'paymentmethod').trim(),
        transferWalletId: transferWalletId.isEmpty ? null : transferWalletId,
      ),
    );
  }

  return CsvImportResult(drafts: drafts, skippedRows: skippedRows);
}

String _cell(List<String> row, Map<String, int> indexes, String key) {
  final index = indexes[key] ?? -1;
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index];
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(trimmed);
  if (iso != null) {
    return iso;
  }

  final parts = trimmed.split('/');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

List<List<String>> _parseRows(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      final nextIsQuote = i + 1 < input.length && input[i + 1] == '"';
      if (inQuotes && nextIsQuote) {
        cell.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      row.add(cell.toString());
      cell.clear();
      continue;
    }

    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
        i++;
      }
      row.add(cell.toString());
      cell.clear();
      if (row.any((value) => value.trim().isNotEmpty)) {
        rows.add(row);
      }
      row = <String>[];
      continue;
    }

    cell.write(char);
  }

  row.add(cell.toString());
  if (row.any((value) => value.trim().isNotEmpty)) {
    rows.add(row);
  }
  return rows;
}

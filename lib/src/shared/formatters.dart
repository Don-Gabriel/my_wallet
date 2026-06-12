class MoneyPrivacy {
  static bool hideAmounts = false;
}

String formatMoney(double value, {bool signed = false}) {
  if (MoneyPrivacy.hideAmounts) {
    final prefix = value < 0
        ? '-'
        : signed && value > 0
        ? '+'
        : '';
    return '${prefix}INR ••••';
  }
  final prefix = value < 0
      ? '-'
      : signed && value > 0
      ? '+'
      : '';
  return '${prefix}INR ${formatNumberWithCommas(value.abs())}';
}

String formatNumberWithCommas(
  num value, {
  int fractionDigits = 2,
  bool trimTrailingZeros = false,
}) {
  if (!value.isFinite) {
    return '0';
  }

  final sign = value < 0 ? '-' : '';
  var text = value.abs().toStringAsFixed(fractionDigits);
  if (trimTrailingZeros && text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return '$sign${formatNumericTextWithCommas(text)}';
}

String formatCalculatorExpression(String expression) {
  final buffer = StringBuffer();
  final token = StringBuffer();

  void flushToken() {
    if (token.isEmpty) {
      return;
    }
    buffer.write(formatNumericTextWithCommas(token.toString()));
    token.clear();
  }

  for (final char in expression.split('')) {
    if ('+-*/'.contains(char)) {
      flushToken();
      buffer.write(' ${char == '*' ? 'x' : char} ');
    } else {
      token.write(char);
    }
  }
  flushToken();

  final formatted = buffer.toString().trim();
  return formatted.isEmpty ? '0' : formatted;
}

String formatNumericTextWithCommas(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '0';
  }

  final sign = trimmed.startsWith('-') ? '-' : '';
  final unsigned = trimmed.replaceFirst(RegExp(r'^[+-]'), '');
  final parts = unsigned.split('.');
  final integer = parts.first.isEmpty ? '0' : parts.first;
  final groupedInteger = _groupIndianDigits(
    integer.replaceFirst(RegExp(r'^0+(?=\d)'), ''),
  );

  if (parts.length == 1) {
    return '$sign$groupedInteger';
  }

  return '$sign$groupedInteger.${parts.sublist(1).join('.')}';
}

String _groupIndianDigits(String digits) {
  if (digits.length <= 3) {
    return digits;
  }

  final lastThree = digits.substring(digits.length - 3);
  var leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (leading.length > 2) {
    groups.insert(0, leading.substring(leading.length - 2));
    leading = leading.substring(0, leading.length - 2);
  }
  if (leading.isNotEmpty) {
    groups.insert(0, leading);
  }
  return '${groups.join(',')},$lastThree';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

bool isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

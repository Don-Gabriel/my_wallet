import 'package:flutter_test/flutter_test.dart';
import 'package:mywallet/src/shared/formatters.dart';

void main() {
  test('formats money with Indian comma grouping', () {
    expect(formatMoney(1000), 'INR 1,000.00');
    expect(formatMoney(100000), 'INR 1,00,000.00');
    expect(formatMoney(-1234567.89, signed: true), '-INR 12,34,567.89');
  });

  test('formats calculator expressions without changing operators', () {
    expect(formatCalculatorExpression('1000'), '1,000');
    expect(formatCalculatorExpression('100000+2500'), '1,00,000 + 2,500');
    expect(formatNumberWithCommas(1200.5, trimTrailingZeros: true), '1,200.5');
  });
}

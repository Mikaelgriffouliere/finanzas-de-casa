import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/amount_parser.dart';

void main() {
  group('parseAmount', () {
    test('interpreta importes simples', () {
      expect(parseAmount('1500'), 1500);
      expect(parseAmount('1250.5'), 1250.5);
      expect(parseAmount('12,5'), 12.5);
      expect(parseAmount('0'), 0);
    });

    test('interpreta separadores de miles argentinos', () {
      expect(parseAmount('1.500'), 1500);
      expect(parseAmount('1.500,50'), 1500.5);
      expect(parseAmount('12.345.678,90'), 12345678.9);
      expect(parseAmount(r'$ 2.000'), 2000);
    });

    test('interpreta el formato internacional', () {
      expect(parseAmount('1,500.50'), 1500.5);
      expect(parseAmount('1,234,567.89'), 1234567.89);
    });

    test('redondea a dos decimales', () {
      expect(parseAmount('10,999'), 11);
      expect(parseAmount('0,005'), 0.01);
    });

    test('rechaza textos inválidos', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('1.2.3'), isNull);
      expect(parseAmount('12,'), isNull);
      expect(parseAmount('.'), isNull);
    });
  });
}

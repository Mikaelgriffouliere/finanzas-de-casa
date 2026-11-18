/// Convierte un importe escrito por el usuario a [double].
///
/// Acepta el formato local argentino (`1.500,50`) y también el formato
/// internacional (`1,500.50` o `1500.50`). Devuelve `null` si el texto no
/// representa un número válido.
double? parseAmount(String input) {
  var text = input
      .trim()
      .replaceAll(RegExp(r'[\s\u00A0]'), '')
      .replaceAll(r'$', '');
  if (text.isEmpty) return null;

  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');
  String? decimalSeparator;

  if (lastComma >= 0 && lastDot >= 0) {
    decimalSeparator = lastComma > lastDot ? ',' : '.';
  } else if (lastComma >= 0) {
    final commaCount = ','.allMatches(text).length;
    if (commaCount > 1) {
      // Varios separadores solo son válidos como separadores de miles.
      final groups = text.split(',');
      final validThousands =
          groups.first.isNotEmpty &&
          groups.skip(1).every((group) => group.length == 3);
      if (!validThousands) return null;
      decimalSeparator = null;
    } else {
      decimalSeparator = ',';
    }
  } else if (lastDot >= 0) {
    final digitsAfterDot = text.length - lastDot - 1;
    final integerPart = text.substring(0, lastDot);
    final dotCount = '.'.allMatches(text).length;

    if (dotCount > 1) {
      final groups = text.split('.');
      final validThousands =
          groups.first.isNotEmpty &&
          groups.skip(1).every((group) => group.length == 3);
      if (!validThousands) return null;
      decimalSeparator = null;
    } else {
      final looksLikeThousands =
          digitsAfterDot == 3 && integerPart.isNotEmpty && integerPart != '0';
      decimalSeparator = looksLikeThousands ? null : '.';
    }
  }

  String normalized;
  if (decimalSeparator == null) {
    normalized = text.replaceAll(RegExp(r'[.,]'), '');
  } else {
    final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
    normalized = text.replaceAll(thousandsSeparator, '');
    final index = normalized.lastIndexOf(decimalSeparator);
    normalized =
        '${normalized.substring(0, index).replaceAll(decimalSeparator, '')}.'
        '${normalized.substring(index + 1)}';
  }

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;

  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite) return null;

  // Se guardan como máximo dos decimales (centavos).
  return (value * 100).roundToDouble() / 100;
}

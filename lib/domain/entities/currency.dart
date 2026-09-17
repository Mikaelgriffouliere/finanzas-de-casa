enum Currency {
  ars('ARS', '\$'),
  usd('USD', 'US\$'),
  eur('EUR', '€'),
  brl('BRL', 'R\$'),
  clp('CLP', '\$'),
  mxn('MXN', 'MX\$');

  final String code;
  final String symbol;

  const Currency(this.code, this.symbol);

  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => Currency.ars,
    );
  }

  String get label => code;
}

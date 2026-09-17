import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../utils/formatters.dart';

/// Secciones que se pueden incluir en el informe PDF.
enum PdfReportSection {
  summary,
  incomeByCategory,
  expenseByCategory,
  incomeByPerson,
  expenseByPerson,
  expenseByAccount,
  movements,
}

/// Fila de un movimiento dentro del informe PDF.
class PdfMovementRow {
  final DateTime date;
  final String typeLabel;
  final String description;
  final String category;
  final String subcategory;
  final String person;
  final String account;
  final int signedCents;

  const PdfMovementRow({
    required this.date,
    required this.typeLabel,
    required this.description,
    required this.category,
    required this.subcategory,
    required this.person,
    required this.account,
    required this.signedCents,
  });
}

/// Genera y guarda un informe PDF del período indicado.
///
/// Todo el contenido fluye de forma continua (resumen, desgloses y
/// movimientos) en pocas páginas, en lugar de una página por sección.
class PdfReportService {
  static const _primary = PdfColor.fromInt(0xFF33416F);
  static const _primarySoft = PdfColor.fromInt(0xFFEAEEF6);
  static const _accent = PdfColor.fromInt(0xFF1B8AA0);
  static const _accentSoft = PdfColor.fromInt(0xFFE3F2F6);
  static const _income = PdfColor.fromInt(0xFF13826C);
  static const _incomeSoft = PdfColor.fromInt(0xFFE0F1ED);
  static const _expense = PdfColor.fromInt(0xFFB85563);
  static const _expenseSoft = PdfColor.fromInt(0xFFF7E8EA);
  static const _lightGray = PdfColor.fromInt(0xFFF2F4F8);
  static const _darkGray = PdfColor.fromInt(0xFF6B7280);

  PdfReportService();

  Future<File> generateReport({
    required String appName,
    required String periodTitle,
    required DateTime from,
    required DateTime to,
    required int totalIncome,
    required int totalExpense,
    required Map<String, int> incomeByCategory,
    required Map<String, int> expenseByCategory,
    required Map<String, int> incomeByPerson,
    required Map<String, int> expenseByPerson,
    required Map<String, int> expenseByAccount,
    required List<PdfMovementRow> movements,
    Set<PdfReportSection> sections = const {
      PdfReportSection.summary,
      PdfReportSection.incomeByCategory,
      PdfReportSection.expenseByCategory,
      PdfReportSection.incomeByPerson,
      PdfReportSection.expenseByPerson,
      PdfReportSection.expenseByAccount,
      PdfReportSection.movements,
    },
    Directory? outputDirectory,
  }) async {
    final doc = pw.Document();

    final content = <pw.Widget>[
      _titleBanner(appName, periodTitle, from, to),
      pw.SizedBox(height: 18),
    ];

    if (sections.contains(PdfReportSection.summary)) {
      content.add(_summarySection(totalIncome, totalExpense));
      content.add(pw.SizedBox(height: 16));
    }

    if (sections.contains(PdfReportSection.incomeByCategory)) {
      _addAmountBlock(
        content,
        'Ingresos por categoría',
        _sortedRows(incomeByCategory),
      );
    }
    if (sections.contains(PdfReportSection.expenseByCategory)) {
      _addAmountBlock(
        content,
        'Gastos por categoría',
        _sortedRows(expenseByCategory),
      );
    }
    if (sections.contains(PdfReportSection.incomeByPerson)) {
      _addAmountBlock(
        content,
        'Ingresos por persona',
        _sortedRows(incomeByPerson),
      );
    }
    if (sections.contains(PdfReportSection.expenseByPerson)) {
      _addAmountBlock(
        content,
        'Gastos por persona',
        _sortedRows(expenseByPerson),
      );
    }
    if (sections.contains(PdfReportSection.expenseByAccount)) {
      _addAmountBlock(
        content,
        'Gastos por cuenta',
        _sortedRows(expenseByAccount),
      );
    }
    if (sections.contains(PdfReportSection.movements) && movements.isNotEmpty) {
      content
        ..add(_sectionTitle('Movimientos del período'))
        ..add(pw.SizedBox(height: 6))
        ..add(_movementsTable(movements))
        ..add(pw.SizedBox(height: 16));
    }

    content.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _lightGray,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'Informe generado por la aplicación. Todos los datos se '
          'almacenan de forma local en tu dispositivo.',
          style: pw.TextStyle(fontSize: 9, color: _darkGray),
        ),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        header: (context) => _topBar(appName),
        footer: (context) => pw.SizedBox(
          width: double.infinity,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Text(
              'Generado el ${DateUtils.shortDateTime(DateTime.now())} '
              '· $appName',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: _darkGray,
                fontSize: 8,
              ),
            ),
          ),
        ),
        build: (context) => content,
      ),
    );

    final dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    final stamp = _timestamp();
    final file = File('${dir.path}/${_slug(appName)}_informe_$stamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _topBar(String appName) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: pw.BoxDecoration(color: _primary),
      child: pw.Row(
        children: [
          pw.Text(
            appName,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Reporte financiero',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _titleBanner(
      String appName, String periodTitle, DateTime from, DateTime to) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: pw.BoxDecoration(
        color: _primarySoft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            periodTitle,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Período: ${DateUtils.shortDate(from)} - '
            '${DateUtils.shortDate(to)}',
            style: pw.TextStyle(
              fontSize: 10,
              color: _darkGray,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _summarySection(int totalIncome, int totalExpense) {
    final balance = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0
        ? ((balance / totalIncome).clamp(0.0, 1.0) * 100).toStringAsFixed(0)
        : '0';

    return pw.Column(
      children: [
        _sectionTitle('Resumen del período'),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            _summaryBox('Ingresos', totalIncome, _income),
            pw.SizedBox(width: 12),
            _summaryBox('Gastos', totalExpense, _expense),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _summaryBox('Balance', balance, _primary),
            pw.SizedBox(width: 12),
            _summaryBox('Tasa de ahorro', '$savingsRate%', _accent),
          ],
        ),
      ],
    );
  }

  void _addAmountBlock(List<pw.Widget> content, String title, List<_Row> rows) {
    if (rows.isEmpty) return;
    content
      ..add(_sectionTitle(title))
      ..add(pw.SizedBox(height: 6))
      ..add(_amountTable(rows))
      ..add(pw.SizedBox(height: 16));
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _primary,
        ),
      ),
    );
  }

  pw.Widget _summaryBox(String label, Object value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _soft(color),
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: color),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value is int ? MoneyUtils.format(value) : value as String,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PdfColor _soft(PdfColor color) {
    if (color == _primary) return _primarySoft;
    if (color == _income) return _incomeSoft;
    if (color == _expense) return _expenseSoft;
    return _accentSoft;
  }

  pw.Widget _amountTable(List<_Row> rows) {
    final total = rows.fold<int>(0, (s, r) => s + r.amount);

    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Detalle', 'Total', '%'],
      data: [
        for (var i = 0; i < rows.length; i++)
          [
            i + 1,
            rows[i].name,
            MoneyUtils.format(rows[i].amount),
            _percent(rows[i].amount, total),
          ],
      ],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(color: _primary),
      cellStyle: pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: pw.BoxDecoration(color: _lightGray),
      cellAlignments: const {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        3: pw.FlexColumnWidth(0.9),
      },
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  pw.Widget _movementsTable(List<PdfMovementRow> movements) {
    final rows = <List<Object>>[];
    for (final m in movements) {
      rows.add([
        DateUtils.shortDate(m.date),
        m.typeLabel,
        m.description.isEmpty
            ? (m.category.isNotEmpty ? m.category : 'Movimiento')
            : m.description,
        _extraLabel(m.category, m.subcategory),
        _extraLabel(m.person, m.account),
        MoneyUtils.format(m.signedCents),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Fecha',
        'Tipo',
        'Descripción',
        'Categoría/Subcategoría',
        'Persona/Cuenta',
        'Monto',
      ],
      data: rows,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: pw.BoxDecoration(color: _primary),
      cellStyle: pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      oddRowDecoration: pw.BoxDecoration(color: _lightGray),
      cellAlignments: const {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(0.9),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.3),
      },
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    );
  }

  String _extraLabel(String a, String b) {
    if (a.isEmpty && b.isEmpty) return '-';
    if (a.isNotEmpty && b.isNotEmpty) return '$a / $b';
    return a.isNotEmpty ? a : b;
  }

  String _percent(int amount, int total) {
    if (total == 0) return '0%';
    return '${(amount * 100 / total).round()}%';
  }

  List<_Row> _sortedRows(Map<String, int> map) {
    final rows = map.entries.map((e) => _Row(e.key, e.value)).toList();
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  pw.PageTheme _pageTheme() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28.35), // 1 cm en cada lado
    );
  }

  String _timestamp() {
    final n = DateTime.now();
    return '${n.year}${_two(n.month)}${_two(n.day)}_${_two(n.hour)}${_two(n.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _slug(String name) {
    final lower = name.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      buffer.write(_isValid(c) ? c : '_');
    }
    return buffer.toString();
  }

  bool _isValid(String c) =>
      (c.codeUnitAt(0) >= 97 && c.codeUnitAt(0) <= 122) ||
      (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57);
}

class _Row {
  final String name;
  final int amount;

  _Row(this.name, this.amount);
}
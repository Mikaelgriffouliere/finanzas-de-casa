import 'dart:io';

import 'package:finanzas_hogar/data/services/pdf_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PdfReportService', () {
    test('genera un PDF válido con datos de ejemplo', () async {
      final dir = Directory.systemTemp.createTempSync('pdf_test');

      final file = await PdfReportService().generateReport(
        appName: 'Finanzas en orden',
        periodTitle: 'Septiembre 2026',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30, 23, 59, 59),
        totalIncome: 100000,
        totalExpense: 40000,
        incomeByCategory: {'Sueldo': 100000},
        expenseByCategory: {'Servicios': 25000, 'Alimentos': 15000},
        incomeByPerson: {'Lucas': 100000},
        expenseByPerson: {'Admin': 40000},
        expenseByAccount: {'Lucas': 30000, 'Madre': 10000},
        movements: [
          PdfMovementRow(
            date: DateTime(2026, 9, 10),
            typeLabel: 'Gasto',
            description: 'Expensa',
            category: 'Servicios',
            subcategory: 'Expensas',
            person: 'Admin',
            account: 'Lucas',
            signedCents: -25000,
          ),
        ],
        outputDirectory: dir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.path, contains('finanzas_en_orden_informe_'));
      expect(file.lengthSync(), greaterThan(1000));

      final bytes = await file.readAsBytes();
      final header = String.fromCharCodes(bytes.take(8));
      expect(header, startsWith('%PDF'));

      dir.deleteSync(recursive: true);
    });

    test('no incluye secciones sin datos', () async {
      final dir = Directory.systemTemp.createTempSync('pdf_test_empty');

      final file = await PdfReportService().generateReport(
        appName: 'Finanzas en orden',
        periodTitle: 'Semana del 14/09/2026 al 20/09/2026',
        from: DateTime(2026, 9, 14),
        to: DateTime(2026, 9, 20, 23, 59, 59),
        totalIncome: 0,
        totalExpense: 0,
        incomeByCategory: const {},
        expenseByCategory: const {},
        incomeByPerson: const {},
        expenseByPerson: const {},
        expenseByAccount: const {},
        movements: const [],
        outputDirectory: dir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(200));

      dir.deleteSync(recursive: true);
    });

    test('respeta las secciones seleccionadas', () async {
      final dir = Directory.systemTemp.createTempSync('pdf_test_sections');

      final file = await PdfReportService().generateReport(
        appName: 'Finanzas en orden',
        periodTitle: 'Septiembre 2026',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30, 23, 59, 59),
        totalIncome: 100000,
        totalExpense: 40000,
        incomeByCategory: {'Sueldo': 100000},
        expenseByCategory: {'Servicios': 25000},
        incomeByPerson: {'Lucas': 100000},
        expenseByPerson: {'Admin': 40000},
        expenseByAccount: {'Lucas': 40000},
        movements: [
          PdfMovementRow(
            date: DateTime(2026, 9, 10),
            typeLabel: 'Gasto',
            description: 'Expensa',
            category: 'Servicios',
            subcategory: 'Expensas',
            person: 'Admin',
            account: 'Lucas',
            signedCents: -25000,
          ),
        ],
        sections: const {
          PdfReportSection.summary,
          PdfReportSection.movements,
        },
        outputDirectory: dir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(500));

      final bytes = await file.readAsBytes();
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF'));

      dir.deleteSync(recursive: true);
    });
  });
}
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../common/glass_card.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;

  Future<void> _exportJson() async {
    setState(() => _exporting = true);
    try {
      final db = await AppDatabase.instance.getDatabase();
      final data = await _readAllTables(db);
      final json = const JsonEncoder.withIndent('  ').convert(data);

      final docs = await getApplicationDocumentsDirectory();
      final stamp = _timestamp();
      final file = File('${docs.path}/finanzas_hogar_backup_$stamp.json');
      await file.writeAsString(json);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup creado: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar JSON: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final db = await AppDatabase.instance.getDatabase();
      final rows = await db.query(
        TableNames.transactions,
        orderBy: 'date DESC',
      );

      final buffer = StringBuffer()
        ..writeln(
          'id;fecha;tipo;monto_centavos;categoria;subcategoria;persona;cuenta;descripcion;notas;recurrente',
        );
      for (final r in rows) {
        final category = await _nameOf(
          db,
          TableNames.categories,
          r['category_id'] as int?,
        );
        final person = await _nameOf(
          db,
          TableNames.persons,
          r['person_id'] as int?,
        );
        final account = await _nameOf(
          db,
          TableNames.accounts,
          r['account_id'] as int?,
        );
        final date = DateTime.fromMillisecondsSinceEpoch(r['date'] as int);
        buffer.writeln(
          [
            r['id'],
            date.toIso8601String(),
            r['type'],
            r['amount'],
            category,
            r['subcategory_id'] ?? '',
            person,
            account,
            _escapeCsv((r['description'] ?? '') as String),
            _escapeCsv((r['notes'] ?? '') as String),
            r['is_recurring'] ?? 0,
          ].join(';'),
        );
      }

      final docs = await getApplicationDocumentsDirectory();
      final stamp = _timestamp();
      final file = File('${docs.path}/finanzas_hogar_movimientos_$stamp.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV creado: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar CSV: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<String> _nameOf(Database db, String table, int? id) async {
    if (id == null) return '';
    final rows = await db.query(
      table,
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return '';
    return rows.first['name'] as String;
  }

  String _escapeCsv(String value) {
    if (value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<Map<String, dynamic>> _readAllTables(Database db) async {
    return {
      'app': AppConstants.appName,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'persons': await db.query(TableNames.persons),
      'accounts': await db.query(TableNames.accounts),
      'categories': await db.query(TableNames.categories),
      'subcategories': await db.query(TableNames.subcategories),
      'transactions': await db.query(TableNames.transactions),
      'recurring_transactions': await db.query(
        TableNames.recurringTransactions,
      ),
      'budgets': await db.query(TableNames.budgets),
      'savings_goals': await db.query(TableNames.savingsGoals),
      'savings_movements': await db.query(TableNames.savingsMovements),
      'settings': await db.query(TableNames.settings),
    };
  }

  String _timestamp() {
    final n = DateTime.now();
    return '${n.year}${_two(n.month)}${_two(n.day)}_${_two(n.hour)}${_two(n.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup y exportación')),
      body: _exporting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SectionTitle(title: 'Exportar'),
                GlassCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.data_object),
                        title: const Text('Exportar JSON'),
                        subtitle: const Text(
                          'Backup completo de todos los datos',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportJson,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.table_chart),
                        title: const Text('Exportar CSV'),
                        subtitle: const Text(
                          'Todos los movimientos en formato CSV',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportCsv,
                      ),
                    ],
                  ),
                ),
                _SectionTitle(title: 'Restaurar'),
                GlassCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.file_download_outlined),
                        title: Text('Importar JSON'),
                        subtitle: Text('Próximamente'),
                        trailing: Icon(Icons.lock_clock),
                      ),
                      const Divider(),
                      const ListTile(
                        leading: Icon(Icons.restore),
                        title: Text('Restaurar backup'),
                        subtitle: Text('Próximamente'),
                        trailing: Icon(Icons.lock_clock),
                      ),
                    ],
                  ),
                ),
                _SectionTitle(title: 'Privacidad'),
                GlassCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Todos tus datos financieros se almacenan de forma local en tu dispositivo. No se envían a ningún servidor ni servicio cloud.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Los archivos exportados se guardan en la carpeta de documentos\nde la aplicación.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

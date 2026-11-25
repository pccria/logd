import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_schema.dart';

/// Analytical SQL query generator bridging TOON streams with DuckDB.
///
/// Produces zero-copy DuckDB SQL queries utilizing `read_csv` to inspect or ingest
/// `.toon` files directly at high throughput without intermediate format conversion.
@immutable
final class ToonDuckDb {
  /// Const constructor for [ToonDuckDb].
  const ToonDuckDb();

  /// Generates a DuckDB `SELECT` statement querying a `.toon` file directly.
  ///
  /// Configures `read_csv` with the schema's exact delimiter, column names,
  /// skipped preamble line counts, and null string representations.
  static String selectQuery(
    final ToonSchema schema, {
    required final String filePath,
    final String? whereClause,
    final int? limit,
  }) {
    final buffer = StringBuffer()
      ..write('SELECT * FROM read_csv(\n')
      ..write("  '$filePath',\n")
      ..write(
        '  delim = ${schema.delimiter == '\t' ? r"'\t'" : "'${schema.delimiter}'"},\n',
      )
      ..write('  header = false,\n')
      ..write('  skip = ${_calculateSkipLines(schema)},\n');

    if (schema.dialect == ToonDialect.strict) {
      buffer.write("  nullstr = '\\N',\n");
    }

    final columnNames = schema.columns.map((final c) => "'$c'").join(', ');
    buffer.write('  names = [$columnNames]\n)');

    if (whereClause != null && whereClause.trim().isNotEmpty) {
      buffer.write(' WHERE ${whereClause.trim()}');
    }

    if (limit != null && limit > 0) {
      buffer.write(' LIMIT $limit');
    }

    buffer.write(';');
    return buffer.toString();
  }

  /// Generates a DuckDB DDL `CREATE TABLE` statement mapped from [schema].
  ///
  /// Maps semantic column types ([ToonType.iso8601] → `TIMESTAMP`,
  /// [ToonType.object] → `JSON`, others → `VARCHAR`).
  static String createTableSql(
    final ToonSchema schema, {
    final String? tableName,
    final bool ifNotExists = true,
  }) {
    final name = tableName ?? schema.arrayName;
    final buffer = StringBuffer('CREATE TABLE ');

    if (ifNotExists) {
      buffer.write('IF NOT EXISTS ');
    }

    buffer.write('$name (\n');

    for (var i = 0; i < schema.columns.length; i++) {
      final col = schema.columns[i];
      final type = schema.columnTypes[col];
      final sqlType = _mapToDuckDbType(type);
      final comma = i < schema.columns.length - 1 ? ',' : '';
      buffer.write('  $col $sqlType$comma\n');
    }

    buffer.write(');');
    return buffer.toString();
  }

  /// Generates an `INSERT INTO ... SELECT * FROM read_csv(...)` ingestion statement.
  static String ingestSql(
    final ToonSchema schema, {
    required final String filePath,
    final String? tableName,
  }) {
    final targetTable = tableName ?? schema.arrayName;
    final select = selectQuery(schema, filePath: filePath);
    return 'INSERT INTO $targetTable $select';
  }

  static int _calculateSkipLines(final ToonSchema schema) {
    var lines = 0;
    if (schema.dialect == ToonDialect.strict) {
      lines += 2; // -- TOON/1.0 and -- DELIMITER:...
    }
    if (schema.columnTypes.isNotEmpty) {
      lines += schema.columns.length + 2; // name[]{\n ... \n}:
    } else {
      lines += 1; // name[]{...}:
    }
    return lines;
  }

  static String _mapToDuckDbType(final ToonType? type) {
    if (type == null) {
      return 'VARCHAR';
    }
    final name = type.name.toLowerCase();
    switch (name) {
      case 'iso8601':
        return 'TIMESTAMP';
      case 'object':
        return 'JSON';
      case 'int':
      case 'integer':
        return 'BIGINT';
      case 'double':
      case 'float':
      case 'num':
        return 'DOUBLE';
      case 'bool':
      case 'boolean':
        return 'BOOLEAN';
      default:
        return 'VARCHAR';
    }
  }
}

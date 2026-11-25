import 'package:logd/logd.dart';
import 'package:logd_toon/logd_toon.dart';
import 'package:test/test.dart';

void main() {
  group('ToonDuckDb SQL Generator Tests', () {
    const compactSchema = ToonSchema(
      arrayName: 'app_logs',
      columns: ['timestamp', 'logger', 'level', 'message', 'context'],
      delimiter: '\t',
      dialect: ToonDialect.compact,
    );

    const strictTypedSchema = ToonSchema(
      arrayName: 'audit_logs',
      columns: ['timestamp', 'level', 'message', 'error', 'context'],
      delimiter: '\t',
      dialect: ToonDialect.strict,
      columnTypes: {
        'timestamp': ToonType.iso8601,
        'level': ToonType('enum', 'INFO,ERROR'),
        'message': ToonType.markdown,
        'error': ToonType.string,
        'context': ToonType.object,
      },
    );

    test('generates SELECT read_csv query for compact schema', () {
      final sql = ToonDuckDb.selectQuery(
        compactSchema,
        filePath: 'logs/production.toon',
        whereClause: "level = 'ERROR'",
        limit: 100,
      );

      expect(sql, contains("read_csv(\n  'logs/production.toon'"));
      expect(sql, contains(r"delim = '\t'"));
      expect(sql, contains('header = false'));
      expect(sql, contains('skip = 1'));
      expect(
        sql,
        contains(
          "names = ['timestamp', 'logger', 'level', 'message', 'context']",
        ),
      );
      expect(sql, contains("WHERE level = 'ERROR'"));
      expect(sql, contains('LIMIT 100;'));
    });

    test(
      'generates SELECT read_csv query for strict typed schema with \\N nullstr',
      () {
        final sql = ToonDuckDb.selectQuery(
          strictTypedSchema,
          filePath: 'logs/audit.toon',
        );

        expect(sql, contains("read_csv(\n  'logs/audit.toon'"));
        expect(sql, contains(r"nullstr = '\N'"));
        // 2 comments + 5 columns + 2 bracket lines = 9 lines
        expect(sql, contains('skip = 9'));
      },
    );

    test('generates CREATE TABLE DDL mapped from schema types', () {
      final ddl = ToonDuckDb.createTableSql(
        strictTypedSchema,
        tableName: 'audit_events',
      );

      expect(ddl, contains('CREATE TABLE IF NOT EXISTS audit_events ('));
      expect(ddl, contains('timestamp TIMESTAMP,'));
      expect(ddl, contains('level VARCHAR,'));
      expect(ddl, contains('message VARCHAR,'));
      expect(ddl, contains('context JSON'));
      expect(ddl, endsWith(');'));
    });

    test('generates INGEST statement with target table', () {
      final ingest = ToonDuckDb.ingestSql(
        compactSchema,
        filePath: 'logs/import.toon',
        tableName: 'staging_logs',
      );

      expect(
        ingest,
        startsWith('INSERT INTO staging_logs SELECT * FROM read_csv('),
      );
      expect(ingest, contains("'logs/import.toon'"));
    });
  });
}

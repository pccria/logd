import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';

void main() async {
  // Always register serializers when using isolates or async handlers
  registerLogdSqliteSerializers();

  // Configure Logger with an async SQLite handler on a background isolate
  final handler = SqliteHandler.async(
    path: 'app_logs.db',
    tableName: 'app_telemetry',
    batchSize: 10,
    walMode: true,
  );

  Logger.configure('main', handlers: [handler]);

  Logger.get('main').info(
    'Application started successfully',
    context: const {'version': '1.0.0', 'environment': 'production'},
  );

  try {
    throw StateError('Database connection attempt timed out');
  } catch (e, stackTrace) {
    Logger.get(
      'main',
    ).error('Database connection failed', error: e, stackTrace: stackTrace);
  }

  // Dispose logger pipeline and handler
  await handler.dispose();
  print('SQLite logs written asynchronously to app_logs.db');
}

// Copyright (c) 2026, Pooria Askari Moqaddam. All rights reserved.
// Use of this source code is governed by a BSD-3-Clause license that can be
// found in the LICENSE file.

/// High-performance SQLite log sink satellite package for `logd`.
library;

import 'package:logd/logd.dart';

import 'src/sqlite_sink.dart';

export 'src/sqlite_handler.dart';
export 'src/sqlite_sink.dart';

/// Registers SQLite components into logd's [LoggerSerializationRegistry].
///
/// Call this during isolate setup or app bootstrapping when using isolates or
/// custom serialization pipelines:
/// ```dart
/// registerLogdSqliteSerializers();
/// ```
void registerLogdSqliteSerializers() {
  LoggerSerializationRegistry.ensureInitialized();

  LoggerSerializationRegistry.registerSink<SqliteSink>(
    type: 'SqliteSink',
    fromJson: (final json) => SqliteSink(
      dbPath: json['dbPath'] as String? ?? 'logs.db',
      tableName: json['tableName'] as String? ?? 'logs',
      maxEntries: json['maxEntries'] as int?,
      maxAge: json['maxAge'] != null
          ? Duration(milliseconds: json['maxAge'] as int)
          : null,
      batchSize: json['batchSize'] as int? ?? 50,
      flushInterval: json['flushInterval'] != null
          ? Duration(milliseconds: json['flushInterval'] as int)
          : const Duration(seconds: 2),
      walMode: json['walMode'] as bool? ?? true,
      maxBufferSize: json['maxBufferSize'] as int? ?? 10000,
    ),
    toJson: (final sink) => <String, dynamic>{
      'dbPath': sink.dbPath,
      'tableName': sink.tableName,
      'maxEntries': sink.maxEntries,
      'maxAge': sink.maxAge?.inMilliseconds,
      'batchSize': sink.batchSize,
      'flushInterval': sink.flushInterval?.inMilliseconds,
      'walMode': sink.walMode,
      'maxBufferSize': sink.maxBufferSize,
    },
  );
}

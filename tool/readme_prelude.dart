// ignore_for_file: depend_on_referenced_packages, camel_case_types
// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:io' as io_lib;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';
import 'package:sqlite3/sqlite3.dart';

export 'dart:isolate' show SendPort;

abstract class _AuthManager {
  Future<String> getFreshAccessToken();
}

// Commonly assumed variables in README snippets:
late Logger logger;
Object e = '';
StackTrace st = StackTrace.empty;
late Dio dio;
final ({int id}) user = (id: 1);
final ({String ip}) request = (ip: '127.0.0.1');
Uint8List bytes = Uint8List(0);
Database? get _dummyDb => null;
late Database existingDb;
late SqliteHandler sqliteHandler;
late _AuthManager authManager;
Map<String, dynamic> exportedJson = {};
late LogSink<Uint8List> worker;
late LogEntry entry;
late LogPipelineFactory factory;
late LogFormatter formatter;
late LogSink sink;

// Helper functions assumed in snippets:
Future<void> chargePaymentGateway() async {}
List<String> sliceLines(
  Uint8List b, {
  int? last,
  int? count,
}) =>
    [];
void performAction(Logger logger) {}

// Namespace for snippets that access io.stdout:
abstract final class io {
  static io_lib.Stdout get stdout => io_lib.stdout;
  static io_lib.IOSink get stderr => io_lib.stderr;
  static io_lib.Stdin get stdin => io_lib.stdin;
}


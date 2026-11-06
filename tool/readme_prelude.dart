// ignore_for_file: depend_on_referenced_packages, camel_case_types
// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:io' as io_lib;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_sqlite/logd_sqlite.dart';

export 'dart:isolate' show SendPort;

// Commonly assumed variables in README snippets:
late Logger logger;
Object e = '';
StackTrace st = StackTrace.empty;
late Dio dio;
dynamic user = (id: 1);
dynamic request = (ip: '127.0.0.1');
Uint8List bytes = Uint8List(0);
dynamic existingDb;
late SqliteHandler sqliteHandler;
dynamic authManager;
Map<String, dynamic> exportedJson = {};
dynamic worker;
late LogEntry entry;
late LogPipelineFactory factory;
late LogFormatter formatter;
late LogSink sink;

// Helper functions assumed in snippets:
Future<void> chargePaymentGateway() async {}
List<String> sliceLines(
  final Uint8List b, {
  final int? last,
  final int? count,
}) =>
    [];
void performAction(final Logger logger) {}

// Namespace for snippets that access io.stdout:
abstract final class io {
  static io_lib.Stdout get stdout => io_lib.stdout;
  static io_lib.IOSink get stderr => io_lib.stderr;
  static io_lib.Stdin get stdin => io_lib.stdin;
}

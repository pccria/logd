library;

import 'dart:async';
import 'dart:typed_data';

import '../../core/context/io/file_system.dart';
import '../../time/timestamp.dart';
import '../encoder/encoder.dart';
import '../sink/sink.dart';

abstract class FileRotation {
  /// Base constructor.
  FileRotation({
    this.compress = false,
    this.backupCount = 5,
  }) {
    if (backupCount < 0) {
      throw ArgumentError(
        'Invalid backupCount: $backupCount. Must be non-negative.',
      );
    }
  }

  /// Whether rotated files should be compressed.
  final bool compress;

  /// The maximum number of backup files to keep.
  final int backupCount;

  /// Determines if rotation is needed.
  Future<bool> needsRotation(final File currentFile, final Uint8List newData);

  /// Rotates the file at [basePath].
  Future<void> rotate(final String basePath);
}

/// Rotates log files based on file size. Stub fallback on unsupported
/// platforms.
class SizeRotation extends FileRotation {
  /// Creates a size-based rotation rule.
  SizeRotation({
    final String maxSize = '512 KB',
    super.compress,
    super.backupCount,
    this.filenameFormatter,
  }) : maxBytes = parseMaxSizeLiteral(maxSize);

  /// Maximum size of the log file in bytes before rotating.
  final int maxBytes;

  /// Custom function to format rotated file names.
  final String Function(
    String baseWithoutExt,
    String? ext,
    int? index,
  )? filenameFormatter;

  /// Parses a human-readable size string into bytes.
  ///
  /// Supported units: B, KB, MB, GB, TB.
  static int parseMaxSizeLiteral(final String maxSizeLiteral) {
    final s = maxSizeLiteral.toUpperCase().replaceAll(' ', '');
    final match = RegExp(r'^(\d+(\.\d+)?)(TB|GB|MB|KB|B)?$').firstMatch(s);
    if (match == null) {
      throw FormatException(
        'Invalid size: $s (e.g., "10 MB", "512 KB", "1 TB")',
      );
    }
    final num = double.parse(match.group(1)!);
    final unit = match.group(3) ?? 'B';
    final multipliers = {
      'B': 1,
      'KB': 1024,
      'MB': 1024 * 1024,
      'GB': 1024 * 1024 * 1024,
      'TB': 1024 * 1024 * 1024 * 1024,
    };
    return (num * (multipliers[unit] ?? 1)).toInt();
  }

  @override
  Future<bool> needsRotation(final File currentFile, final Uint8List newData) =>
      throw UnsupportedError(
        'SizeRotation is not supported on the Web because browsers lack '
        'direct file system access. SizeRotation is native-only.',
      );

  @override
  Future<void> rotate(final String basePath) => throw UnsupportedError(
        'SizeRotation is not supported on the Web because browsers lack '
        'direct file system access. SizeRotation is native-only.',
      );
}

/// Rotates log files based on time intervals. Stub fallback on unsupported
/// platforms.
class TimeRotation extends FileRotation {
  /// Creates a time-based rotation rule.
  TimeRotation({
    this.interval = const Duration(days: 7),
    final Timestamp? timestamp,
    this.filenameFormatter,
    super.compress,
    super.backupCount,
  })  : timestamp = timestamp ?? Timestamp(formatter: 'yyyy-MM-dd'),
        assert(!interval.isNegative, 'Invalid interval: must be non-negative');

  /// The time interval after which log files should rotate.
  final Duration interval;

  /// The timestamp formatter for rotated filename suffixes.
  final Timestamp timestamp;

  /// The last time rotation occurred.
  DateTime? lastRotation;

  /// Custom function to format rotated file names.
  final String Function(
    String baseWithoutExt,
    String? ext,
    DateTime rotationTime,
  )? filenameFormatter;

  @override
  Future<bool> needsRotation(final File currentFile, final Uint8List newData) =>
      throw UnsupportedError(
        'TimeRotation is not supported on the Web because browsers lack '
        'direct file system access. TimeRotation is native-only.',
      );

  @override
  Future<void> rotate(final String basePath) => throw UnsupportedError(
        'TimeRotation is not supported on the Web because browsers lack '
        'direct file system access. TimeRotation is native-only.',
      );
}

/// A fallback stub for [FileSink] on unsupported platforms (like Web).
///
/// Attempting to use this sink on the Web will output a warning or fail
/// since browser sandboxing prevents local file storage.
base class FileSink extends EncodingSink {
  /// Creates a [FileSink] stub.
  FileSink(
    this.basePath, {
    super.encoder = const AutoTextEncoder(),
    this.fileRotation,
    final int? lineLength,
    super.enabled = true,
  }) : super(
          preferredWidth: lineLength ?? 120,
          delegate: _dummyDelegate,
        ) {
    _validateBasePath(basePath);
  }

  /// Target path on the file system.
  final String basePath;

  /// Configured file rotation strategy.
  final FileRotation? fileRotation;

  @override
  Future<void> flush() async {}

  static void _validateBasePath(final String basePath) {
    if (basePath.isEmpty) {
      throw ArgumentError(
        'Invalid basePath: empty string. Examples: "app.log" or "some/dir/app.log".',
      );
    }
    if (basePath.endsWith('/') || basePath.endsWith(r'\')) {
      throw ArgumentError(
        'Invalid basePath: path to a directory. Must point to a filename.',
      );
    }
  }

  static FutureOr<void> _dummyDelegate(final Uint8List data) {
    throw UnsupportedError(
      'FileSink is not supported on the Web because browsers prevent direct '
      'local file system operations. Consider using ConsoleSink or HttpSink '
      'for logging under browser environments.',
    );
  }
}

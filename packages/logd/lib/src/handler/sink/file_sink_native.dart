library;

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import '../../core/context/context.dart';
import '../../core/context/io/file_system.dart';
import '../../logger/logger.dart';
import '../../time/timestamp.dart';
import '../encoder/encoder.dart';
import '../engine/engine.dart';
import '../sink/sink.dart';

/// Base interface for file rotation policies.
///
/// Subclasses define the criteria for when a log file should be rotated (e.g.,
/// based on size or time) and how the rotation is performed.
abstract class FileRotation {
  /// Creates a [FileRotation] policy.
  ///
  /// - [compress]: Whether to gzip compress rotated backup files.
  /// - [backupCount]: The number of backup files to keep.
  /// If 0, no backups are kept.
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

  /// Whether to gzip compress rotated files.
  final bool compress;

  /// Number of backup files to keep
  /// (deletes oldest if exceeded; 0 = no backups).
  final int backupCount;

  /// Determines if rotation is necessary before appending
  /// [newData] to [currentFile].
  Future<bool> needsRotation(final File currentFile, final Uint8List newData);

  /// Performs the rotation of the file at [basePath].
  ///
  /// This typically involves renaming the current file, optionally compressing
  /// it, and cleaning up old backups that exceed [backupCount].
  Future<void> rotate(final String basePath);
}

/// A [FileRotation] policy that rotates files when they exceed a maximum size.
///
/// Rotated files are indexed (e.g., `app.1.log`, `app.2.log`), where index 1
/// is always the most recent backup.
class SizeRotation extends FileRotation {
  /// Creates a [SizeRotation] policy.
  ///
  /// - [maxSize]: A human-readable string representing the maximum size (e.g.,
  ///   '10 MB', '512 KB').
  /// - [filenameFormatter]: An optional function to customize the rotated
  /// filename.
  SizeRotation({
    final String maxSize = '512 KB',
    super.compress,
    super.backupCount,
    this.filenameFormatter,
  }) : maxBytes = parseMaxSizeLiteral(maxSize);

  /// A custom function for formatting rotated filenames.
  ///
  /// Takes the base name without extension, the extension, and the
  /// backup index. Returns the relative filename.
  final String Function(
    String baseWithoutExt,
    String? ext,
    int? index,
  )? filenameFormatter;

  String _defaultNameFormatter(
    final String baseWithoutExt,
    final String? ext,
    final int? index,
  ) =>
      '$baseWithoutExt'
      '${index != null ? '.$index' : ''}'
      '${ext != null && ext.isNotEmpty ? ext : ''}';

  /// The maximum size in bytes after which rotation occurs.
  ///
  /// e.g. '10 MB', '512 KB', '1 TB'
  final int maxBytes;

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
  Future<bool> needsRotation(
    final File currentFile,
    final Uint8List newData,
  ) async {
    final currentLength =
        await currentFile.exists() ? await currentFile.length() : 0;
    return currentLength + newData.length > maxBytes;
  }

  @override
  Future<void> rotate(final String basePath) async {
    final file = Context.fileSystem.file(basePath);
    if (!await file.exists()) {
      return;
    }

    final pathSeparator = io.Platform.pathSeparator;
    final normalizedPath =
        basePath.replaceAll('\\', pathSeparator).replaceAll('/', pathSeparator);
    final lastSepIndex = normalizedPath.lastIndexOf(pathSeparator);
    final filenamePart = lastSepIndex != -1
        ? normalizedPath.substring(lastSepIndex + 1)
        : normalizedPath;
    final extIndex = filenamePart.lastIndexOf('.');
    final ext = extIndex != -1 && extIndex < filenamePart.length - 1
        ? filenamePart.substring(extIndex)
        : null;
    final baseWithoutExt =
        basePath.substring(0, basePath.length - (ext?.length ?? 0));

    final formatter = filenameFormatter ?? _defaultNameFormatter;

    if (backupCount > 0) {
      // Shift backups: .N -> .(N+1)
      final extension = compress ? '.gz' : '';
      for (int i = backupCount - 1; i >= 1; i--) {
        final oldPath = formatter(baseWithoutExt, ext, i) + extension;
        final newPath = formatter(baseWithoutExt, ext, i + 1) + extension;
        final oldFile = Context.fileSystem.file(oldPath);
        if (await oldFile.exists()) {
          await oldFile.rename(newPath);
        }
      }
      // Move current to .1
      final backupPath = formatter(baseWithoutExt, ext, 1);
      await file.rename(backupPath);
      if (compress) {
        final bytes = await Context.fileSystem.file(backupPath).readAsBytes();
        final gzBytes = io.GZipCodec().encode(bytes);
        await Context.fileSystem.file('$backupPath.gz').writeAsBytes(gzBytes);
        await Context.fileSystem.file(backupPath).delete();
      }
      // Cleanup excess
      final dir = file.parent;
      final entities = await dir.list().toList();
      final backupFiles = <File>[];
      final targetStem = filenamePart.substring(
        0,
        filenamePart.length - (ext?.length ?? 0),
      );
      for (final e in entities) {
        if (e is! File || e.path == basePath) {
          continue;
        }
        final name = e.path.split(pathSeparator).last;
        if (compress && !name.endsWith('.gz')) {
          continue;
        }
        if (!compress && name.endsWith('.gz')) {
          continue;
        }
        final n = compress ? name.substring(0, name.length - 3) : name;
        if (!n.startsWith('$targetStem.')) {
          continue;
        }
        final extPart = ext ?? '';
        if (extPart.isNotEmpty && !n.endsWith(extPart)) {
          continue;
        }
        final indexPart = n.substring(
          targetStem.length + 1,
          n.length - extPart.length,
        );
        if (int.tryParse(indexPart) != null) {
          backupFiles.add(e);
        }
      }
      backupFiles.sort(
        (final a, final b) =>
            a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      ); // Oldest first
      while (backupFiles.length > backupCount) {
        await backupFiles.removeAt(0).delete();
      }
    } else {
      await file.delete();
    }
  }
}

/// A [FileRotation] policy that rotates files based on a time interval.
///
/// Rotated files are suffixed with a timestamp (e.g., `app-2025-01-01.log`).
class TimeRotation extends FileRotation {
  /// Creates a [TimeRotation] policy.
  ///
  /// - [interval]: The duration after which rotation occurs
  /// (e.g., daily, weekly).
  /// - [timestamp]: A [Timestamp] instance used to format the suffix.
  TimeRotation({
    this.interval = const Duration(days: 7),
    final Timestamp? timestamp,
    this.filenameFormatter,
    super.compress,
    super.backupCount,
  })  : timestamp = timestamp ?? Timestamp(formatter: 'yyyy-MM-dd'),
        assert(!interval.isNegative, 'Invalid interval: must be non-negative');

  /// A custom function for formatting rotated filenames.
  ///
  /// Takes the base name without extension, the extension,
  /// and the rotation time.
  final String Function(
    String baseWithoutExt,
    String? ext,
    DateTime rotationTime,
  )? filenameFormatter;

  String _defaultNameFormatter(
    final String baseWithoutExt,
    final String? ext,
    final DateTime rotationTime,
  ) {
    final ts = timestamp.formatter.format(rotationTime) ??
        rotationTime.toIso8601String().split('T')[0];
    return '$baseWithoutExt-$ts${ext != null && ext.isNotEmpty ? ext : ''}';
  }

  /// The duration between rotations.
  ///
  /// Must be non-negative.
  /// e.g. `Duration(days: 7)`
  final Duration interval;

  /// The timestamp formatter for rotated filename suffixes.
  final Timestamp timestamp;

  /// The last time rotation occurred
  /// (calculated from the file's last modified time if null).
  DateTime? lastRotation;

  @override
  Future<bool> needsRotation(
    final File currentFile,
    final Uint8List newData,
  ) async {
    await initLastRotation(currentFile);
    final now = Context.clock.now;
    return now.difference(lastRotation!) >= interval;
  }

  @override
  Future<void> rotate(final String basePath) async {
    final file = Context.fileSystem.file(basePath);
    if (!await file.exists()) {
      return;
    }

    final pathSeparator = io.Platform.pathSeparator;
    final normalizedPath =
        basePath.replaceAll('\\', pathSeparator).replaceAll('/', pathSeparator);
    final lastSepIndex = normalizedPath.lastIndexOf(pathSeparator);
    final filenamePart = lastSepIndex != -1
        ? normalizedPath.substring(lastSepIndex + 1)
        : normalizedPath;
    final extIndex = filenamePart.lastIndexOf('.');
    final ext = extIndex != -1 && extIndex < filenamePart.length - 1
        ? filenamePart.substring(extIndex)
        : null;
    final baseWithoutExt =
        basePath.substring(0, basePath.length - (ext?.length ?? 0));

    final rotationTime = lastRotation!;
    final formatter = filenameFormatter ?? _defaultNameFormatter;
    final rotatedPath = formatter(baseWithoutExt, ext, rotationTime);
    await file.rename(rotatedPath);
    if (compress) {
      final bytes = await Context.fileSystem.file(rotatedPath).readAsBytes();
      final gzBytes = io.GZipCodec().encode(bytes);
      await Context.fileSystem.file('$rotatedPath.gz').writeAsBytes(gzBytes);
      await Context.fileSystem.file(rotatedPath).delete();
    }
    lastRotation = Context.clock.now;
    if (backupCount > 0) {
      // Cleanup: Find rotated files, sort by mod time, delete oldest
      final dir = file.parent;
      final entities = await dir.list().toList();
      final targetStem = filenamePart.substring(
        0,
        filenamePart.length - (ext?.length ?? 0),
      );
      final logFiles = entities
          .where(
            (final e) {
              if (e is! File || e.path == basePath) {
                return false;
              }
              final name = e.path.split(pathSeparator).last;
              if (compress && !name.endsWith('.gz')) {
                return false;
              }
              if (!compress && name.endsWith('.gz')) {
                return false;
              }
              final n = compress ? name.substring(0, name.length - 3) : name;
              if (!n.startsWith('$targetStem-')) {
                return false;
              }
              final extPart = ext ?? '';
              if (extPart.isNotEmpty && !n.endsWith(extPart)) {
                return false;
              }
              final middle = n.substring(
                targetStem.length + 1,
                n.length - extPart.length,
              );
              return middle.isNotEmpty;
            },
          )
          .cast<File>()
          .toList()
        ..sort(
          (final a, final b) =>
              a.lastModifiedSync().compareTo(b.lastModifiedSync()),
        ); // Oldest first
      while (logFiles.length > backupCount) {
        await logFiles.removeAt(0).delete();
      }
    }
  }

  /// Initializes [lastRotation] from the file's metadata or current time.
  Future<void> initLastRotation(final File currentFile) async {
    if (lastRotation != null) {
      return;
    }
    if (await currentFile.exists()) {
      lastRotation = await currentFile.lastModified();
    } else {
      lastRotation = Context.clock.now;
    }
  }
}

/// A [LogSink] that encodes and appends logs to a local file.
///
/// It supports various file rotation policies (size-based, time-based) and
/// optional GZip compression of rotated backups. Parent directories are
/// automatically created if they do not exist.
///
/// This sink uses internal synchronization to ensure that concurrent write
/// operations are serialized, preventing data loss when logging operations
/// happen rapidly (e.g., in a loop).
base class FileSink extends EncodingSink {
  /// Creates a [FileSink] at the specified [basePath].
  ///
  /// - [basePath]: The relative or absolute path to the log file. Must point
  ///   to a filename, not a directory.
  /// - [encoder]: The encoder used to serialize logs into raw bytes
  /// (default: [PlainTextEncoder]).
  /// - [fileRotation]: An optional policy for rotating the log file.
  /// - [lineLength]: The maximum line length for the output (default: 120).
  /// - [enabled]: Whether the sink is currently active.
  FileSink(
    this.basePath, {
    super.encoder = const AutoTextEncoder(),
    this.fileRotation,
    final int? lineLength,
    super.enabled = true,
  }) : super(
          preferredWidth: lineLength ?? 120,
          delegate: (final data) async => _staticWrite(
            basePath,
            data,
            fileRotation,
            encoder: encoder,
            strategy: encoder.wrappingStrategy,
            getPreamble: () => _activeSinks[basePath]?.rememberedPreamble,
          ),
        ) {
    _validateBasePath(basePath);
    if (encoder.wrappingStrategy == WrappingStrategy.document) {
      final existing = _activeSinks[basePath];
      if (existing != null &&
          existing.encoder.wrappingStrategy == WrappingStrategy.document) {
        InternalLogger.log(
          LogLevel.warning,
          'Multiple active FileSinks with document-wrapping encoders created '
          'for the same path "$basePath". Rotating or concurrent writes may '
          'corrupt document boundaries.',
        );
      }
    }
    _activeSinks[basePath] = this;
  }

  /// The path to the active log file (e.g., 'logs/app.log').
  final String basePath;

  /// The rotation policy applied to this sink (null for no rotation).
  final FileRotation? fileRotation;

  static final Map<String, FileSink> _activeSinks = {};

  @override
  Future<void> flush() async {
    final lock = _locks[basePath];
    if (lock != null) {
      await lock;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await flush();
      await super.dispose();
    } finally {
      if (identical(_activeSinks[basePath], this)) {
        _activeSinks.remove(basePath);
      }
    }
  }

  static void _validateBasePath(final String basePath) {
    if (basePath.isEmpty) {
      throw ArgumentError('Invalid basePath: empty string. '
          'Examples: "app.log" or "some/dir/app.log".');
    }

    final pathSeparator = io.Platform.pathSeparator;

    final normalizedPath =
        basePath.replaceAll('\\', pathSeparator).replaceAll('/', pathSeparator);

    if (normalizedPath.endsWith(pathSeparator)) {
      throw ArgumentError('Invalid basePath: path to a directory. '
          'Must point to a filename (not empty or end in path separator). '
          'Examples: "app.log" or "some/dir/app.log".');
    }
  }

  /// Map of active write locks per file path to serialize concurrent writes.
  static final Map<String, Future<void>> _locks = {};

  /// Performs the actual file write operation with rotation and locking.
  static Future<void> _staticWrite(
    final String basePath,
    final Uint8List data,
    final FileRotation? fileRotation, {
    final LogEncoder? encoder,
    final WrappingStrategy? strategy,
    final Uint8List? Function()? getPreamble,
  }) async {
    final lock = _locks[basePath];
    final completer = Completer<void>();
    _locks[basePath] = completer.future;

    if (lock != null) {
      await lock;
    }

    try {
      final file = Context.fileSystem.file(basePath);
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      if (data.isEmpty) {
        return;
      }

      File targetFile = file;
      if (fileRotation != null &&
          await fileRotation.needsRotation(file, data)) {
        try {
          final shouldWrap = strategy == WrappingStrategy.document &&
              encoder != null &&
              await file.exists() &&
              await file.length() > 0;

          if (shouldWrap) {
            const factory = StandardPipelineFactory();
            final postContext = factory.checkoutContext();
            try {
              encoder.postamble(postContext, LogLevel.info, factory);
              final postBytes = postContext.takeBytes();
              if (postBytes.isNotEmpty) {
                final oldRaf = file.openSync(mode: LogFileMode.append);
                try {
                  oldRaf.writeFromSync(postBytes, 0, postBytes.length);
                } finally {
                  oldRaf.closeSync();
                }
              }
            } finally {
              factory.release(postContext);
            }
          }

          await fileRotation.rotate(basePath);
          targetFile = Context.fileSystem.file(basePath);

          if (shouldWrap) {
            final preBytes = getPreamble?.call() ??
                _activeSinks[basePath]?.rememberedPreamble;
            if (preBytes != null && preBytes.isNotEmpty) {
              final newRaf = targetFile.openSync(mode: LogFileMode.append);
              try {
                newRaf.writeFromSync(preBytes, 0, preBytes.length);
              } finally {
                newRaf.closeSync();
              }
            }
          }
        } catch (rotationError, rotationStack) {
          InternalLogger.log(
            LogLevel.warning,
            'File rotation failed, continuing with write to original file',
            error: rotationError,
            stackTrace: rotationStack,
          );
        }
      }

      final raf = targetFile.openSync(mode: LogFileMode.append);
      try {
        raf.writeFromSync(
          data,
          0,
          data.length,
        );
      } finally {
        raf.closeSync();
      }
    } finally {
      if (_locks[basePath] == completer.future) {
        unawaited(_locks.remove(basePath));
      }
      completer.complete();
    }
  }
}

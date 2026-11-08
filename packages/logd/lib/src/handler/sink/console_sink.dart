part of 'sink.dart';

/// A [LogSink] that encodes and outputs logs to the system console.
@immutable
base class ConsoleSink extends EncodingSink {
  /// Creates a [ConsoleSink].
  ///
  /// - [lineLength]: The max line length. If null, terminal width is used.
  /// - [encoder]: The encoder used to serialize logs (default:
  ///   [AutoConsoleEncoder]).
  /// - [allowSgr]: Whether safe ANSI SGR styling/color codes are allowed
  ///   through without neutralization (default: false). Intended for trusted
  ///   logs only.
  /// - [enabled]: Whether the sink is currently active.
  /// - [usePrint]: Whether to explicitly use [print] instead of [io.stdout].
  ///   If null, it defaults to using [print] in Flutter or non-terminal
  ///   environments.
  const ConsoleSink({
    this.lineLength,
    final LogEncoder? encoder,
    this.allowSgr = false,
    super.enabled,
    this.usePrint,
  }) : super(
          encoder: encoder ??
              (allowSgr
                  ? const AutoConsoleEncoder(allowSgr: true)
                  : const AutoConsoleEncoder()),
          delegate: usePrint == true
              ? PrintSink.staticWrite
              : (usePrint == false ? _stdoutWrite : _staticWrite),
          preferredWidth: lineLength,
        );

  /// The maximum line length for the output.
  final int? lineLength;

  /// Whether safe ANSI SGR styling/color codes are allowed through without
  /// neutralization.
  ///
  /// Intended for trusted logs only.
  final bool allowSgr;

  /// Whether to explicitly use [print] instead of [io.stdout].
  final bool? usePrint;

  static void _stdoutWrite(final Uint8List data) => io.stdout.add(data);

  static void _staticWrite(final Uint8List data) {
    final bool shouldPrint = io.isStub || !io.stdout.hasTerminal;

    if (shouldPrint) {
      PrintSink.staticWrite(data);
    } else {
      _stdoutWrite(data);
    }
  }

  @override
  int? get preferredWidth =>
      lineLength ?? (io.stdout.hasTerminal ? io.stdout.terminalColumns : 80);

  @override
  Future<void> flush() async {
    if (!io.isStub) {
      try {
        await io.stdout.flush();
      } catch (_) {}
    }
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ConsoleSink &&
          runtimeType == other.runtimeType &&
          lineLength == other.lineLength &&
          enabled == other.enabled &&
          usePrint == other.usePrint &&
          allowSgr == other.allowSgr;

  @override
  int get hashCode =>
      Object.hash(runtimeType, lineLength, enabled, usePrint, allowSgr);
}

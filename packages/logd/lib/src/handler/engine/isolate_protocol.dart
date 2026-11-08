library;

import 'dart:isolate';
import 'package:meta/meta.dart';

/// The internal control command types for background isolates.
@internal
enum IsolateCommandType {
  /// Stop the background isolate execution.
  stop,

  /// Flush in-flight pipeline tasks and underlying sinks.
  flush,
}

/// A control command sent to a background worker isolate.
@internal
class IsolateCommand {
  /// Creates a stop command.
  IsolateCommand.stop(this.replyPort) : type = IsolateCommandType.stop;

  /// Creates a flush command.
  IsolateCommand.flush(this.replyPort) : type = IsolateCommandType.flush;

  /// The type of command.
  final IsolateCommandType type;

  /// An optional port to send a reply back once the command is processed.
  final SendPort? replyPort;
}

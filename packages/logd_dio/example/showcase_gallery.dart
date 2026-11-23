import 'dart:io';

import 'advanced/custom_pipeline_example.dart' as advanced_example;
import 'main.dart' as main_example;
import 'resilience/error_and_cancellation_example.dart' as resilience_example;
import 'security/sanitization_example.dart' as security_example;
import 'serializers/custom_serializer_example.dart' as serializer_example;
import 'streaming/stream_telemetry_example.dart' as streaming_example;
import 'telemetry/w3c_tracing_and_metrics_example.dart' as telemetry_example;
import 'tracing/distributed_tracing_example.dart' as tracing_example;

/// Interactive showcase runner for `logd_dio` examples.
///
/// Usage:
/// ```bash
/// dart run example/showcase_gallery.dart         # Interactive menu
/// dart run example/showcase_gallery.dart 1       # Quick-Start
/// dart run example/showcase_gallery.dart 2       # Security & Sanitization
/// dart run example/showcase_gallery.dart 3       # Distributed Tracing
/// dart run example/showcase_gallery.dart 4       # Resilience & Cancellation
/// dart run example/showcase_gallery.dart 5       # Advanced & cURL
/// dart run example/showcase_gallery.dart 6       # W3C Tracing & Metrics
/// dart run example/showcase_gallery.dart 7       # Stream Telemetry
/// dart run example/showcase_gallery.dart 8       # Custom Serializers
/// dart run example/showcase_gallery.dart all     # Run all sequentially
/// ```
Future<void> main(final List<String> args) async {
  if (args.isNotEmpty) {
    switch (args.first.toLowerCase()) {
      case '1':
      case 'quick':
      case 'main':
        await main_example.main();
        return;
      case '2':
      case 'security':
      case 'sanitize':
        await security_example.main();
        return;
      case '3':
      case 'tracing':
      case 'trace':
        await tracing_example.main();
        return;
      case '4':
      case 'resilience':
      case 'cancel':
      case 'error':
        await resilience_example.main();
        return;
      case '5':
      case 'advanced':
      case 'curl':
        await advanced_example.main();
        return;
      case '6':
      case 'w3c':
      case 'telemetry':
      case 'metrics':
        await telemetry_example.main();
        return;
      case '7':
      case 'stream':
      case 'streaming':
        await streaming_example.main();
        return;
      case '8':
      case 'serializer':
      case 'serializers':
        await serializer_example.main();
        return;
      case '9':
      case 'all':
      case '--all':
      case '-a':
        await _runAll();
        return;
    }
  }

  print('================================================');
  print('          LOGD_DIO: SHOWCASE GALLERY            ');
  print('================================================');
  print('Select a demonstration to run:');
  print('');
  print('  [1] Quick-Start Basic Integration (main.dart)');
  print('  [2] Security & Sanitization (SOC2/GDPR Compliance)');
  print('  [3] Distributed Tracing & Zone Isolation (LogContext)');
  print('  [4] Resilience, Errors & Cancellation (CancelToken)');
  print('  [5] Advanced Configuration & cURL Generation');
  print('  [6] W3C Distributed Tracing, Metrics & Elevation');
  print('  [7] Non-Blocking Stream & Chunked Response Telemetry');
  print('  [8] Pluggable Custom Payload Serializers');
  print('  [9] Run All Demos Sequentially');
  print('  [0] Exit');
  print('');
  stdout.write('Enter choice [1-9, 0]: ');

  final input = stdin.readLineSync()?.trim();
  print('');

  switch (input) {
    case '1':
      await main_example.main();
      break;
    case '2':
      await security_example.main();
      break;
    case '3':
      await tracing_example.main();
      break;
    case '4':
      await resilience_example.main();
      break;
    case '5':
      await advanced_example.main();
      break;
    case '6':
      await telemetry_example.main();
      break;
    case '7':
      await streaming_example.main();
      break;
    case '8':
      await serializer_example.main();
      break;
    case '9':
      await _runAll();
      break;
    case '0':
    case null:
      print('Exiting.');
      break;
    default:
      print('Invalid choice "$input". Exiting.');
  }
}

Future<void> _runAll() async {
  print('\x1B[1;36m=== 1/8: Quick-Start ===\x1B[0m\n');
  await main_example.main();

  print('\n\x1B[1;36m=== 2/8: Security & Sanitization ===\x1B[0m\n');
  await security_example.main();

  print('\n\x1B[1;36m=== 3/8: Distributed Tracing ===\x1B[0m\n');
  await tracing_example.main();

  print('\n\x1B[1;36m=== 4/8: Resilience & Cancellation ===\x1B[0m\n');
  await resilience_example.main();

  print('\n\x1B[1;36m=== 5/8: Advanced Configuration & cURL ===\x1B[0m\n');
  await advanced_example.main();

  print('\n\x1B[1;36m=== 6/8: W3C Tracing, Metrics & Elevation ===\x1B[0m\n');
  await telemetry_example.main();

  print('\n\x1B[1;36m=== 7/8: Non-Blocking Stream Telemetry ===\x1B[0m\n');
  await streaming_example.main();

  print(
    '\n\x1B[1;36m=== 8/8: Pluggable Custom Payload Serializers ===\x1B[0m\n',
  );
  await serializer_example.main();

  print(
    '\n\x1B[32m✔ All logd_dio showcase demos completed successfully.\x1B[0m',
  );
}

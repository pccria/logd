import 'package:logd/logd.dart';
import 'sink/http_server_sink.dart';
import 'sink/network_sink.dart';

/// Registers serialization and deserialization handlers for [logd_network] components
/// with [LoggerSerializationRegistry].
///
/// If using background isolates with [HttpSink], [SocketSink], or [HttpServerSink],
/// call this function once in each isolate before calling `Logger.importConfig()`.
///
/// **Note**: Dynamic closure callbacks such as [HttpSink.headersProvider] and
/// [HttpSink.onDropped] are transient and cannot be serialized across isolates.
/// When deserializing in a worker isolate, these fields default to `null`.
void registerLogdNetworkSerializers() {
  LoggerSerializationRegistry.registerSink<HttpSink>(
    type: 'HttpSink',
    fromJson: (final json) => HttpSink(
      url: json['url'] as String,
      headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      batchSize: json['batchSize'] as int? ?? 50,
      flushInterval: Duration(
        milliseconds: json['flushIntervalMs'] as int? ?? 60000,
      ),
      maxRetries: json['maxRetries'] as int? ?? 5,
      maxBufferSize: json['maxBufferSize'] as int? ?? 1000,
      dropPolicy: DropPolicy.values.byName(
        json['dropPolicy'] as String? ?? 'discardOldest',
      ),
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'url': val.url,
      'headers': val.headers,
      'batchSize': val.batchSize,
      'flushIntervalMs': val.flushInterval.inMilliseconds,
      'maxRetries': val.maxRetries,
      'maxBufferSize': val.maxBufferSize,
      'dropPolicy': val.dropPolicy.name,
      'enabled': val.enabled,
    },
  );

  LoggerSerializationRegistry.registerSink<SocketSink>(
    type: 'SocketSink',
    fromJson: (final json) => SocketSink(
      url: json['url'] as String,
      headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      reconnectInterval: Duration(
        milliseconds: json['reconnectIntervalMs'] as int? ?? 15000,
      ),
      maxBufferSize: json['maxBufferSize'] as int? ?? 1000,
      dropPolicy: DropPolicy.values.byName(
        json['dropPolicy'] as String? ?? 'discardOldest',
      ),
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'url': val.url,
      'headers': val.headers,
      'reconnectIntervalMs': val.reconnectInterval.inMilliseconds,
      'maxBufferSize': val.maxBufferSize,
      'dropPolicy': val.dropPolicy.name,
      'enabled': val.enabled,
    },
  );

  LoggerSerializationRegistry.registerSink<HttpServerSink>(
    type: 'HttpServerSink',
    fromJson: (final json) => HttpServerSink(
      address: json['address'] as String? ?? 'localhost',
      port: json['port'] as int? ?? 8080,
      bufferCapacity: json['bufferCapacity'] as int? ?? 100,
      lineLength: json['lineLength'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'address': val.address,
      'port': val.port,
      'bufferCapacity': val.bufferCapacity,
      'lineLength': val.preferredWidth,
      'enabled': val.enabled,
    },
  );
}

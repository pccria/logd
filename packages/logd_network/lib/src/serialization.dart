import 'package:logd/logd.dart';
import 'policy/backoff_policy.dart';
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
      failoverUrls: (json['failoverUrls'] as List?)?.cast<String>() ?? const [],
      failureThreshold: json['failureThreshold'] as int? ?? 5,
      recoveryTimeout: Duration(
        milliseconds: json['recoveryTimeoutMs'] as int? ?? 60000,
      ),
      headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      batchSize: json['batchSize'] as int? ?? 50,
      flushInterval: Duration(
        milliseconds: json['flushIntervalMs'] as int? ?? 60000,
      ),
      maxRetries: json['maxRetries'] as int? ?? 5,
      deliveryFormat: HttpDeliveryFormat.values.byName(
        json['deliveryFormat'] as String? ?? 'jsonArray',
      ),
      backoffPolicy: json['backoffPolicy'] != null
          ? BackoffPolicy.fromJson(
              (json['backoffPolicy'] as Map).cast<String, dynamic>(),
            )
          : const BackoffPolicy(),
      compress: json['compress'] as bool? ?? false,
      maxBufferSize: json['maxBufferSize'] as int? ?? 1000,
      maxBufferBytes: json['maxBufferBytes'] as int?,
      dropPolicy: DropPolicy.values.byName(
        json['dropPolicy'] as String? ?? 'discardOldest',
      ),
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'url': val.url,
      'failoverUrls': val.failoverUrls,
      'failureThreshold': val.failureThreshold,
      'recoveryTimeoutMs': val.recoveryTimeout.inMilliseconds,
      'headers': val.headers,
      'batchSize': val.batchSize,
      'flushIntervalMs': val.flushInterval.inMilliseconds,
      'maxRetries': val.maxRetries,
      'deliveryFormat': val.deliveryFormat.name,
      'backoffPolicy': val.backoffPolicy.toJson(),
      'compress': val.compress,
      'maxBufferSize': val.maxBufferSize,
      if (val.maxBufferBytes != null) 'maxBufferBytes': val.maxBufferBytes,
      'dropPolicy': val.dropPolicy.name,
      'enabled': val.enabled,
    },
  );

  LoggerSerializationRegistry.registerSink<SocketSink>(
    type: 'SocketSink',
    fromJson: (final json) => SocketSink(
      url: json['url'] as String,
      headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      protocols: (json['protocols'] as List?)?.cast<String>(),
      reconnectInterval: Duration(
        milliseconds: json['reconnectIntervalMs'] as int? ?? 15000,
      ),
      backoffPolicy: json['backoffPolicy'] != null
          ? BackoffPolicy.fromJson(
              (json['backoffPolicy'] as Map).cast<String, dynamic>(),
            )
          : null,
      heartbeatInterval: json['heartbeatIntervalMs'] != null
          ? Duration(milliseconds: json['heartbeatIntervalMs'] as int)
          : const Duration(seconds: 30),
      heartbeatTimeout: Duration(
        milliseconds: json['heartbeatTimeoutMs'] as int? ?? 10000,
      ),
      pingMessage: json['pingMessage'] as String? ?? 'ping',
      pongMessage: json['pongMessage'] as String? ?? 'pong',
      maxBufferSize: json['maxBufferSize'] as int? ?? 1000,
      maxBufferBytes: json['maxBufferBytes'] as int?,
      dropPolicy: DropPolicy.values.byName(
        json['dropPolicy'] as String? ?? 'discardOldest',
      ),
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'url': val.url,
      'headers': val.headers,
      if (val.protocols != null) 'protocols': val.protocols!.toList(),
      'reconnectIntervalMs': val.reconnectInterval.inMilliseconds,
      if (val.backoffPolicy != null)
        'backoffPolicy': val.backoffPolicy!.toJson(),
      if (val.heartbeatInterval != null)
        'heartbeatIntervalMs': val.heartbeatInterval!.inMilliseconds,
      'heartbeatTimeoutMs': val.heartbeatTimeout.inMilliseconds,
      'pingMessage': val.pingMessage,
      'pongMessage': val.pongMessage,
      'maxBufferSize': val.maxBufferSize,
      if (val.maxBufferBytes != null) 'maxBufferBytes': val.maxBufferBytes,
      'dropPolicy': val.dropPolicy.name,
      'enabled': val.enabled,
    },
  );

  LoggerSerializationRegistry.registerSink<HttpServerSink>(
    type: 'HttpServerSink',
    fromJson: (final json) => HttpServerSink(
      address: json['address'] as String? ?? 'localhost',
      port: json['port'] as int? ?? 8080,
      title: json['title'] as String?,
      bufferCapacity: json['bufferCapacity'] as int? ?? 100,
      lineLength: json['lineLength'] as int?,
      maxConnections: json['maxConnections'] as int? ?? 32,
      allowedOrigins:
          (json['allowedOrigins'] as List?)?.cast<String>().toSet() ?? const {},
      allowedHosts:
          (json['allowedHosts'] as List?)?.cast<String>().toSet() ?? const {},
      authToken: json['authToken'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    ),
    toJson: (final val) => <String, dynamic>{
      'address': val.address,
      'port': val.port,
      if (val.title != null) 'title': val.title,
      'bufferCapacity': val.bufferCapacity,
      'lineLength': val.preferredWidth,
      'maxConnections': val.maxConnections,
      'allowedOrigins': val.allowedOrigins.toList(),
      'allowedHosts': val.allowedHosts.toList(),
      if (val.authToken != null) 'authToken': val.authToken,
      'enabled': val.enabled,
    },
  );
}

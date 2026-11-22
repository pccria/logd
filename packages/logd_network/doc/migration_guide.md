# Migration Guide: `logd` v0.9.x to `logd_network`

`logd_network` provides HTTP batching, WebSocket streaming, and a live web dashboard server for `logd`.

## 1. Add the Dependency

Add `logd_network` to your `pubspec.yaml`:

```yaml
dependencies:
  logd: ^latest_version
  logd_network: ^latest_version
```

Run `dart pub get` or `flutter pub get`.

## 2. Registering Serializers (For Full Isolate Config Sync)

`HttpDashboardHandler.async()` constructs its underlying `HttpServerSink` directly inside the worker isolate from plain configuration parameters, avoiding isolate port binding conflicts and eliminating the need for serializer registration.

However, if you export and import the full logger configuration registry across isolates using `Logger.exportConfig()` and `Logger.importConfig()`, you must register network serializers during your application bootstrap:

```dart
void main() {
  // Required only when using Logger.exportConfig() / Logger.importConfig()
  registerLogdNetworkSerializers();
}
```

## 3. Real-Time Dashboard Usage

`HttpDashboardHandler` starts a local web server (default: `http://localhost:8080`) where you can view live log streams in any web browser.

## 4. Upgrading to `v0.3.0`

`logd_network` v0.3.0 introduces configurable retry backoff with jitter, flexible ingestion delivery formats, and client-side memory budgeting. All existing code remains 100% backward compatible without breaking changes:

- **Backoff Policies**: `HttpSink` and `SocketSink` default to deterministic backoff curves. To enable randomized decorrelated jitter across fleet clients:
  ```dart
  HttpSink(
    url: 'https://logs.example.com',
    backoffPolicy: const BackoffPolicy(
      initialDelay: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 30),
      multiplier: 2.0,
      jitter: true, // prevents thundering herd spikes
    ),
  );
  ```
- **Delivery Formats**: To ingest via Newline-Delimited JSON or raw byte streams:
  ```dart
  HttpSink(
    url: 'https://logs.example.com/ndjson',
    deliveryFormat: HttpDeliveryFormat.ndjson, // sets application/x-ndjson
  );
  ```
- **Memory Budgeting & Priority Eviction**:
  ```dart
  HttpSink(
    url: 'https://logs.example.com',
    maxBufferBytes: 1024 * 1024, // 1 MB buffer ceiling
    dropPolicy: DropPolicy.discardByPriority, // drops debug -> info -> warning -> error
  );
  ```

## 5. Status in `v0.10.0`

In `logd` v0.10.0, all network sinks (`NetworkSink`, `HttpSink`, `SocketSink`, `HttpServerSink`, `HttpDashboardHandler`) were permanently removed from core `package:logd`.

- Core `logd` no longer depends on `package:http` or `package:web_socket_channel`.
- If migrating from `logd` <=0.9.7, replace all core network sink imports with `package:logd_network/logd_network.dart`.

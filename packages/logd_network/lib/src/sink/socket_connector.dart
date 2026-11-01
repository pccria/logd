import 'package:web_socket_channel/web_socket_channel.dart';
import 'socket_connector_stub.dart'
    if (dart.library.io) 'socket_connector_native.dart' as connector;

/// Connects to a WebSocket server with cross-platform support for native HTTP headers.
WebSocketChannel connectWebSocket(
  final Uri uri, {
  final Map<String, dynamic>? headers,
  final Iterable<String>? protocols,
}) =>
    connector.connectWebSocket(uri, headers: headers, protocols: protocols);

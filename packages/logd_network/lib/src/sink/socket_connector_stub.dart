import 'package:web_socket_channel/web_socket_channel.dart';

/// Web/browser implementation connecting via standard WebSocketChannel.
WebSocketChannel connectWebSocket(
  final Uri uri, {
  final Map<String, dynamic>? headers,
  final Iterable<String>? protocols,
}) =>
    WebSocketChannel.connect(uri, protocols: protocols);

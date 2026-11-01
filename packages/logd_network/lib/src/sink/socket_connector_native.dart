import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Native VM/IO implementation connecting via IOWebSocketChannel with real HTTP headers.
WebSocketChannel connectWebSocket(
  final Uri uri, {
  final Map<String, dynamic>? headers,
  final Iterable<String>? protocols,
}) =>
    IOWebSocketChannel.connect(uri, headers: headers, protocols: protocols);

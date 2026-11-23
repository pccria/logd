import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:logd/logd.dart';
import 'package:logd_dio/logd_dio.dart';

/// Simulated custom binary/domain model (e.g. Protocol Buffer message).
class OrderProto {
  const OrderProto(this.orderId, this.amount, this.authToken);
  final String orderId;
  final double amount;
  final String authToken;

  Uint8List toBinary() =>
      Uint8List.fromList(utf8.encode('PROTO:$orderId:$amount:$authToken'));
}

/// Demonstrates registering pluggable payload serializers with `logd_dio`.
Future<void> main() async {
  Logger.configure(
    'global',
    handlers: [ConsoleHandler(theme: const DarkTheme())],
  );

  final serializerLogger = Logger.get('serializers');

  // Register custom serializer for OrderProto models
  final orderSerializer = FunctionalBodySerializer(
    predicate: (final data, final ct) => data is OrderProto,
    formatter: (final data, final ct) {
      final proto = data as OrderProto;
      return '{"protoType":"OrderProto","orderId":"${proto.orderId}","amount":${proto.amount},"token":"${proto.authToken}"}';
    },
  );

  final dio = Dio();
  dio.httpClientAdapter = _EchoAdapter();

  dio.interceptors.add(
    LogdDioInterceptor(
      LogdDioOptions(
        bodySerializers: [orderSerializer],
        sensitiveBodyKeys: {
          'token',
        }, // token will still be redacted in preview & cURL!
        logCurl: true,
      ),
    ),
  );

  serializerLogger.info('Dispatching request with custom domain model...');

  await dio.post<void>(
    'https://api.example.com/v1/orders/submit',
    data: const OrderProto('ORD-8812', 149.99, 'vault-token-xyz'),
  );

  serializerLogger.info('Custom serializer demo completed successfully.');
}

class _EchoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    final RequestOptions options,
    final Stream<Uint8List>? requestStream,
    final Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"status":"acknowledged"}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({final bool force = false}) {}
}

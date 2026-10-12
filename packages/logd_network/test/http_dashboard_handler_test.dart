import 'package:logd/logd.dart';
import 'package:logd_network/logd_network.dart';
import 'package:logd_network/src/target_handlers/http_dashboard_isolate_handler.dart';
import 'package:logd_network/src/target_handlers/http_dashboard_isolate_handler_stub.dart'
    as stub;
import 'package:test/test.dart';

void main() {
  group('HttpDashboardHandler Tests', () {
    setUp(() {
      Logger.reset();
    });

    test('HttpDashboardHandler creates valid dashboard pipeline', () {
      final handler = HttpDashboardHandler(port: 8888, title: 'Test Dashboard');

      expect(handler, isA<Handler>());
      expect(handler.formatter, isA<StructuredFormatter>());
      expect(handler.sink, isA<HttpServerSink>());
    });

    test(
      'HttpDashboardHandler cleanly releases resources on dispose',
      () async {
        final handler = HttpDashboardHandler(
          port: 0, // 0 lets OS pick random ephemeral port
          title: 'Test Dashboard',
        );

        // Wait a tiny bit for the internal HttpServer to bind
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Dispose should complete without hanging or crashing
        await expectLater(handler.dispose(), completes);
      },
    );

    test('HttpDashboardHandler.async creates background isolate handler',
        () async {
      registerLogdNetworkSerializers();

      final handler = HttpDashboardHandler.async(
        port: 0,
        title: 'Async Test Dashboard',
      );

      expect(handler, isA<Handler>());

      Logger.configure('test.dashboard_async', handlers: [handler]);
      final logger = Logger.get('test.dashboard_async');

      await (handler as HttpDashboardIsolateHandler).ready;
      logger.info('Dashboard log on isolate');

      await expectLater(handler.dispose(), completes);
    });

    test(
      'HttpDashboardIsolateHandler stub throws UnsupportedError on construction',
      () {
        expect(
          () => stub.HttpDashboardIsolateHandler(),
          throwsUnsupportedError,
        );
      },
    );
  });
}

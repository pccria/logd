import 'dart:math';
import 'package:logd_network/logd_network.dart';
import 'package:test/test.dart';

void main() {
  group('BackoffPolicy Tests', () {
    test('default configuration has sane defaults', () {
      const policy = BackoffPolicy();
      expect(policy.initialDelay, equals(const Duration(milliseconds: 200)));
      expect(policy.maxDelay, equals(const Duration(seconds: 30)));
      expect(policy.multiplier, equals(2.0));
      expect(policy.jitter, isFalse);
    });

    test('constructor assertions prevent invalid parameters', () {
      expect(
        () => BackoffPolicy(multiplier: 0.9),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'deterministic backoff without jitter grows exponentially and clamps to maxDelay',
      () {
        const policy = BackoffPolicy(
          initialDelay: Duration(milliseconds: 500),
          maxDelay: Duration(milliseconds: 3000),
          multiplier: 2.0,
          jitter: false,
        );

        expect(policy.computeDelay(0), equals(Duration.zero));
        expect(policy.computeDelay(-1), equals(Duration.zero));
        expect(
          policy.computeDelay(1),
          equals(const Duration(milliseconds: 500)),
        );
        expect(
          policy.computeDelay(2),
          equals(const Duration(milliseconds: 1000)),
        );
        expect(
          policy.computeDelay(3),
          equals(const Duration(milliseconds: 2000)),
        );
        expect(
          policy.computeDelay(4),
          equals(const Duration(milliseconds: 3000)),
        ); // clamped
        expect(
          policy.computeDelay(10),
          equals(const Duration(milliseconds: 3000)),
        ); // clamped
      },
    );

    test('full jitter produces delays within [0, ceiling]', () {
      const policy = BackoffPolicy(
        initialDelay: Duration(milliseconds: 1000),
        maxDelay: Duration(milliseconds: 8000),
        multiplier: 2.0,
        jitter: true,
      );

      for (int attempt = 1; attempt <= 5; attempt++) {
        final deterministicCeiling = (1000 * pow(2.0, attempt - 1))
            .clamp(0, 8000)
            .toInt();
        for (int sample = 0; sample < 20; sample++) {
          final delay = policy.computeDelay(attempt);
          expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
          expect(delay.inMilliseconds, lessThanOrEqualTo(deterministicCeiling));
        }
      }
    });

    test('custom Random scales delay deterministically', () {
      const policy = BackoffPolicy(
        initialDelay: Duration(milliseconds: 1000),
        multiplier: 2.0,
        jitter: true,
      );

      // Attempt 2 deterministic ceiling is 2000ms
      final halfRandom = _FakeRandom(0.5);
      expect(
        policy.computeDelay(2, halfRandom),
        equals(const Duration(milliseconds: 1000)),
      );

      final zeroRandom = _FakeRandom(0.0);
      expect(policy.computeDelay(2, zeroRandom), equals(Duration.zero));

      final fullRandom = _FakeRandom(1.0);
      expect(
        policy.computeDelay(2, fullRandom),
        equals(const Duration(milliseconds: 2000)),
      );
    });

    test('JSON serialization round-trip', () {
      const original = BackoffPolicy(
        initialDelay: Duration(milliseconds: 1500),
        maxDelay: Duration(milliseconds: 45000),
        multiplier: 1.75,
        jitter: false,
      );

      final json = original.toJson();
      final restored = BackoffPolicy.fromJson(json);

      expect(restored, equals(original));
      expect(restored.initialDelay, equals(const Duration(milliseconds: 1500)));
      expect(restored.maxDelay, equals(const Duration(milliseconds: 45000)));
      expect(restored.multiplier, equals(1.75));
      expect(restored.jitter, isFalse);
    });

    test('equality and hashCode contract', () {
      const p1 = BackoffPolicy(initialDelay: Duration(seconds: 1));
      const p2 = BackoffPolicy(initialDelay: Duration(seconds: 1));
      const p3 = BackoffPolicy(initialDelay: Duration(seconds: 2));

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
    });
  });
}

class _FakeRandom implements Random {
  _FakeRandom(this._nextValue);
  final double _nextValue;

  @override
  double nextDouble() => _nextValue;

  @override
  bool nextBool() => true;

  @override
  int nextInt(int max) => (_nextValue * max).toInt();
}

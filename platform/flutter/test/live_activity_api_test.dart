import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/mosaic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mosaic_bridge');

  // ─── MActivityAlert / MEndPolicy value tests (no channel needed) ──────────

  group('MActivityAlert', () {
    test('toJson returns correct shape', () {
      const alert = MActivityAlert(title: 'Hey', body: 'Update!');
      expect(alert.toJson(), {'title': 'Hey', 'body': 'Update!'});
    });
  });

  group('MEndPolicy', () {
    test('immediate.name == "immediate"', () {
      expect(MEndPolicy.immediate.name, 'immediate');
    });
    test('afterDefault.name == "afterDefault"', () {
      expect(MEndPolicy.afterDefault.name, 'afterDefault');
    });
  });

  // ─── Channel mock tests ────────────────────────────────────────────────────

  group('MosaicLiveActivities.start', () {
    late List<MethodCall> log;

    setUp(() {
      log = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        log.add(call);
        if (call.method == 'startActivity') return 'test-id-42';
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends startActivity with activityType and state', () async {
      await MosaicLiveActivities.start(
        'com.example.MyActivity',
        {'score': '10', 'label': 'First half'},
      );

      expect(log.length, 1);
      expect(log.first.method, 'startActivity');
      final args = log.first.arguments as Map;
      expect(args['activityType'], 'com.example.MyActivity');
      expect(args['state'], {'score': '10', 'label': 'First half'});
    });

    test('returns the id from the native side', () async {
      final id = await MosaicLiveActivities.start('T', {});
      expect(id, 'test-id-42');
    });
  });

  group('MosaicLiveActivities.update', () {
    late List<MethodCall> log;

    setUp(() {
      log = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        log.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends updateActivity with id, state, and null alert', () async {
      await MosaicLiveActivities.update('abc', {'score': '20'});

      expect(log.length, 1);
      expect(log.first.method, 'updateActivity');
      final args = log.first.arguments as Map;
      expect(args['id'], 'abc');
      expect(args['state'], {'score': '20'});
      expect(args['alert'], isNull);
    });

    test('includes alert json when provided', () async {
      await MosaicLiveActivities.update(
        'abc',
        {'score': '20'},
        alert: const MActivityAlert(title: 'Goal!', body: 'Score updated'),
      );

      final args = log.first.arguments as Map;
      expect(args['alert'], {'title': 'Goal!', 'body': 'Score updated'});
    });
  });

  group('MosaicLiveActivities.end', () {
    late List<MethodCall> log;

    setUp(() {
      log = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        log.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends endActivity with default policy', () async {
      await MosaicLiveActivities.end('xyz');

      expect(log.first.method, 'endActivity');
      final args = log.first.arguments as Map;
      expect(args['id'], 'xyz');
      expect(args['policy'], 'afterDefault');
      expect(args['state'], isNull);
    });

    test('sends immediate policy and finalState when supplied', () async {
      await MosaicLiveActivities.end(
        'xyz',
        finalState: {'score': '99'},
        policy: MEndPolicy.immediate,
      );

      final args = log.first.arguments as Map;
      expect(args['policy'], 'immediate');
      expect(args['state'], {'score': '99'});
    });
  });

  group('MosaicLiveActivities.areEnabled', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns true when native returns true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => true);
      expect(await MosaicLiveActivities.areEnabled(), isTrue);
    });

    test('returns false when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      expect(await MosaicLiveActivities.areEnabled(), isFalse);
    });
  });

  group('MosaicLiveActivities.active', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('returns list of ids from native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              channel, (_) async => ['id-1', 'id-2', 'id-3']);
      expect(await MosaicLiveActivities.active(), ['id-1', 'id-2', 'id-3']);
    });

    test('returns empty list when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      expect(await MosaicLiveActivities.active(), isEmpty);
    });
  });
}

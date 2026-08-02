import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/mosaic_widgets.dart';

/// The store was write-only from Dart: `saveString` and friends went out, and
/// nothing came back. That mattered because the *widget* writes to it too — an
/// `MToggleAction` flips its bool on-device with the app closed, and a declared
/// `refresh:` source stores what it fetched. Neither was visible to the app.
///
/// `MFileImage` had the mirror problem: the DSL could name a file path the app
/// had no supported way to create.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mosaic_bridge');
  late List<MethodCall> calls;
  Object? reply;

  setUp(() {
    calls = [];
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('getValue', () {
    test('returns a typed value straight through', () async {
      reply = 'markets rally';
      expect(await MosaicBridge.getValue<String>('title'), 'markets rally');
      expect(calls.single.method, 'getValue');
      expect(calls.single.arguments['key'], 'title');
    });

    test('coerces the strings Android stores everything as', () async {
      // Android's SharedPreferences path writes numbers as text, so a bare
      // `is T` check would miss every numeric value.
      reply = '42';
      expect(await MosaicBridge.getValue<int>('count'), 42);
      reply = '3.5';
      expect(await MosaicBridge.getValue<double>('ratio'), 3.5);
      reply = 'true';
      expect(await MosaicBridge.getValue<bool>('torch_on'), isTrue);
    });

    test('decodes what saveList and saveJson wrote', () async {
      reply = jsonEncode([
        {'title': 'a'},
      ]);
      final rows = await MosaicBridge.getValue<List<dynamic>>('tasks');
      expect(rows, hasLength(1));
      expect((rows!.first as Map)['title'], 'a');
    });

    test('a missing key yields the default, not an exception', () async {
      reply = null;
      expect(
          await MosaicBridge.getValue<String>('nope', defaultValue: 'x'), 'x');
    });

    test('malformed JSON yields the default rather than throwing', () async {
      // A widget-side writer could store anything; a render must not crash.
      reply = 'not json';
      expect(
        await MosaicBridge.getValue<List<dynamic>>('tasks',
            defaultValue: const []),
        isEmpty,
      );
    });
  });

  group('saveFile', () {
    test('sends the bytes and returns the platform path', () async {
      reply = '/data/app/files/mosaic_files/ring.png';
      final path = await MosaicBridge.saveFile(
        'ring',
        Uint8List.fromList([1, 2, 3]),
      );
      expect(path, endsWith('ring.png'));
      expect(calls.single.method, 'saveFile');
      expect(calls.single.arguments['key'], 'ring');
      expect(calls.single.arguments['extension'], 'png');
      expect((calls.single.arguments['bytes'] as Uint8List), hasLength(3));
    });

    test('honours a non-default extension', () async {
      reply = '/tmp/x.jpg';
      await MosaicBridge.saveFile('x', Uint8List(0), extension: 'jpg');
      expect(calls.single.arguments['extension'], 'jpg');
    });
  });

  group('installedWidgets', () {
    test('maps platform rows into typed info', () async {
      reply = [
        {'name': 'News', 'id': '7', 'family': 'systemMedium'},
        {'name': 'Weather', 'id': '8'},
      ];
      final placed = await MosaicBridge.installedWidgets();
      expect(placed.map((w) => w.name), ['News', 'Weather']);
      expect(placed.first.family, 'systemMedium');
      // Android has no family concept, so absent must not become the string
      // "null".
      expect(placed.last.family, isNull);
    });

    test('an unimplemented host reports none rather than throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('not implemented');
      });
      expect(await MosaicBridge.installedWidgets(), isEmpty);
    });
  });
}

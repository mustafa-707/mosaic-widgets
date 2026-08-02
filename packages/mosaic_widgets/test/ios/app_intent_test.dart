import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('callback button emits Button(intent:) guarded with Link fallback',
      () async {
    final r = await runIos([
      irDef(container({
        '__type': 'HWButton',
        'child': text('go'),
        'action': {
          '__type': 'HWActionCallback',
          'callbackName': 'doThing',
        },
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Button(intent:'));
    expect(s, contains('if #available(iOS 17.0'));
    // retains the Link fallback for pre-iOS17
    expect(s, contains('Link(destination:'));
    // the callback intent struct name is referenced
    expect(s, contains('MosaicCallbackIntent'));
    expect(s, contains('doThing'));
  });

  test('refresh button emits Button(intent:) with refresh intent', () async {
    final r = await runIos([
      irDef(container({
        '__type': 'HWButton',
        'child': text('refresh'),
        'action': {'__type': 'HWRefreshAction'},
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Button(intent:'));
    expect(s, contains('if #available(iOS 17.0'));
    expect(s, contains('MosaicRefreshIntent'));
    expect(s, contains('Link(destination:'));
  });

  test('intent definitions are generated in a shared file with sentinel',
      () async {
    final r = await runIos([irDef(text('hi'))]);
    final intents = r.file('ios/HomeWidgetExtension/MosaicIntents.swift');
    final firstLine = readFirstLine(intents);
    expect(firstLine, contains('MOSAIC-GENERATED'));
    final body = readFile(intents);
    expect(body, contains('struct MosaicCallbackIntent: AppIntent'));
    expect(body, contains('struct MosaicRefreshIntent: AppIntent'));
    expect(body, contains('@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)'));
    expect(body, contains('reloadAllTimelines'));
    expect(body, contains('mosaic_pending_callback'));
    expect(body, contains('@Parameter'));
  });

  test('launch-url button is unchanged (plain Link)', () async {
    final r = await runIos([
      irDef(container({
        '__type': 'HWButton',
        'child': text('open'),
        'action': {'__type': 'HWLaunchUrlAction', 'url': 'myapp://x'},
      }))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Link(destination:'));
    expect(s, isNot(contains('Button(intent:')));
  });
}

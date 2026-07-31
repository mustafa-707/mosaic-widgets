import 'dart:io';

import 'package:mosaic_android/mosaic_android.dart';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:mosaic_ios/mosaic_ios.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The two generators are separate packages with separate test suites, so
/// nothing compared them — and they silently diverged: after Android learned to
/// size a stack child to its parent, iOS kept filling unconditionally, so the
/// same DSL laid out differently on each platform.
///
/// This runs one IR tree through both and asserts they agree on *whether* a node
/// fills its parent. It deliberately does not compare the emitted text, which is
/// necessarily different — only the layout decision.
MosaicConfig _config() => MosaicConfig.fromJson({
      'app': {
        'bundle_id': 'com.acme.app',
        'android_package': 'com.acme.app',
        'ios_app_group': 'group.com.acme.app.widgets',
      },
      'widgets': [
        {'name': 'TestW', 'entry': 'TestW'},
      ],
    });

IRDefinition _def(Map<String, dynamic> root) => IRDefinition.fromJson({
      'name': 'TestW',
      'width': 4,
      'height': 2,
      'root': root,
    });

Map<String, dynamic> _text(String s) => {'__type': 'HWText', 'text': s};

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mosaic_parity_');
    await Directory(p.join(root.path, 'android/app/src/main/res'))
        .create(recursive: true);
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Generates [node] as the only child of a row, returning whether each
  /// platform made it fill the row's main axis.
  Future<({bool android, bool ios})> fillsMainAxis(
      Map<String, dynamic> node) async {
    final defs = [
      _def({
        '__type': 'HWRow',
        'children': [node, _text('sibling')],
      })
    ];

    await AndroidGenerator(config: _config(), definitions: defs)
        .generate(root.path);
    await IosGenerator(config: _config(), definitions: defs)
        .generate(root.path);

    final xml = File(p.join(
      root.path,
      'android/app/src/main/res/layout/hw_testw.xml',
    )).readAsStringSync();
    final swift =
        File(p.join(root.path, 'ios/HomeWidgetExtension/TestW.swift'))
            .readAsStringSync();

    // Android: a row child fills the main axis with match_parent width or a
    // weight. Start *after* the LinearLayout's own opening tag — the row itself
    // is match_parent wide, which would otherwise read as every child filling.
    final rowTag = xml.indexOf('<LinearLayout');
    final body = xml.substring(xml.indexOf('>', rowTag) + 1);
    final androidFills = body.contains('android:layout_width="match_parent"') ||
        body.contains('android:layout_weight=');

    // iOS: only the stack body, so the widget wrapper's own frame is excluded.
    // SwiftUI expresses "fill" two ways — an infinite frame, or a bare Spacer,
    // which takes the free space with no frame modifier at all.
    final start = swift.indexOf('HStack');
    final stack = swift.substring(start, swift.indexOf('}', swift.indexOf('sibling')));
    final iosFills =
        stack.contains('maxWidth: .infinity') || stack.contains('Spacer()');

    return (android: androidFills, ios: iosFills);
  }

  test('Center does not fill a row on either platform', () async {
    // Flutter's Center wraps when unconstrained; both generators must match it.
    final r = await fillsMainAxis({'__type': 'HWCenter', 'child': _text('A')});
    expect(r.android, isFalse);
    expect(r.ios, isFalse);
    expect(r.android, r.ios);
  });

  test('Align does not fill a row main axis on either platform', () async {
    final r = await fillsMainAxis({
      '__type': 'HWAlign',
      'alignment': 'topStart',
      'child': _text('A'),
    });
    expect(r.android, isFalse);
    expect(r.ios, isFalse);
  });

  test('Flexible fills on both, because that is what it is for', () async {
    final r = await fillsMainAxis({
      '__type': 'HWFlexible',
      'flex': 1,
      'child': _text('A'),
    });
    expect(r.android, isTrue);
    expect(r.ios, isTrue);
  });

  test('Spacer fills on both', () async {
    final r = await fillsMainAxis({'__type': 'HWSpacer'});
    expect(r.android, isTrue);
    expect(r.ios, isTrue);
  });

  test('a plain text node fills on neither', () async {
    final r = await fillsMainAxis(_text('A'));
    expect(r.android, isFalse);
    expect(r.ios, isFalse);
  });

  test('a sized box fills on neither', () async {
    final r = await fillsMainAxis({'__type': 'HWSizedBox', 'width': 8});
    expect(r.android, isFalse);
    expect(r.ios, isFalse);
  });

  /// Generates [root] on both platforms and returns the three artefacts a
  /// property can land in.
  Future<({String xml, String kotlin, String swift})> both(
      Map<String, dynamic> node) async {
    final defs = [_def(node)];
    await AndroidGenerator(config: _config(), definitions: defs)
        .generate(root.path);
    await IosGenerator(config: _config(), definitions: defs)
        .generate(root.path);
    return (
      xml: File(p.join(
              root.path, 'android/app/src/main/res/layout/hw_testw.xml'))
          .readAsStringSync(),
      kotlin: File(p.join(root.path,
              'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TestWProvider.kt'))
          .readAsStringSync(),
      swift: File(p.join(root.path, 'ios/HomeWidgetExtension/TestW.swift'))
          .readAsStringSync(),
    );
  }

  group('a property honoured on one platform is honoured on the other', () {
    // Each of these is silent when dropped: the widget still builds and renders,
    // just wrong on one platform.

    test('maxLines truncates on both', () async {
      final g = await both({'__type': 'HWText', 'text': 'x', 'maxLines': 2});
      expect(g.xml, contains('android:maxLines="2"'));
      // Without ellipsize Android clips mid-glyph instead of showing "…".
      expect(g.xml, contains('ellipsize'));
      expect(g.swift, contains('lineLimit(2)'));
    });

    test('a semantics label reaches both accessibility APIs', () async {
      final g = await both({
        '__type': 'HWSemantics',
        'label': 'Battery level',
        'child': _text('100'),
      });
      expect(g.xml, contains('android:contentDescription="Battery level"'));
      expect(g.swift, contains('accessibilityLabel'));
    });

    test('image fit maps to each platform\'s equivalent', () async {
      final cover = await both(
          {'__type': 'HWNetworkImage', 'url': 'https://a/b.jpg', 'fit': 'cover'});
      expect(cover.xml, contains('android:scaleType="centerCrop"'));
      expect(cover.swift, contains('.aspectRatio(contentMode: .fill)'));

      final contain = await both({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'fit': 'contain',
      });
      expect(contain.xml, contains('android:scaleType="fitCenter"'));
      expect(contain.swift, contains('.aspectRatio(contentMode: .fit)'));
    });

    test('a circle clip is a circle on both, not a rounded rect', () async {
      // Android needs shape="oval"; corners on a rectangle would leave an
      // avatar visibly square-ish next to the iOS Circle().
      final g = await both({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'circle': true,
      });
      final clip = Directory(
              p.join(root.path, 'android/app/src/main/res/drawable'))
          .listSync()
          .whereType<File>()
          .firstWhere((f) => p.basename(f.path).startsWith('hw_clip_'))
          .readAsStringSync();
      expect(clip, contains('android:shape="oval"'));
      expect(g.swift, contains('Circle()'));
    });

    test('a radius clip is a rounded rect on both', () async {
      final g = await both({
        '__type': 'HWNetworkImage',
        'url': 'https://a/b.jpg',
        'radius': 16,
      });
      final clip = Directory(
              p.join(root.path, 'android/app/src/main/res/drawable'))
          .listSync()
          .whereType<File>()
          .firstWhere((f) => p.basename(f.path).startsWith('hw_clip_'))
          .readAsStringSync();
      expect(clip, contains('android:shape="rectangle"'));
      expect(clip, contains('android:radius="16dp"'));
      expect(g.swift, contains('cornerRadius'));
    });

    test('a count-down timer counts down on both', () async {
      // SwiftUI's `.timer` style counts down to a future date, which is the
      // iOS equivalent of setChronometerCountDown(true).
      final g = await both({'__type': 'HWTimer', 'target': 1900000000000});
      expect(g.kotlin, contains('setChronometerCountDown(R.id.hw_timer_0, true)'));
      expect(g.swift, contains('style: .timer'));
    });

    test('a count-up timer counts up on both', () async {
      final g = await both(
          {'__type': 'HWTimer', 'target': 1700000000000, 'countUp': true});
      expect(
          g.kotlin, contains('setChronometerCountDown(R.id.hw_timer_0, false)'));
      expect(g.swift, contains('countsDown: false'));
    });

    test('a formatted bind is formatted on both', () async {
      final g = await both({
        '__type': 'HWText',
        'text': {'__type': 'HWBind', 'key': 'p'},
        'format': 'currency',
      });
      expect(g.kotlin, contains('MosaicData.formatValue'));
      expect(g.swift, contains('.currency'));
    });

    test('visibility with a replacement swaps on both', () async {
      final g = await both({
        '__type': 'HWVisibility',
        'bind': {'__type': 'HWBind', 'key': 'on'},
        'child': _text('A'),
        'replacement': _text('B'),
      });
      // Android toggles two views; SwiftUI branches.
      expect(g.kotlin, contains('hw_visibility_on'));
      expect(g.kotlin, contains('hw_visibility_on_alt'));
      expect(g.swift, contains('mosaicBool'));
      expect(g.swift, contains('Text("A")'));
      expect(g.swift, contains('Text("B")'));
    });
  });
}

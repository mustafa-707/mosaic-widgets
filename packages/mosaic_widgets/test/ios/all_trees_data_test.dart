import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';
import 'support/gen_harness.dart';

Map<String, dynamic> _text(String key) => {
      '__type': 'HWText',
      'text': {'__type': 'HWBind', 'key': key},
      'style': <String, dynamic>{},
    };

Map<String, dynamic> _image(String key) => {
      '__type': 'HWNetworkImage',
      'url': {'__type': 'HWBind', 'key': key},
      'fit': 'cover',
      'circle': false,
      'accentedMode': 'fullColor',
    };

IRDefinition _def() => IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson({
        '__type': 'HWColumn',
        'children': [_text('medium_only'), _image('shared_img')],
      }),
      compactRoot: IRNode.fromJson(_text('compact_only')),
      largeRoot: IRNode.fromJson({
        '__type': 'HWColumn',
        'children': [_text('large_only'), _image('large_img')],
      }),
      resizeMode: 'both',
    );

void main() {
  test('every tree\'s binds are loaded, not just the default one', () async {
    final s = (await runIos([_def()])).swiftForTestW();
    final loader = s.substring(s.indexOf('for k in ['));
    final keys = loader.substring(0, loader.indexOf(']'));
    expect(keys, contains('"medium_only"'));
    expect(keys, contains('"compact_only"'));
    expect(keys, contains('"large_only"'));
  });

  test('images that only the large tree shows are prefetched too', () async {
    final s = (await runIos([_def()])).swiftForTestW();
    final prefetch = s.substring(s.indexOf('MosaicImageCache.prefetch('));
    final line = prefetch.substring(0, prefetch.indexOf('\n'));
    expect(line, contains('"shared_img"'));
    expect(line, contains('"large_img"'));
  });

  test('a URL bound by several trees is prefetched once', () async {
    final def = IRDefinition(
      name: 'TestW',
      root: IRNode.fromJson(_image('same_img')),
      compactRoot: IRNode.fromJson(_image('same_img')),
      resizeMode: 'both',
    );
    final s = (await runIos([def])).swiftForTestW();
    final prefetch = s.substring(s.indexOf('MosaicImageCache.prefetch('));
    final line = prefetch.substring(0, prefetch.indexOf('\n'));
    expect('"same_img"'.allMatches(line).length, 1);
  });

  test('the image cache file name does not depend on the process', () async {
    final core = readFile((await runIos([_def()]))
        .file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    // `String.hashValue` is randomised per launch, so a name built from it is
    // never found again by the next run of the extension.
    expect(core, isNot(contains('url.hashValue')));
    expect(core, contains('0xcbf29ce484222325'));
  });
}

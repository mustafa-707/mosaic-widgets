// Standalone verification: generates a widget exercising the Components pack
// and emits its .swift files into a temp dir so they can be type-checked with
// swiftc at both the iOS 16.1 and 17.0 targets. Not a unit test — run with:
//   dart run test/support/verify_typecheck.dart
// It prints the temp directory path; the caller runs swiftc against it.
import 'dart:io';
import 'package:mosaic_core/mosaic_core.dart';
import 'package:mosaic_ios/mosaic_ios.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _text(Object v, {Map<String, dynamic>? style}) =>
    {'__type': 'HWText', 'text': v, 'style': style ?? <String, dynamic>{}};
Map<String, dynamic> _bind(String k) => {'__type': 'HWBind', 'key': k};
Map<String, dynamic> _color(String hex) => {'hex': hex, 'opacity': 1.0};

Future<void> main() async {
  final root = {
    '__type': 'HWColumn',
    'children': [
      // Divider horizontal + vertical
      {
        '__type': 'HWDivider',
        'thickness': 2.0,
        'color': _color('#FF0000'),
        'vertical': false,
        'indent': 8.0,
      },
      {
        '__type': 'HWDivider',
        'thickness': 3.0,
        'color': null,
        'vertical': true,
        'indent': 4.0,
      },
      // Icon present + fallback
      {
        '__type': 'HWIcon',
        'sfSymbol': 'star.fill',
        'androidDrawable': null,
        'size': 18.0,
        'color': _color('#00FF00'),
      },
      {
        '__type': 'HWIcon',
        'sfSymbol': null,
        'androidDrawable': 'ic_foo',
        'size': 24.0,
        'color': null,
      },
      // Gauge static + bound
      {
        '__type': 'HWGauge',
        'value': 25.0,
        'max': 100.0,
        'trackColor': _color('#CCCCCC'),
        'fillColor': _color('#0000FF'),
        'lineWidth': 6.0,
      },
      {
        '__type': 'HWGauge',
        'value': _bind('pct'),
        'max': 100.0,
        'trackColor': null,
        'fillColor': null,
        'lineWidth': 4.0,
      },
      // Badge static + bound
      {
        '__type': 'HWBadge',
        'child': _text('A'),
        'count': 3,
        'color': _color('#FF0000'),
      },
      {
        '__type': 'HWBadge',
        'child': _text('B'),
        'count': _bind('unread'),
        'color': null,
      },
      // Charts — added later than this fixture, so nothing was compiling them.
      {
        '__type': 'HWSparkline',
        'bind': _bind('series'),
        'color': _color('#38BDF8'),
        'strokeWidth': 2.0,
        'fill': true,
      },
      {
        '__type': 'HWSparkline',
        'bind': _bind('series'),
        'color': null,
        'strokeWidth': 1.0,
        'fill': false,
        'height': 40.0,
      },
      {
        '__type': 'HWBarChart',
        'bind': _bind('series'),
        'color': _color('#22C55E'),
        'spacing': 3.0,
        'radius': 2.0,
      },
      // The same key rendered twice. On Android this collided into one view id
      // and the second never updated; on iOS each closure has its own scope, so
      // this is here to keep that true rather than assumed.
      _text(_bind('dupe')),
      _text(_bind('dupe')),
      {
        '__type': 'HWVisibility',
        'bind': _bind('flag'),
        'child': _text('on'),
        'replacement': _text('off'),
      },
      {
        '__type': 'HWVisibility',
        'bind': _bind('flag'),
        'child': _text('ON2'),
        'replacement': _text('OFF2'),
      },
      // Text maxLines + align
      _text('hello world', style: {
        'size': 12,
        'maxLines': 2,
        'align': 'center',
      }),
      _text(_bind('news_title'), style: {'align': 'end'}),
      // Container shadow + per-corner radius
      {
        '__type': 'HWContainer',
        'child': _text('boxed'),
        'background': _color('#222222'),
        'shadow': {
          'color': _color('#000000'),
          'blur': 8.0,
          'dx': 0.0,
          'dy': 2.0,
        },
        'corners': {
          'topLeft': 12.0,
          'topRight': 4.0,
          'bottomLeft': 0.0,
          'bottomRight': 20.0,
        },
      },
      // Gradient with angle
      {
        '__type': 'HWContainer',
        'child': _text('grad'),
        'gradient': {
          '__type': 'HWLinearGradient',
          'colors': [_color('#FF0000'), _color('#0000FF')],
          'stops': null,
          'angle': 90.0,
        },
      },
    ],
  };

  final def = IRDefinition(name: 'TestW', root: IRNode.fromJson(root));
  final cfg = MosaicConfig.fromJson({
    'app': {
      'bundle_id': 'com.acme.app',
      'android_package': 'com.acme.app',
      'ios_app_group': 'group.com.acme.app.widgets',
    },
    'widgets': [
      {
        'name': 'TestW',
        'entry': 'TestW',
        'android': {'min_sdk': 21, 'sizes': ['medium']},
        'ios': {'families': ['systemMedium']},
      },
    ],
  });

  final dir = await Directory.systemTemp.createTemp('hw_ios_verify_');
  await Directory(p.join(dir.path, 'ios', 'HomeWidgetExtension'))
      .create(recursive: true);
  await IosGenerator(config: cfg, definitions: [def]).generate(dir.path);
  stdout.writeln(p.join(dir.path, 'ios', 'HomeWidgetExtension'));
}

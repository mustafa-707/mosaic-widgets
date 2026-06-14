import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';

void main() {
  group('MDivider', () {
    test('defaults', () {
      expect(const MDivider().toJson(), {
        '__type': 'HWDivider',
        'thickness': 1.0,
        'color': null,
        'vertical': false,
        'indent': 0.0,
      });
    });

    test('all props', () {
      expect(
        const MDivider(
          thickness: 2,
          color: MColor.hex('#FF0000'),
          vertical: true,
          indent: 8,
        ).toJson(),
        {
          '__type': 'HWDivider',
          'thickness': 2.0,
          'color': {'hex': '#FF0000', 'dark': null, 'opacity': 1.0},
          'vertical': true,
          'indent': 8.0,
        },
      );
    });
  });

  group('MIcon', () {
    test('sfSymbol + androidDrawable + color', () {
      expect(
        const MIcon(
          sfSymbol: 'star.fill',
          androidDrawable: 'ic_star',
          size: 32,
          color: MColor.hex('#00FF00'),
        ).toJson(),
        {
          '__type': 'HWIcon',
          'sfSymbol': 'star.fill',
          'androidDrawable': 'ic_star',
          'size': 32.0,
          'color': {'hex': '#00FF00', 'dark': null, 'opacity': 1.0},
        },
      );
    });

    test('defaults / null color', () {
      expect(const MIcon(sfSymbol: 'bolt').toJson(), {
        '__type': 'HWIcon',
        'sfSymbol': 'bolt',
        'androidDrawable': null,
        'size': 24.0,
        'color': null,
      });
    });
  });

  group('MGauge', () {
    test('literal value', () {
      expect(
        const MGauge(
          value: 42.0,
          max: 100,
          trackColor: MColor.hex('#EEEEEE'),
          fillColor: MColor.hex('#3333FF'),
          lineWidth: 8,
        ).toJson(),
        {
          '__type': 'HWGauge',
          'value': 42.0,
          'max': 100.0,
          'trackColor': {'hex': '#EEEEEE', 'dark': null, 'opacity': 1.0},
          'fillColor': {'hex': '#3333FF', 'dark': null, 'opacity': 1.0},
          'lineWidth': 8.0,
        },
      );
    });

    test('MBind value + defaults', () {
      expect(const MGauge(value: MBind('progress')).toJson(), {
        '__type': 'HWGauge',
        'value': {'__type': 'HWBind', 'key': 'progress'},
        'max': 100.0,
        'trackColor': null,
        'fillColor': null,
        'lineWidth': 6.0,
      });
    });
  });

  group('MBadge', () {
    test('int count', () {
      expect(
        const MBadge(
          child: MIcon(sfSymbol: 'bell'),
          count: 3,
          color: MColor.hex('#FF0000'),
        ).toJson(),
        {
          '__type': 'HWBadge',
          'child': {
            '__type': 'HWIcon',
            'sfSymbol': 'bell',
            'androidDrawable': null,
            'size': 24.0,
            'color': null,
          },
          'count': 3,
          'color': {'hex': '#FF0000', 'dark': null, 'opacity': 1.0},
        },
      );
    });

    test('String count', () {
      expect(
        const MBadge(child: MSpacer(), count: '9+').toJson(),
        {
          '__type': 'HWBadge',
          'child': {'__type': 'HWSpacer'},
          'count': '9+',
          'color': null,
        },
      );
    });

    test('MBind count', () {
      expect(
        const MBadge(child: MSpacer(), count: MBind('unread')).toJson(),
        {
          '__type': 'HWBadge',
          'child': {'__type': 'HWSpacer'},
          'count': {'__type': 'HWBind', 'key': 'unread'},
          'color': null,
        },
      );
    });
  });

  group('MText maxLines + align', () {
    test('set', () {
      final json = const MText(
        'hi',
        maxLines: 2,
        align: MTextAlign.center,
      ).toJson();
      expect(json['maxLines'], 2);
      expect(json['align'], 'center');
    });

    test('unset -> keys present with null', () {
      final json = const MText('hi').toJson();
      expect(json.containsKey('maxLines'), isTrue);
      expect(json.containsKey('align'), isTrue);
      expect(json['maxLines'], isNull);
      expect(json['align'], isNull);
    });
  });

  group('MContainer shadow + corners', () {
    test('shadow', () {
      final json = const MContainer(
        child: MSpacer(),
        shadow: MShadow(color: MColor.hex('#000000'), blur: 12, dx: 1, dy: 4),
      ).toJson();
      expect(json['shadow'], {
        'color': {'hex': '#000000', 'dark': null, 'opacity': 1.0},
        'blur': 12.0,
        'dx': 1.0,
        'dy': 4.0,
      });
    });

    test('shadow defaults', () {
      expect(const MShadow().toJson(), {
        'color': null,
        'blur': 8.0,
        'dx': 0.0,
        'dy': 2.0,
      });
    });

    test('per-corner radius', () {
      final json = const MContainer(
        child: MSpacer(),
        corners: MRadius(
          topLeft: 4,
          topRight: 8,
          bottomLeft: 12,
          bottomRight: 16,
        ),
      ).toJson();
      expect(json['corners'], {
        'topLeft': 4.0,
        'topRight': 8.0,
        'bottomLeft': 12.0,
        'bottomRight': 16.0,
      });
    });

    test('MRadius.all', () {
      expect(const MRadius.all(10).toJson(), {
        'topLeft': 10.0,
        'topRight': 10.0,
        'bottomLeft': 10.0,
        'bottomRight': 10.0,
      });
    });

    test('scalar radius still works; shadow/corners null when unset', () {
      final json = const MContainer(child: MSpacer(), radius: 5).toJson();
      expect(json['radius'], 5.0);
      expect(json['shadow'], isNull);
      expect(json['corners'], isNull);
    });
  });

  group('MStack alignment', () {
    test('default alignment is topLeading', () {
      final json = MStack([const MText('x')]).toJson();
      expect(json['__type'], 'HWStack');
      expect(json['alignment'], 'topLeading');
    });

    test('explicit center alignment', () {
      final json = MStack(
        [const MText('x')],
        alignment: MStackAlignment.center,
      ).toJson();
      expect(json['alignment'], 'center');
    });

    test('all nine alignment names round-trip', () {
      const expected = [
        'topLeading', 'top', 'topTrailing',
        'leading', 'center', 'trailing',
        'bottomLeading', 'bottom', 'bottomTrailing',
      ];
      for (final value in MStackAlignment.values) {
        final json = MStack([], alignment: value).toJson();
        expect(expected.contains(json['alignment']), isTrue,
            reason: 'unexpected name: ${json['alignment']}');
      }
      expect(MStackAlignment.values.length, expected.length);
    });

    test('wire __type stays HWStack', () {
      expect(
        MStack([], alignment: MStackAlignment.bottomTrailing).toJson()['__type'],
        'HWStack',
      );
    });
  });

  group('MLinearGradient angle', () {
    test('explicit angle', () {
      final json = const MLinearGradient(
        colors: [MColor.hex('#000000'), MColor.hex('#FFFFFF')],
        stops: [0, 1],
        angle: 90,
      ).toJson();
      expect(json['angle'], 90.0);
      expect(json['colors'], isA<List>());
      expect(json['stops'], [0, 1]);
    });

    test('default angle is 0', () {
      final json = const MLinearGradient(
        colors: [MColor.hex('#000000'), MColor.hex('#FFFFFF')],
      ).toJson();
      expect(json['angle'], 0.0);
    });
  });
}

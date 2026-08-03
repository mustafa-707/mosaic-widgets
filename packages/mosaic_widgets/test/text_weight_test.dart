import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';

/// Before this, a widget author could choose regular or bold, upright only —
/// a hard ceiling on output quality for exactly the medium/semibold typography
/// Apple's stock widgets and Material You lean on.
void main() {
  group('wire', () {
    test('an unweighted style is unchanged', () {
      // 72 literal MTextStyle sites exist, including the CLI scaffold. If the
      // common case grew keys, every golden fixture would move for nothing.
      expect(const MTextStyle(size: 12).toJson(), {
        'size': 12,
        'color': null,
        'opacity': null,
        'bold': null,
      });
    });

    test('weight and italic travel when set', () {
      final json = const MTextStyle(
        weight: MFontWeight.w600,
        italic: true,
      ).toJson();
      expect(json['weight'], 'w600');
      expect(json['italic'], isTrue);
    });
  });

  group('baseStyle', () {
    test('is flattened before serialization', () {
      // Nothing downstream should have to walk a chain — the generators see a
      // single resolved map.
      const base = MTextStyle(size: 14, bold: true);
      final json = const MTextStyle(
        baseStyle: base,
        weight: MFontWeight.w500,
      ).toJson();
      expect(json['size'], 14, reason: 'inherited');
      expect(json['bold'], isTrue, reason: 'inherited');
      expect(json['weight'], 'w500', reason: 'own field');
      expect(json.containsKey('baseStyle'), isFalse);
    });

    test('own fields win over inherited ones', () {
      const base = MTextStyle(size: 14);
      expect(const MTextStyle(baseStyle: base, size: 20).toJson()['size'], 20);
    });

    test('chains resolve all the way down', () {
      const a = MTextStyle(size: 10);
      const b = MTextStyle(baseStyle: a, italic: true);
      final json = const MTextStyle(
        baseStyle: b,
        weight: MFontWeight.w900,
      ).toJson();
      expect(json['size'], 10);
      expect(json['italic'], isTrue);
      expect(json['weight'], 'w900');
    });
  });

  group('copyWith', () {
    test('replaces only what is named', () {
      const s = MTextStyle(size: 12, bold: true);
      final c = s.copyWith(weight: MFontWeight.w300);
      expect(c.size, 12);
      expect(c.bold, isTrue);
      expect(c.weight, MFontWeight.w300);
    });
  });

  group('the Android approximation is real and documented', () {
    test('every weight names a family Android actually ships', () {
      // textFontWeight is API 28 and the floor is 21, so weight goes through
      // the sans-serif-* aliases — six steps for the DSL's nine.
      const shipped = {'thin', 'light', 'regular', 'medium', 'bold', 'black'};
      for (final w in MFontWeight.values) {
        expect(
          shipped,
          contains(w.androidFamilySuffix),
          reason: '${w.name} maps to a family Android does not have',
        );
      }
    });

    test('the collapsing pairs are the ones documented', () {
      // w200→thin, w600→medium, w800→black. If these ever stop collapsing the
      // docs are wrong, so pin them.
      expect(MFontWeight.w200.androidFamilySuffix,
          MFontWeight.w100.androidFamilySuffix);
      expect(MFontWeight.w600.androidFamilySuffix,
          MFontWeight.w500.androidFamilySuffix);
      expect(MFontWeight.w800.androidFamilySuffix,
          MFontWeight.w900.androidFamilySuffix);
    });

    test('iOS keeps all nine distinct', () {
      final swift = MFontWeight.values.map((w) => w.swiftWeight).toSet();
      expect(swift, hasLength(MFontWeight.values.length));
    });
  });
}

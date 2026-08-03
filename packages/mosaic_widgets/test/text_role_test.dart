import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';

/// Authors previously hand-guessed point sizes, which produces widgets that do
/// not sit right next to the OS's own. A role names the intent instead, and
/// each platform resolves it on its own scale — the roles line up, the exact
/// sizes deliberately do not.
void main() {
  test('a style without a role is unchanged on the wire', () {
    // The common case must not grow keys, or every golden moves for nothing.
    expect(const MTextStyle(size: 12).toJson().keys.toSet(), {
      'size',
      'color',
      'opacity',
      'bold',
    });
  });

  test('a role carries both platforms\' resolutions', () {
    // Each generator resolves without needing a shared lookup table.
    final json = const MTextStyle(role: MTextRole.headline).toJson();
    expect(json['role'], 'headline');
    expect(json['roleSwiftFont'], 'headline');
    expect(json['roleAndroidSp'], 16);
  });

  test('every role names a real SwiftUI Font case', () {
    // A typo here compiles in Dart and fails in Swift, which is the worst
    // place to find out.
    const valid = {
      'largeTitle',
      'title',
      'title2',
      'title3',
      'headline',
      'subheadline',
      'body',
      'callout',
      'footnote',
      'caption',
      'caption2',
    };
    for (final r in MTextRole.values) {
      expect(valid, contains(r.swiftFont),
          reason: '${r.name} → ${r.swiftFont}');
    }
  });

  test('the ramp descends', () {
    // title is the largest, captionSmall the smallest; a ramp that is not
    // monotonic is not a ramp.
    final sizes = MTextRole.values.map((r) => r.androidSp).toList();
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], lessThanOrEqualTo(sizes[i - 1]),
          reason:
              '${MTextRole.values[i].name} is larger than the role above it');
    }
  });

  test('roles stay legible on a widget', () {
    // A home-screen tile is small and the OS fixes its size; anything under
    // ~11sp is unreadable there regardless of what a phone UI would allow.
    for (final r in MTextRole.values) {
      expect(r.androidSp, greaterThanOrEqualTo(11));
      expect(r.androidSp, lessThanOrEqualTo(28));
    }
  });

  test('an explicit size wins over the role', () {
    // Naming a number is the more specific instruction, so it must not be
    // silently overridden by the semantic default.
    final json = const MTextStyle(role: MTextRole.title, size: 9).toJson();
    expect(json['size'], 9);
    expect(json['roleAndroidSp'], 22, reason: 'still carried, just outranked');
  });

  test('a role is inherited through baseStyle', () {
    const base = MTextStyle(role: MTextRole.caption);
    expect(const MTextStyle(baseStyle: base).toJson()['role'], 'caption');
  });

  test('copyWith can replace the role', () {
    const s = MTextStyle(role: MTextRole.body);
    expect(s.copyWith(role: MTextRole.title).role, MTextRole.title);
  });
}

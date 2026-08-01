import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('container background with dark variant emits light+dark adaptive color',
      () async {
    final r = await runIos([
      irDef(container(
        text('hi'),
        extra: {
          'background': {'hex': '#112233', 'dark': '#445566', 'opacity': 1.0},
        },
      ))
    ]);
    final s = r.swiftForTestW();
    // both light & dark hex present
    expect(s, contains('112233'));
    expect(s, contains('445566'));
    // adaptive helper / colorScheme switch
    expect(s, contains('Color(light:'));
  });

  test('opacity below 1 on adaptive color is applied', () async {
    final r = await runIos([
      irDef(container(
        text('hi'),
        extra: {
          'background': {'hex': '#112233', 'dark': '#445566', 'opacity': 0.5},
        },
      ))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Color(light:'));
    expect(s, contains('.opacity(0.5)'));
  });

  test('static color without dark keeps simple Color(hex:) form', () async {
    final r = await runIos([
      irDef(container(
        text('hi'),
        extra: {
          'background': {'hex': '#112233', 'dark': null, 'opacity': 1.0},
        },
      ))
    ]);
    final s = r.swiftForTestW();
    expect(s, isNot(contains('Color(light:')));
    // 7-char #RRGGBB resolves to a literal Color(red:green:blue:) expression.
    expect(s, contains('Color(red:'));
  });

  test('bind color resolves from entry data', () async {
    final r = await runIos([
      irDef(container(
        text('hi'),
        extra: {
          'background': {'bind': 'accent', 'opacity': 1.0},
        },
      ))
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('entry.data['));
    expect(s, contains('accent'));
  });

  test('core defines the Color(light:dark:) helper', () async {
    final r = await runIos([irDef(text('hi'))]);
    final core =
        readFile(r.file('ios/HomeWidgetExtension/HomeWidgetCore.swift'));
    expect(core, contains('init(light:'));
    expect(core, contains('userInterfaceStyle'));
  });
}

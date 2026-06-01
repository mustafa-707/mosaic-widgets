import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('currency format on bound text emits .currency', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('price'),
        'style': <String, dynamic>{},
        'format': 'currency',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.currency'));
    expect(s, contains('entry.data["price"]'));
  });

  test('relativeTime format on bound text emits .relative', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('eta'),
        'style': <String, dynamic>{},
        'format': 'relativeTime',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.relative'));
  });

  test('decimal format emits .number', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('count'),
        'style': <String, dynamic>{},
        'format': 'decimal',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.number'));
  });

  test('percent format emits .percent', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('ratio'),
        'style': <String, dynamic>{},
        'format': 'percent',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('.percent'));
  });

  test('date format emits Date(timeIntervalSince1970:) and .formatted', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('ts'),
        'style': <String, dynamic>{},
        'format': 'date',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Date(timeIntervalSince1970:'));
    expect(s, contains('.formatted(date:'));
  });

  test('date format divides epoch millis by 1000 (millis→seconds)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('when'),
        'style': <String, dynamic>{},
        'format': 'date',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('/ 1000'),
        reason: 'iOS must divide epoch-ms by 1000.0 to match Android');
  });

  test('relativeTime format divides epoch millis by 1000 (millis→seconds)',
      () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': bind('when'),
        'style': <String, dynamic>{},
        'format': 'relativeTime',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('/ 1000'),
        reason: 'iOS must divide epoch-ms by 1000.0 to match Android');
  });

  test('format ignored on static (non-bind) text', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWText',
        'text': 'hello',
        'style': <String, dynamic>{},
        'format': 'currency',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('Text("hello")'));
    expect(s, isNot(contains('.currency')));
  });
}

import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('no dictionaryRepresentation in generated swift', () async {
    final r = await runIos([irDef(text(bind('t')))]);
    expect(r.swiftForTestW(), isNot(contains('dictionaryRepresentation')));
  });

  test('loadData reads only the used bind keys', () async {
    final r = await runIos([irDef(text(bind('t')))]);
    final s = r.swiftForTestW();
    // The single used key 't' must be read from the suite explicitly.
    expect(s, contains('"t"'));
    expect(s, contains('object(forKey:'));
  });

  test('timer with bind target reads entry data at runtime', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': {'__type': 'HWBind', 'key': 'deadline'},
        'countUp': false,
        'style': {}
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('deadline'));
    expect(s, contains('timeIntervalSince1970'));
  });

  test('timer with literal target bakes the date', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWTimer',
        'target': 1700000000000,
        'countUp': false,
        'style': {}
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('timeIntervalSince1970'));
    expect(s, contains('1700000000'));
  });

  test('progress bind reads entry data', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWProgressBar',
        'value': {'__type': 'HWBind', 'key': 'p'},
        'max': 100.0,
        'color': {'hex': '#FF0000', 'opacity': 1.0}
      })
    ]);
    expect(r.swiftForTestW(), contains('entry.data["p"]'));
  });

  test('image file bind reads entry data', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWImage',
        'source': {
          '__type': 'HWFileImage',
          'path': {'__type': 'HWBind', 'key': 'pic'}
        },
        'fit': 'cover'
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('entry.data["pic"]'));
    expect(s, contains('contentsOfFile'));
  });
}

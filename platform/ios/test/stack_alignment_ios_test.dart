import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  test('ZStack with alignment center emits ZStack(alignment: .center)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'center',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .center'));
  });

  test('ZStack with alignment bottomTrailing emits ZStack(alignment: .bottomTrailing)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'bottomTrailing',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .bottomTrailing'));
  });

  test('ZStack with alignment topLeading emits ZStack(alignment: .topLeading)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'topLeading',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .topLeading'));
  });

  test('ZStack with alignment top emits ZStack(alignment: .top)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'top',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .top'));
  });

  test('ZStack with alignment topTrailing emits ZStack(alignment: .topTrailing)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'topTrailing',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .topTrailing'));
  });

  test('ZStack with alignment leading emits ZStack(alignment: .leading)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'leading',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .leading'));
  });

  test('ZStack with alignment trailing emits ZStack(alignment: .trailing)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'trailing',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .trailing'));
  });

  test('ZStack with alignment bottomLeading emits ZStack(alignment: .bottomLeading)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'bottomLeading',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .bottomLeading'));
  });

  test('ZStack with alignment bottom emits ZStack(alignment: .bottom)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'bottom',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .bottom'));
  });

  test('ZStack with absent alignment defaults to ZStack(alignment: .topLeading)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .topLeading'));
  });

  test('ZStack with unknown alignment defaults to ZStack(alignment: .topLeading)', () async {
    final r = await runIos([
      irDef({
        '__type': 'HWStack',
        'children': [
          {'__type': 'HWText', 'text': 'x', 'style': <String, dynamic>{}}
        ],
        'alignment': 'unknown_value',
      })
    ]);
    final s = r.swiftForTestW();
    expect(s, contains('ZStack(alignment: .topLeading'));
  });
}

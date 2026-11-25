import 'package:mosaic_widgets/dsl.dart';
import 'package:mosaic_widgets/src/core/core.dart';
import 'package:test/test.dart';

void main() {
  const root = MText('hi');

  test('widgetUrl is omitted from the wire shape when not set', () {
    final json = const MosaicDefinition(name: 'W', root: root).toJson();
    expect(json.containsKey('widgetUrl'), isFalse);
  });

  test('a literal widgetUrl serialises as a string', () {
    final json = const MosaicDefinition(
            name: 'W', root: root, widgetUrl: 'mosaic://offer/1')
        .toJson();
    expect(json['widgetUrl'], 'mosaic://offer/1');
  });

  test('an MBind widgetUrl serialises as a bind and round-trips to the IR', () {
    final json = const MosaicDefinition(
      name: 'W',
      root: root,
      widgetUrl: MBind('offer_url', defaultValue: 'mosaic://home'),
    ).toJson();
    expect(json['widgetUrl'], {
      '__type': 'HWBind',
      'key': 'offer_url',
      'defaultValue': 'mosaic://home'
    });
    final ir = IRDefinition.fromJson(json);
    expect(ir.widgetUrlBind!['key'], 'offer_url');
    expect(ir.widgetUrlLiteral, isNull);
  });

  test('widgetUrl must be a String or an MBind', () {
    expect(() => MosaicDefinition(name: 'W', root: root, widgetUrl: 42),
        throwsA(isA<AssertionError>()));
  });

  test('MTimer keeps its literal wire shape', () {
    final json =
        MTimer(target: DateTime.fromMillisecondsSinceEpoch(5)).toJson();
    expect(json['target'], 5);
  });

  test('MTimer.bound serialises the bind as the target', () {
    final json = MTimer.bound(const MBind('ends_at'), countUp: true).toJson();
    expect(json['target'], {'__type': 'HWBind', 'key': 'ends_at'});
    expect(json['countUp'], true);
  });
}

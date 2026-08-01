import 'package:mosaic_widgets/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MExpanded emits all slots (null where absent)', () {
    final j = MExpanded(
      leading: MText('L'),
      trailing: MText('T'),
    ).toJson();
    expect(j['__type'], 'HWExpanded');
    expect(j['leading']['__type'], 'HWText');
    expect(j['leading']['text'], 'L');
    expect(j['trailing']['__type'], 'HWText');
    expect(j['center'], isNull);
    expect(j['bottom'], isNull);
  });

  test('MDynamicIsland nests each region toJson', () {
    final j = MDynamicIsland(
      compactLeading: MText('cl'),
      compactTrailing: MText('ct'),
      minimal: MText('m'),
      expanded: MExpanded(center: MText('c')),
    ).toJson();
    expect(j['__type'], 'HWDynamicIsland');
    expect(j['compactLeading']['__type'], 'HWText');
    expect(j['compactLeading']['text'], 'cl');
    expect(j['compactTrailing']['text'], 'ct');
    expect(j['minimal']['text'], 'm');
    expect(j['expanded']['__type'], 'HWExpanded');
    expect(j['expanded']['center']['text'], 'c');
  });

  test('MosaicLiveActivity emits full wire shape', () {
    final la = MosaicLiveActivity(
      name: 'DeliveryActivity',
      lockScreen: MText('lock'),
      dynamicIsland: MDynamicIsland(
        compactLeading: MText('cl'),
        compactTrailing: MText('ct'),
        minimal: MText('m'),
        expanded: MExpanded(leading: MText('e')),
      ),
    );
    final j = la.toJson();
    expect(j['__type'], 'HWLiveActivity');
    expect(j['name'], 'DeliveryActivity');
    expect(j['lockScreen']['__type'], 'HWText');
    expect(j['lockScreen']['text'], 'lock');
    expect(j['dynamicIsland']['__type'], 'HWDynamicIsland');
    expect(j['dynamicIsland']['expanded']['__type'], 'HWExpanded');
    expect(j['dynamicIsland']['expanded']['leading']['text'], 'e');
    expect(j['dynamicIsland']['expanded']['trailing'], isNull);
  });
}

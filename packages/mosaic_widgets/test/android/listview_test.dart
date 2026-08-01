import 'package:test/test.dart';
import 'support/fixtures.dart';
import 'support/gen_harness.dart';

void main() {
  group('HWListView Android RemoteViews collection', () {
    Future<GenResult> genList() => runAndroid([
          irDef(
            {
              '__type': 'HWColumn',
              'children': [
                {
                  '__type': 'HWListView',
                  'bind': {'__type': 'HWBind', 'key': 'items'},
                  'itemTemplate': {
                    '__type': 'HWRow',
                    'children': [
                      text(bind('title')),
                      text(bind('subtitle')),
                    ],
                  },
                }
              ],
            },
            name: 'ListW',
          )
        ]);

    test('(a) widget layout declares a ListView with the sanitized id',
        () async {
      final res = await genList();
      final layout = res.file(
        'android/app/src/main/res/layout/hw_listw.xml',
      );
      expect(layout, contains('<ListView'));
      expect(layout, contains('@+id/hw_list_items'));
    });

    test(
        '(b) MosaicListService.kt reads resolveList and inflates the item '
        'layout', () async {
      final res = await genList();
      const svc =
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/MosaicListService.kt';
      expect(res.exists(svc), isTrue);
      final kt = res.file(svc);
      expect(kt, contains('RemoteViewsService'));
      expect(kt, contains('RemoteViewsFactory'));
      expect(kt, contains('MosaicData.resolveList'));
      // The per-row item layout is inflated and bound fields are set.
      expect(kt, contains('R.layout.hw_listitem_listw_items'));
      expect(kt, contains('setTextViewText'));
      expect(kt, contains('R.id.hw_item_title'));
      expect(kt, contains('R.id.hw_item_subtitle'));
      // The factory reads the list key from the intent extra.
      expect(kt, contains('hw_list_key'));
    });

    test('(c) the per-row item layout is generated from the template',
        () async {
      final res = await genList();
      const item =
          'android/app/src/main/res/layout/hw_listitem_listw_items.xml';
      expect(res.exists(item), isTrue);
      final xml = res.file(item);
      expect(xml.split('\n').first, startsWith('<?xml'));
      expect(xml, contains('@+id/hw_item_title'));
      expect(xml, contains('@+id/hw_item_subtitle'));
    });

    test(
        '(d) the provider wires setRemoteAdapter + '
        'notifyAppWidgetViewDataChanged', () async {
      final res = await genList();
      const prov =
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/ListWProvider.kt';
      final kt = res.file(prov);
      expect(kt, contains('setRemoteAdapter'));
      expect(kt, contains('R.id.hw_list_items'));
      expect(kt, contains('MosaicListService'));
      expect(kt, contains('notifyAppWidgetViewDataChanged'));
    });

    test('generated res XML stays AAPT-valid', () async {
      final res = await genList();
      expect(res.firstNonXmlDeclFile(), isNull);
    });
  });
}

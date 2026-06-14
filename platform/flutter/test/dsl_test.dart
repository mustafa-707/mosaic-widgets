import 'package:mosaic_widgets/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MColor.hex stays backward compatible', () {
    expect(const MColor.hex('#FFF').toJson(), {'hex': '#FFF', 'dark': null, 'opacity': 1.0});
  });
  test('MColor.hex with dark variant', () {
    expect(const MColor.hex('#FFF', dark: '#000').toJson(),
        {'hex': '#FFF', 'dark': '#000', 'opacity': 1.0});
  });
  test('MColor.bind emits bind form without hex', () {
    final j = const MColor.bind('accent').toJson();
    expect(j['bind'], 'accent');
    expect(j.containsKey('hex'), isFalse);
  });
  test('MText carries format name', () {
    expect(MText(MBind('price'), format: MFormat.currency).toJson()['format'], 'currency');
    expect(MText('x').toJson()['format'], isNull);
  });
}

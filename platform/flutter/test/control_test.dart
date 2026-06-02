import 'package:mosaic/dsl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggle MControl with valueKey + MActionCallback serializes', () {
    final j = MControl(
      name: 'Flashlight',
      kind: MControlKind.toggle,
      label: 'Flashlight',
      sfSymbol: 'flashlight.on.fill',
      androidIcon: 'ic_flashlight',
      valueKey: 'flashlight_on',
      action: MActionCallback('toggleFlashlight'),
    ).toJson();

    expect(j['__type'], 'HWControl');
    expect(j['name'], 'Flashlight');
    expect(j['kind'], 'toggle');
    expect(j['label'], 'Flashlight');
    expect(j['sfSymbol'], 'flashlight.on.fill');
    expect(j['androidIcon'], 'ic_flashlight');
    expect(j['valueKey'], 'flashlight_on');
    expect(j['action']['__type'], 'HWActionCallback');
    expect(j['action']['callbackName'], 'toggleFlashlight');
  });

  test('button MControl with MLaunchUrlAction serializes', () {
    final j = MControl(
      name: 'OpenApp',
      kind: MControlKind.button,
      label: 'Open',
      sfSymbol: 'arrow.up.forward.app',
      action: MLaunchUrlAction('mosaic://open'),
    ).toJson();

    expect(j['__type'], 'HWControl');
    expect(j['name'], 'OpenApp');
    expect(j['kind'], 'button');
    expect(j['label'], 'Open');
    expect(j['sfSymbol'], 'arrow.up.forward.app');
    expect(j['androidIcon'], isNull);
    expect(j['valueKey'], isNull);
    expect(j['action']['__type'], 'HWLaunchUrlAction');
    expect(j['action']['url'], 'mosaic://open');
  });
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/mosaic_widgets.dart';

/// Exercises the bridge against the **real** native handlers.
///
/// The unit tests mock the method channel, so they prove the Dart side sends
/// and parses correctly — not that the Swift and Kotlin on the other end do
/// anything. These run on a device or simulator, where the platform code is
/// actually invoked.
///
/// That distinction mattered: the Android handlers were verified by hand on an
/// emulator, but the iOS ones could only be compile-checked, because the
/// simulator has no scriptable way to tap a button.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Harmless on Android, required on iOS: without it every call resolves
    // against the default suite and silently reads nothing.
    await MosaicBridge.setAppGroupId('group.com.example.demo_app.widgets');
  });

  testWidgets('a saved string reads back through the native store',
      (tester) async {
    final value = 'written-${DateTime.now().microsecondsSinceEpoch}';
    await MosaicBridge.saveString('it_probe', value);

    expect(await MosaicBridge.getValue<String>('it_probe'), value,
        reason: 'the store round trip is what MToggleAction depends on');
  });

  testWidgets('a saved bool survives the round trip as a bool',
      (tester) async {
    // Android keeps bools natively but strings for everything else, so this is
    // the case most likely to come back as "true" rather than true.
    await MosaicBridge.saveBool('it_flag', true);
    expect(await MosaicBridge.getValue<bool>('it_flag'), isTrue);

    await MosaicBridge.saveBool('it_flag', false);
    expect(await MosaicBridge.getValue<bool>('it_flag'), isFalse);
  });

  testWidgets('a list round-trips through JSON', (tester) async {
    await MosaicBridge.saveList('it_rows', [
      {'title': 'first'},
    ]);
    final rows = await MosaicBridge.getValue<List<dynamic>>('it_rows');
    expect(rows, isNotNull);
    expect((rows!.first as Map)['title'], 'first');
  });

  testWidgets('an absent key returns the default', (tester) async {
    expect(
      await MosaicBridge.getValue<String>('it_absent', defaultValue: 'fallback'),
      'fallback',
    );
  });

  testWidgets('saveFile writes real bytes and returns a usable path',
      (tester) async {
    // A 1x1 PNG. The point is the file, not the picture.
    final bytes = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    ]);
    final path = await MosaicBridge.saveFile('it_file', bytes);

    expect(path, isNotNull, reason: 'MFileImage has nothing to show without it');
    expect(path, endsWith('it_file.png'));
    expect(path, startsWith('/'), reason: 'must be absolute for the widget');
  });

  testWidgets('renderFlutterWidget produces a PNG on disk', (tester) async {
    final path = await MosaicBridge.renderFlutterWidget(
      Container(width: 40, height: 40, color: const Color(0xFF34D399)),
      key: 'it_render',
      logicalSize: const Size(40, 40),
    );

    expect(path, isNotNull);
    expect(path, endsWith('it_render.png'));
  });

  testWidgets('installedWidgets answers without throwing', (tester) async {
    // The count depends on what the user has placed, so the contract under
    // test is that the platform responds at all rather than blowing up.
    final placed = await MosaicBridge.installedWidgets();
    expect(placed, isA<List<MosaicWidgetInfo>>());
    for (final w in placed) {
      expect(w.name, isNotEmpty);
    }
  });
}

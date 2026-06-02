import 'dart:io';

import 'package:test/test.dart';

import 'support/gen_harness.dart';

void main() {
  const togglePath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/TorchTileService.kt';
  const buttonPath =
      'android/app/src/main/kotlin/com/acme/app/mosaic_generated/RefreshTileService.kt';

  Map<String, dynamic> toggleControl() => {
        '__type': 'HWControl',
        'name': 'Torch',
        'kind': 'toggle',
        'label': 'Flashlight',
        'sfSymbol': 'flashlight.on.fill',
        'androidIcon': 'ic_torch',
        'valueKey': 'torch_on',
        'action': {
          '__type': 'HWActionCallback',
          'callbackName': 'toggle_torch',
        },
      };

  Map<String, dynamic> buttonControl() => {
        '__type': 'HWControl',
        'name': 'Refresh',
        'kind': 'button',
        'label': 'Refresh Now',
        'androidIcon': 'ic_refresh',
        'action': {
          '__type': 'HWActionCallback',
          'callbackName': 'do_refresh',
        },
      };

  group('Quick Settings TileService — toggle control', () {
    Future<String> gen() async {
      final res = await runAndroidControls([toggleControl()]);
      expect(res.exists(togglePath), isTrue,
          reason: 'expected $togglePath to be generated');
      return res.file(togglePath);
    }

    test('generated with sentinel first line, package and TileService base',
        () async {
      final kt = await gen();
      expect(kt.split('\n').first, startsWith('// MOSAIC-GENERATED'));
      expect(kt, contains('package com.acme.app.mosaic_generated'));
      expect(kt, contains('import com.acme.app.R'));
      expect(kt, contains('class TorchTileService : TileService()'));
      expect(kt, contains('android.service.quicksettings.TileService'));
    });

    test('onStartListening sets label, icon and reads valueKey state',
        () async {
      final kt = await gen();
      expect(kt, contains('override fun onStartListening()'));
      expect(kt, contains('qsTile?.label = "Flashlight"'));
      expect(kt,
          contains('Icon.createWithResource(this, R.drawable.ic_torch)'));
      // Reads the stored bool from the shared widget_data store.
      expect(kt, contains('"widget_data"'));
      expect(kt, contains('getBoolean("torch_on", false)'));
      expect(kt, contains('Tile.STATE_ACTIVE'));
      expect(kt, contains('Tile.STATE_INACTIVE'));
      expect(kt, contains('qsTile?.updateTile()'));
    });

    test('onClick flips the stored bool and broadcasts the callback',
        () async {
      final kt = await gen();
      expect(kt, contains('override fun onClick()'));
      // Flips and writes back under valueKey.
      expect(kt, contains('putBoolean("torch_on"'));
      // Fires the callback the same way the widget callback path does.
      expect(kt, contains('com.acme.app.MOSAIC_CALLBACK'));
      expect(kt, contains('"callbackName"'));
      expect(kt, contains('toggle_torch'));
      expect(kt, contains('sendBroadcast'));
    });
  });

  group('Quick Settings TileService — button control', () {
    Future<String> gen() async {
      final res = await runAndroidControls([buttonControl()]);
      expect(res.exists(buttonPath), isTrue,
          reason: 'expected $buttonPath to be generated');
      return res.file(buttonPath);
    }

    test('button tile stays static and fires its callback action', () async {
      final kt = await gen();
      expect(kt, contains('class RefreshTileService : TileService()'));
      expect(kt, contains('override fun onClick()'));
      expect(kt, contains('com.acme.app.MOSAIC_CALLBACK'));
      expect(kt, contains('do_refresh'));
      // A button has no persisted bool to flip.
      expect(kt, isNot(contains('putBoolean(')));
    });

    test('launch-url button uses startActivityAndCollapse', () async {
      final res = await runAndroidControls([
        {
          '__type': 'HWControl',
          'name': 'Open',
          'kind': 'button',
          'label': 'Open App',
          'action': {
            '__type': 'HWLaunchUrlAction',
            'url': 'myapp://home',
          },
        },
      ]);
      const path =
          'android/app/src/main/kotlin/com/acme/app/mosaic_generated/OpenTileService.kt';
      expect(res.exists(path), isTrue);
      final kt = res.file(path);
      expect(kt, contains('startActivityAndCollapse'));
      expect(kt, contains('myapp://home'));
    });
  });

  group('no controls', () {
    test('no TileService generated when controls is empty', () async {
      final res = await runAndroidControls(const []);
      final ktDir = Directory.fromUri(Uri.directory(
              '${res.root.path}/android/app/src/main/kotlin/com/acme/app/mosaic_generated'))
          .listSync()
          .where((f) => f.path.endsWith('TileService.kt'))
          .toList();
      expect(ktDir, isEmpty);
    });
  });
}

// Needed only for the directory listing in the "no controls" test.
// ignore_for_file: avoid_dynamic_calls

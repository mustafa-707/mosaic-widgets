import 'package:test/test.dart';
import 'support/gen_harness.dart';

/// A toggle control fixture mirroring the IR shape the widget runner collects:
/// `{__type:'HWControl', name, kind, label, sfSymbol, androidIcon, valueKey,
///   action:{__type:'HWActionCallback', callbackName}}`.
Map<String, dynamic> torchToggle() => {
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

/// A button control fixture that fires a callback.
Map<String, dynamic> pingButton() => {
      '__type': 'HWControl',
      'name': 'Ping',
      'kind': 'button',
      'label': 'Ping Server',
      'sfSymbol': 'antenna.radiowaves.left.and.right',
      'androidIcon': 'ic_ping',
      'valueKey': null,
      'action': {
        '__type': 'HWActionCallback',
        'callbackName': 'ping_server',
      },
    };

void main() {
  group('iOS 18 Control Widget generation', () {
    test('toggle control emits <Name>Control.swift with ControlWidgetToggle',
        () async {
      final res = await runIos(const [], controls: [torchToggle()]);

      expect(
        res.exists('ios/HomeWidgetExtension/TorchControl.swift'),
        isTrue,
      );
      final swift = readFile(
          res.file('ios/HomeWidgetExtension/TorchControl.swift'));

      // Sentinel must be the first line.
      expect(swift.split('\n').first, contains('MOSAIC-GENERATED'));
      // Everything is iOS-18 gated.
      expect(swift, contains('@available(iOS 18.0, *)'));
      // Toggle control primitives.
      expect(swift, contains('ControlWidget'));
      expect(swift, contains('ControlWidgetToggle'));
      expect(swift, contains('isOn:'));
      // The current value is read from the App Group bool under the valueKey.
      expect(swift, contains('UserDefaults(suiteName:'));
      expect(swift, contains('bool(forKey: "torch_on")'));
      // Label uses the SF Symbol + label.
      expect(swift, contains('Label("Flashlight", systemImage: "flashlight.on.fill")'));
    });

    test('toggle control emits a SetValueIntent that writes the App Group bool',
        () async {
      final res = await runIos(const [], controls: [torchToggle()]);

      final intents = readFile(
          res.file('ios/HomeWidgetExtension/MosaicControlIntents.swift'));
      expect(intents.split('\n').first, contains('MOSAIC-GENERATED'));
      expect(intents, contains('@available(iOS 18.0, *)'));
      expect(intents, contains('SetValueIntent'));
      // perform() writes the bool under the valueKey into the suite.
      expect(intents, contains('set(value, forKey: "torch_on")'));
      // Reloads the control of this kind so Control Center re-renders.
      expect(intents, contains('reloadControls(ofKind:'));
    });

    test('button control emits <Name>Control.swift with ControlWidgetButton',
        () async {
      final res = await runIos(const [], controls: [pingButton()]);

      expect(
        res.exists('ios/HomeWidgetExtension/PingControl.swift'),
        isTrue,
      );
      final swift =
          readFile(res.file('ios/HomeWidgetExtension/PingControl.swift'));
      expect(swift.split('\n').first, contains('MOSAIC-GENERATED'));
      expect(swift, contains('@available(iOS 18.0, *)'));
      expect(swift, contains('ControlWidgetButton'));
      // The button reuses the callback intent path.
      expect(swift, contains('MosaicCallbackIntent(callbackName: "ping_server")'));
      expect(swift, contains(
          'Label("Ping Server", systemImage: "antenna.radiowaves.left.and.right")'));
    });

    test('bundle registers controls under an iOS 18 gate', () async {
      final res = await runIos(
        const [],
        controls: [torchToggle(), pingButton()],
      );
      final bundle = readFile(
          res.file('ios/HomeWidgetExtension/HomeWidgetBundle.swift'));
      expect(bundle, contains('if #available(iOS 18.0, *)'));
      expect(bundle, contains('TorchControl()'));
      expect(bundle, contains('PingControl()'));
    });

    test('no control files emitted when there are no controls', () async {
      final res = await runIos(const [], controls: const []);
      expect(
        res.exists('ios/HomeWidgetExtension/MosaicControlIntents.swift'),
        isFalse,
      );
    });

    test('user strings are swift-escaped', () async {
      final res = await runIos(const [], controls: [
        {
          '__type': 'HWControl',
          'name': 'Quote',
          'kind': 'toggle',
          'label': 'Say "hi"',
          'sfSymbol': 'quote.bubble',
          'androidIcon': null,
          'valueKey': 'q_on',
          'action': {
            '__type': 'HWActionCallback',
            'callbackName': 'say_"hi"',
          },
        }
      ]);
      final swift =
          readFile(res.file('ios/HomeWidgetExtension/QuoteControl.swift'));
      // The literal double-quote must be backslash-escaped in the Swift source.
      expect(swift, contains(r'Say \"hi\"'));
    });
  });
}

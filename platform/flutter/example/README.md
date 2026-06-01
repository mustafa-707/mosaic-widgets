# mosaic example

A minimal, self-contained example of the [`mosaic`](https://pub.dev/packages/mosaic) package.

For a full working app with multiple widgets, Live Activities, real API calls, and both
iOS and Android wiring, see the
[demo app](https://github.com/your-org/mosaic/tree/main/examples/demo_app).

## Minimal widget definition

```dart
import 'package:mosaic/dsl.dart';

MosaicDefinition buildExampleWidget() {
  return MosaicDefinition(
    name: 'ExampleWidget',
    width: 2,
    height: 2,
    root: MContainer(
      background: const MColor.hex('#1E3A8A'),
      radius: 16,
      child: MPadding(
        const MInsets.all(12),
        MColumn([
          const MText(
            'Hello Mosaic',
            style: MTextStyle(
              color: MColor.hex('#FFFFFF'),
              size: 14,
              bold: true,
            ),
          ),
          MText(MBind('subtitle')),
        ]),
      ),
    ),
  );
}
```

## Pushing data from the app

```dart
import 'package:mosaic/mosaic.dart';

await MosaicBridge.setAppGroupId('group.com.example.myapp.widgets');
await MosaicBridge.saveString('subtitle', 'Live from Flutter!');
await MosaicBridge.refreshAll();
```

## Running

```bash
cd example
flutter pub get
flutter run
```

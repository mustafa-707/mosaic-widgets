import 'package:mosaic_widgets/dsl.dart';

/// A Control Center / Quick Settings toggle. Tapping flips the shared
/// `torch_on` bool and fires the `toggle_torch` background callback.
MControl buildTorch() => const MControl(
      name: 'Torch',
      kind: MControlKind.toggle,
      label: 'Flashlight',
      sfSymbol: 'flashlight.on.fill',
      valueKey: 'torch_on',
      action: MActionCallback('toggle_torch'),
    );

import 'package:mosaic_widgets/dsl.dart';

/// A one-cell flashlight toggle.
///
/// The smallest useful widget shape: one tap target, state legible without
/// reading. `MToggleAction` flips the shared `torch_on` bool **on-device**, so
/// it works with the app closed — the point of a torch you reach from the home
/// screen. The same key backs the Control Center / Quick Settings tile in
/// `controls/torch.control.dart`, so the two never disagree.
///
/// Both states fill the whole cell and share one layout, so toggling changes
/// only colour — the tile never resizes or shifts under your thumb.
MosaicDefinition buildFlashlight() => MosaicDefinition(
  name: 'Flashlight',
  width: 1,
  height: 1,
  root: MButton(
    action: const MToggleAction('torch_on'),
    child: MVisibility(
      bind: const MBind('torch_on'),
      child: _face(
        // Lit: warm amber, the colour of the beam itself.
        gradient: const MLinearGradient(
          colors: [MColor.hex('#FDE047'), MColor.hex('#F59E0B')],
          angle: 135,
        ),
        halo: const MColor.hex('#FFFFFF', opacity: 0.28),
        icon: const MColor.hex('#422006'),
        label: const MColor.hex('#422006', opacity: 0.75),
        symbol: 'flashlight.on.fill',
        drawable: 'ic_flash_on',
        text: 'ON',
        semantics: 'Flashlight on, tap to turn off',
      ),
      // Dark: the same shape at rest, so the cell never looks empty.
      replacement: _face(
        gradient: const MLinearGradient(
          colors: [MColor.hex('#334155'), MColor.hex('#1E293B')],
          angle: 135,
        ),
        halo: const MColor.hex('#FFFFFF', opacity: 0.06),
        icon: const MColor.hex('#94A3B8'),
        label: const MColor.hex('#64748B'),
        symbol: 'flashlight.off.fill',
        drawable: 'ic_flash_off',
        text: 'OFF',
        semantics: 'Flashlight off, tap to turn on',
      ),
    ),
  ),
);

/// One state of the tile. Both states share this shape so only colour differs.
MNode _face({
  required MLinearGradient gradient,
  required MColor halo,
  required MColor icon,
  required MColor label,
  required String symbol,
  required String drawable,
  required String text,
  required String semantics,
}) => MSemantics(
  label: semantics,
  // The glyph carries the meaning; announcing "ON" separately reads as noise.
  excludeChildren: true,
  child: MContainer(
    gradient: gradient,
    // Matches the launcher's own tile curvature rather than a circle floating
    // inside a square cell.
    radius: 22,
    child: MStack([
      // A corner highlight, bled off the top-left so only a quarter shows.
      //
      // Sized deliberately small: RemoteViews cannot blur, so a translucent
      // disc has a hard edge. At 92dp it covered most of a 1x1 tile and drew a
      // visible diagonal band straight through the glyph. Kept to a corner it
      // reads as a highlight instead of a shape.
      MPositioned(
        top: -34,
        left: -34,
        child: MContainer(
          width: 64,
          height: 64,
          radius: 32,
          background: halo,
          child: const MSpacer(),
        ),
      ),
      MCenter(
        child: MColumn(
          mainAxisAlignment: MMainAxisAlignment.center,
          crossAxisAlignment: MCrossAxisAlignment.center,
          [
            MIcon(
              sfSymbol: symbol,
              androidDrawable: drawable,
              size: 32,
              color: icon,
            ),
            const MSizedBox.height(6),
            MText(
              text,
              align: MTextAlign.center,
              style: MTextStyle(color: label, size: 10, bold: true),
            ),
          ],
        ),
      ),
    ]),
  ),
);

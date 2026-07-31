import 'package:mosaic_widgets/dsl.dart';

// Values are stored raw (no suffix) by both the app and the widget's own
// refresh, so the unit symbol is rendered here instead.
const _tempStyle = MTextStyle(
  color: MColor.hex('#FFFFFF'),
  bold: true,
  size: 28,
);

const _unitStyle = MTextStyle(
  color: MColor.hex('#FFFFFF'),
  bold: true,
  size: 14,
);


const _rangeStyle = MTextStyle(color: MColor.hex('#DCEBFB'), size: 12);

/// "H:18°  L:11°" from two bound values.
MNode _rangeLine(MBind hi, MBind lo) => MRow([
  const MText('H:', style: _rangeStyle),
  MText(hi, style: _rangeStyle),
  const MText('°   L:', style: _rangeStyle),
  MText(lo, style: _rangeStyle),
  const MText('°', style: _rangeStyle),
]);

MosaicDefinition buildWeather() => MosaicDefinition(
  name: 'Weather',
  width: 2,
  height: 2,
  root: MContainer(
    background: const MColor.hex('#4A90D9', dark: '#1C3D5A'),
    radius: 20,
    // Inside the background, like Flutter's Container(padding:) — no
    // nested MPadding needed.
    padding: const MInsets.all(14),
    child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
      // City and condition share the header row, so the icon uses width that
      // was previously dead space rather than floating in its own band.
      MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
        const MText(
          'San Francisco',
          // Without a limit SwiftUI wraps rather than shrinks, so on a narrower
          // iOS systemMedium the city broke to two lines and shoved the
          // temperature down — while the wider Android cell fit it on one and
          // looked fine. A header in a Row wants an explicit limit.
          maxLines: 1,
          style: MTextStyle(color: MColor.hex('#FFFFFF'), bold: true, size: 14),
        ),
        const MIcon(
          sfSymbol: 'cloud.sun.fill',
          androidDrawable: 'ic_weather',
          size: 26,
          color: MColor.hex('#FFD700'),
        ),
      ]),
      const MSpacer(),
      // Current temperature — the one thing read at a glance, so it gets the
      // most weight. The unit is in-widget state: MToggleAction flips
      // `weather_unit_f` and this picks the matching key, so switching needs
      // no network round-trip.
      MVisibility(
        bind: MBind('weather_unit_f'),
        child: MRow([
          MText(MBind('temp_f'), style: _tempStyle),
          const MText('°F', style: _unitStyle),
        ]),
        replacement: MRow([
          MText(MBind('temp_c'), style: _tempStyle),
          const MText('°C', style: _unitStyle),
        ]),
      ),
      const MSizedBox.height(2),
      // Today's range, in whichever unit is selected. Built from raw bindings
      // rather than one preformatted string, because the in-widget refresh
      // maps JSON paths to keys 1:1 and could not compose a sentence — the
      // range would have gone stale whenever the widget refreshed itself.
      MVisibility(
        bind: MBind('weather_unit_f'),
        child: _rangeLine(MBind('hi_f'), MBind('lo_f')),
        replacement: _rangeLine(MBind('hi_c'), MBind('lo_c')),
      ),
      const MSpacer(),
      MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
        // Fetches both units natively — works with the app closed.
        // Mosaic sets `mosaic_refreshing` around the fetch, so the
        // icon swaps to a spinner while the request is in flight.
        MButton(
          action: const MActionCallback('refresh_weather'),
          child: MContainer(
            background: const MColor.hex('#FFFFFF', opacity: 0.2),
            radius: 8,
            child: MPadding(
              const MInsets.symmetric(vertical: 4, horizontal: 8),
              MVisibility(
                bind: MBind('mosaic_refreshing'),
                child: const MActivityIndicator(
                  size: 14,
                  color: MColor.hex('#FFFFFF'),
                ),
                replacement: const MIcon(
                  sfSymbol: 'arrow.clockwise',
                  androidDrawable: 'ic_refresh',
                  size: 14,
                  color: MColor.hex('#FFFFFF'),
                ),
              ),
            ),
          ),
        ),
        // Flips the unit in place — no app launch, no network.
        MButton(
          action: const MToggleAction('weather_unit_f'),
          child: MContainer(
            background: const MColor.hex('#FFFFFF', opacity: 0.2),
            radius: 8,
            child: const MPadding(
              MInsets.symmetric(vertical: 4, horizontal: 8),
              MText(
                '°C / °F',
                style: MTextStyle(
                  color: MColor.hex('#FFFFFF'),
                  bold: true,
                  size: 12,
                ),
              ),
            ),
          ),
        ),
      ]),
    ]),
  ),
);

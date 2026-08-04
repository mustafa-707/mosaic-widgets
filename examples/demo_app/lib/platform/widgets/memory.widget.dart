import 'package:mosaic_widgets/dsl.dart';

/// RAM gauge with a one-tap cleanup, in the style of a system memory panel.
///
/// Every number here is read **natively in the widget process** via
/// `MDeviceValue`, so the figures are current even if the app has not run for
/// days — the same source the system settings screen reports.
///
/// Tapping *Optimize* fires the `clear_ram` background callback. While it runs,
/// `mosaic_refreshing` is true and the spinner replaces the button, so the tap
/// visibly does something instead of appearing dead.
MosaicDefinition buildMemory() => MosaicDefinition(
  name: 'Memory',
  width: 2,
  height: 2,
  resizeMode: MResizeMode.both,
  root: MContainer(
    gradient: const MLinearGradient(
      colors: [MColor.hex('#111827'), MColor.hex('#1F2937')],
    ),
    radius: 24,
    child: MPadding(
      const MInsets.all(14),
      // spaceBetween spread four short rows to the tile's extremes and left
      // holes between them. Packed to the top with explicit gaps instead, so
      // the spacing is deliberate rather than whatever was left over.
      MColumn(
        mainAxisAlignment: MMainAxisAlignment.start,
        crossAxisAlignment: MCrossAxisAlignment.start,
        [
          MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
            MText(
              'USED',
              style: MTextStyle(
                bold: true,
                size: 9,
                color: MColor.system(
                  MSystemColor.accent,
                  fallback: '#34D399',
                ),
              ),
            ),
            // Bound to the same flag the provider sets around the callback.
            MVisibility(
              bind: const MBind('mosaic_refreshing'),
              child: const MActivityIndicator(size: 12),
              replacement: MRow([
                MText(
                  MDeviceValue(MDeviceMetric.memoryUsedPercent),
                  format: MFormat.decimal,
                  style: const MTextStyle(
                    size: 9,
                    bold: true,
                    color: MColor.hex('#94A3B8'),
                  ),
                ),
                const MText(
                  '%',
                  style: MTextStyle(size: 9, color: MColor.hex('#64748B')),
                ),
              ]),
            ),
          ]),

          const MSizedBox.height(8),

          // The headline figure, in the units a memory panel uses.
          MSemantics(
            label: 'Free memory',
            excludeChildren: true,
            child: MRow(crossAxisAlignment: MCrossAxisAlignment.end, [
              MText(
                MDeviceValue(MDeviceMetric.memoryFreeMb),
                format: MFormat.decimal,
                style: const MTextStyle(
                  size: 30,
                  bold: true,
                  color: MColor.hex('#FFFFFF'),
                ),
              ),
              const MPadding(
                MInsets.only(left: 3, bottom: 5),
                MText(
                  'MB free',
                  style: MTextStyle(size: 11, color: MColor.hex('#94A3B8')),
                ),
              ),
            ]),
          ),

          const MSizedBox.height(8),

          // Used share of total. The bar is the "same as the OS" read: how
          // full the device is right now.
          MSemantics(
            label: 'Memory in use',
            child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
              MProgressBar(
                value: MDeviceValue(MDeviceMetric.memoryUsedPercent),
                max: 100.0,
                color: const MColor.hex('#34D399'),
              ),
              const MSizedBox.height(5),
              MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                const MText(
                  'in use',
                  style: MTextStyle(size: 10, color: MColor.hex('#64748B')),
                ),
                MRow([
                  MText(
                    MDeviceValue(MDeviceMetric.memoryTotalMb),
                    format: MFormat.decimal,
                    style: const MTextStyle(
                      size: 10,
                      color: MColor.hex('#94A3B8'),
                    ),
                  ),
                  const MText(
                    ' MB total',
                    style: MTextStyle(size: 10, color: MColor.hex('#64748B')),
                  ),
                ]),
              ]),
            ]),
          ),

          const MSizedBox.height(8),

          // Escape hatch: SwiftUI's Gauge has no DSL node, and RemoteViews has
          // no gauge at all — so iOS gets the real control and Android a plain
          // line of text. Mosaic still wires the data.
          MRaw(
            swift:
                'Gauge(value: (mosaicNum(entry.data["mosaic_memory_used_percent"]) ?? 0) / 100.0) '
                '{ EmptyView() }.gaugeStyle(.accessoryLinearCapacity).tint(.green)',
            androidXml:
                '<TextView android:layout_width="wrap_content" '
                'android:layout_height="wrap_content" '
                'android:text="RAM" android:textSize="9sp" '
                'android:textColor="#64748B" />',
            binds: const ['mosaic_memory_used_percent'],
          ),

          const MSizedBox.height(8),

          // Swaps to a spinner mid-run rather than sitting there looking inert.
          MVisibility(
            bind: const MBind('mosaic_refreshing'),
            child: MContainer(
              background: const MColor.hex('#1F2937'),
              radius: 8,
              border: const MBorder(color: MColor.hex('#374151'), width: 1),
              child: const MPadding(
                MInsets.symmetric(horizontal: 10, vertical: 7),
                MCenter(child: MActivityIndicator(size: 14)),
              ),
            ),
            replacement: MButton(
              action: const MActionCallback('clear_ram'),
              child: MContainer(
                background: const MColor.hex('#34D399'),
                radius: 8,
                child: const MPadding(
                  MInsets.symmetric(horizontal: 10, vertical: 6),
                  MCenter(
                    child: MText(
                      'Optimize',
                      style: MTextStyle(
                        color: MColor.hex('#06281D'),
                        size: 11,
                        bold: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

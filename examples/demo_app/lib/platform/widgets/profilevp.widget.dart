import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition buildProfileVP() {
  return MosaicDefinition(
    name: "ProfileVP",
    width: 2,
    height: 2,
    resizeMode: MResizeMode.both,
    // A 2x2 tile cannot hold the four sections below — at systemSmall the
    // labels collide and the buttons clip. The compact tree keeps the one
    // number a glanceable tile is for, and drops the rest.
    compactRoot: MContainer(
      gradient: const MLinearGradient(
        colors: [MColor.hex("#0F172A"), MColor.hex("#1E293B")],
      ),
      radius: 28,
      border: const MBorder(color: MColor.hex("#334155"), width: 1.5),
      child: MPadding(
        const MInsets.all(14),
        // Centred, not spaceBetween. The OS picks the tile's height, so
        // spaceBetween pushed the label to the top, the number to the middle
        // and the bar to the floor with dead space between — see the same fix
        // in the medium tree below.
        MColumn(
          mainAxisAlignment: MMainAxisAlignment.center,
          crossAxisAlignment: MCrossAxisAlignment.start,
          [
            MText(
              "BATTERY",
              style: MTextStyle(
                bold: true,
                size: 9,
                color: MColor.hex("#38BDF8"),
              ),
            ),
            MSemantics(
              label: "Battery level",
              child: MRow(crossAxisAlignment: MCrossAxisAlignment.end, [
                MText(
                  MDeviceValue(MDeviceMetric.batteryLevel),
                  style: MTextStyle(
                    size: 34,
                    bold: true,
                    color: MColor.hex("#FFFFFF"),
                  ),
                ),
                MPadding(
                  const MInsets.only(left: 2, bottom: 5),
                  MText(
                    "%",
                    style: MTextStyle(size: 13, color: MColor.hex("#94A3B8")),
                  ),
                ),
              ]),
            ),
            MProgressBar(
              value: MDeviceValue(MDeviceMetric.batteryLevel),
              max: 100.0,
              color: MColor.hex("#38BDF8"),
            ),
          ],
        ),
      ),
    ),
    root: MContainer(
      gradient: const MLinearGradient(
        colors: [
          MColor.hex("#0F172A"),
          MColor.hex("#1E293B"),
        ], // Slate-900 to Slate-800
      ),
      radius: 28,
      border: const MBorder(color: MColor.hex("#334155"), width: 1.5),
      child: MStack([
        // Top right decorative circle
        const MPositioned(
          top: -20,
          right: -20,
          child: MContainer(
            width: 80,
            height: 80,
            radius: 40,
            background: MColor.hex("#38BDF8", opacity: 0.1),
            child: MSpacer(),
          ),
        ),

        // Compact layout for systemSmall
        MPadding(
          const MInsets.all(12),
          // Packed from the top with deliberate gaps. spaceBetween distributed
          // whatever height the family happened to have, so the same tree left
          // a hole under the battery row on iOS medium and looked correct on a
          // 2x2 Android cell.
          MColumn(
            mainAxisAlignment: MMainAxisAlignment.start,
            crossAxisAlignment: MCrossAxisAlignment.start,
            [
              // 1. Header
              MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                  MText(
                    "SYSTEM STATUS",
                    style: MTextStyle(
                      bold: true,
                      size: 9, // Smaller font
                      color: MColor.hex("#38BDF8"),
                    ),
                  ),
                  MText(
                    MBind("system_status"),
                    style: MTextStyle(
                      bold: true,
                      size: 12,
                      color: MColor.hex("#FFFFFF"),
                    ),
                  ),
                ]),
                MContainer(
                  width: 24, // Smaller icon
                  height: 24,
                  radius: 12,
                  background: MColor.hex("#38BDF8"),
                  child: MCenter(
                    child: MIcon(
                      sfSymbol: "bolt.fill",
                      androidDrawable: "ic_lightning",
                      size: 12,
                      color: MColor.hex("#FFFFFF"),
                    ),
                  ),
                ),
              ]),

              const MSizedBox.height(10),

              // 2. Battery
              // Screen readers would otherwise announce "Battery 71 %" as
              // separate fragments, and the bar as an unlabelled control.
              // Static label: the value itself is announced by the children
              // below, so this only supplies the context they lack.
              MSemantics(
                label: "Battery level",
                // The number, the "%" and the bar read as three unrelated
                // fragments one by one; collapsed, it announces once.
                excludeChildren: true,
                child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                  MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                    MText(
                      "Battery",
                      style: MTextStyle(size: 12, color: MColor.hex("#94A3B8")),
                    ),
                    MRow([
                      MText(
                        MDeviceValue(MDeviceMetric.batteryLevel),
                        style: MTextStyle(
                          size: 14,
                          bold: true,
                          color: MColor.hex("#FFFFFF"),
                        ),
                      ),
                      MText(
                        "%",
                        style: MTextStyle(
                          size: 10,
                          color: MColor.hex("#94A3B8"),
                        ),
                      ),
                    ]),
                  ]),
                  const MSizedBox.height(4),
                  MProgressBar(
                    value: MDeviceValue(MDeviceMetric.batteryLevel),
                    max: 100.0,
                    color: MColor.hex("#38BDF8"),
                  ),
                  const MSizedBox.height(4),
                ]),
              ),

              const MSizedBox.height(10),

              // 3. Free storage — read natively, like the battery above.
              //    The 7-day trend replaces a static progress bar here: the
              //    "8.3 GB" beside it already states today's value, so bars
              //    showing how it moved are the only thing a chart adds.
              MSemantics(
                label: "Free storage, last 7 days",
                child: MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                  MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                    MText(
                      "Free",
                      style: MTextStyle(size: 12, color: MColor.hex("#94A3B8")),
                    ),
                    MRow([
                      MText(
                        MDeviceValue(MDeviceMetric.storageFreeGb),
                        style: MTextStyle(
                          size: 14,
                          bold: true,
                          color: MColor.hex("#FFFFFF"),
                        ),
                      ),
                      MText(
                        "GB",
                        style: MTextStyle(
                          size: 10,
                          color: MColor.hex("#94A3B8"),
                        ),
                      ),
                    ]),
                  ]),
                  const MSizedBox.height(6),
                  MSizedBox(
                    height: 22,
                    child: MBarChart(
                      bind: MBind('storage_week'),
                      color: const MColor.hex('#22C55E'),
                      spacing: 3,
                      radius: 2,
                    ),
                  ),
                ]),
              ),
              const MSizedBox.height(10),

              // 4. Buttons
              // Both actions share the width equally, so neither gets
              // clipped as the widget resizes. Android honours the
              // weight exactly; on iOS the siblings split it evenly.
              MRow([
                MFlexible(
                  child: MButton(
                    action: MLaunchUrlAction("hwdemo://profile/details"),
                    child: MContainer(
                      background: MColor.hex("#1E293B"),
                      radius: 8,
                      border: MBorder(color: MColor.hex("#334155"), width: 1),
                      child: MPadding(
                        MInsets.symmetric(horizontal: 8, vertical: 6),
                        MText(
                          "Details",
                          style: MTextStyle(
                            color: MColor.hex("#FFFFFF"),
                            size: 10,
                            bold: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const MSizedBox.width(8),
                MFlexible(
                  child: MButton(
                    action: const MRefreshAction(),
                    child: MContainer(
                      background: MColor.hex("#38BDF8"),
                      radius: 8,
                      child: MPadding(
                        MInsets.symmetric(horizontal: 8, vertical: 6),
                        MText(
                          "Refresh",
                          style: MTextStyle(
                            color: MColor.hex("#0F172A"),
                            size: 10,
                            bold: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    ),
  );
}

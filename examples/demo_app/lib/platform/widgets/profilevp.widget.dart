import 'package:mosaic/mosaic.dart';

MosaicDefinition buildProfileVP() {
  return MosaicDefinition(
    name: "ProfileVP",
    width: 2,
    height: 2,
    resizeMode: MResizeMode.both,
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
          MColumn(
            mainAxisAlignment: MMainAxisAlignment.spaceBetween,
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
                    child: MText("⚡", style: MTextStyle(size: 12)),
                  ),
                ),
              ]),

              // 2. Battery
              MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                  MText(
                    "Battery",
                    style: MTextStyle(size: 12, color: MColor.hex("#94A3B8")),
                  ),
                  MRow([
                    MText(
                      MBind("battery_level"),
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
                MPadding(
                  MInsets.only(top: 4, bottom: 4),
                  MProgressBar(
                    value: MBind("battery_progress"),
                    max: 100.0,
                    color: MColor.hex("#38BDF8"),
                  ),
                ),
              ]),

              // 3. Memory
              MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                  MText(
                    "Memory",
                    style: MTextStyle(size: 12, color: MColor.hex("#94A3B8")),
                  ),
                  MRow([
                    MText(
                      MBind("memory_usage"),
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
                MPadding(
                  MInsets.only(top: 4, bottom: 4),
                  MProgressBar(
                    value: MBind("memory_progress"),
                    max: 100.0,
                    color: MColor.hex("#22C55E"),
                  ),
                ),
              ]),

              // 4. Buttons
              MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                MButton(
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
                MButton(
                  action: MRefreshAction(),
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
              ]),
            ],
          ),
        ),
      ]),
    ),
  );
}

import 'package:hw_flutter/hw_dsl.dart';

HWDefinition buildProfileVP() {
  return HWDefinition(
    name: "ProfileVP",
    width: 2,
    height: 2,
    resizeMode: HWResizeMode.both,
    root: HWContainer(
      gradient: const HWLinearGradient(
        colors: [
          HWColor.hex("#0F172A"),
          HWColor.hex("#1E293B"),
        ], // Slate-900 to Slate-800
      ),
      radius: 28,
      border: const HWBorder(color: HWColor.hex("#334155"), width: 1.5),
      child: HWStack([
        // Top right decorative circle
        const HWPositioned(
          top: -20,
          right: -20,
          child: HWContainer(
            width: 80,
            height: 80,
            radius: 40,
            background: HWColor.hex("#38BDF8", opacity: 0.1),
            child: HWSpacer(),
          ),
        ),

        // Compact layout for systemSmall
        HWPadding(
          const HWInsets.all(12),
          HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            crossAxisAlignment: HWCrossAxisAlignment.start,
            [
              // 1. Header
              HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                  HWText(
                    "SYSTEM STATUS",
                    style: HWTextStyle(
                      bold: true,
                      size: 9, // Smaller font
                      color: HWColor.hex("#38BDF8"),
                    ),
                  ),
                  HWText(
                    HWBind("system_status"),
                    style: HWTextStyle(
                      bold: true,
                      size: 12,
                      color: HWColor.hex("#FFFFFF"),
                    ),
                  ),
                ]),
                HWContainer(
                  width: 24, // Smaller icon
                  height: 24,
                  radius: 12,
                  background: HWColor.hex("#38BDF8"),
                  child: HWCenter(
                    child: HWText("⚡", style: HWTextStyle(size: 12)),
                  ),
                ),
              ]),

              // 2. Battery
              HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                  HWText(
                    "Battery",
                    style: HWTextStyle(size: 12, color: HWColor.hex("#94A3B8")),
                  ),
                  HWRow([
                    HWText(
                      HWBind("battery_level"),
                      style: HWTextStyle(
                        size: 14,
                        bold: true,
                        color: HWColor.hex("#FFFFFF"),
                      ),
                    ),
                    HWText(
                      "%",
                      style: HWTextStyle(
                        size: 10,
                        color: HWColor.hex("#94A3B8"),
                      ),
                    ),
                  ]),
                ]),
                HWPadding(
                  HWInsets.only(top: 4, bottom: 4),
                  HWProgressBar(
                    value: HWBind("battery_progress"),
                    max: 100.0,
                    color: HWColor.hex("#38BDF8"),
                  ),
                ),
              ]),

              // 3. Memory
              HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                  HWText(
                    "Memory",
                    style: HWTextStyle(size: 12, color: HWColor.hex("#94A3B8")),
                  ),
                  HWRow([
                    HWText(
                      HWBind("memory_usage"),
                      style: HWTextStyle(
                        size: 14,
                        bold: true,
                        color: HWColor.hex("#FFFFFF"),
                      ),
                    ),
                    HWText(
                      "GB",
                      style: HWTextStyle(
                        size: 10,
                        color: HWColor.hex("#94A3B8"),
                      ),
                    ),
                  ]),
                ]),
                HWPadding(
                  HWInsets.only(top: 4, bottom: 4),
                  HWProgressBar(
                    value: HWBind("memory_progress"),
                    max: 100.0,
                    color: HWColor.hex("#22C55E"),
                  ),
                ),
              ]),

              // 4. Buttons
              HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                HWButton(
                  action: HWLaunchUrlAction("hwdemo://profile/details"),
                  child: HWContainer(
                    background: HWColor.hex("#1E293B"),
                    radius: 8,
                    border: HWBorder(color: HWColor.hex("#334155"), width: 1),
                    child: HWPadding(
                      HWInsets.symmetric(horizontal: 8, vertical: 6),
                      HWText(
                        "Details",
                        style: HWTextStyle(
                          color: HWColor.hex("#FFFFFF"),
                          size: 10,
                          bold: true,
                        ),
                      ),
                    ),
                  ),
                ),
                HWButton(
                  action: HWRefreshAction(),
                  child: HWContainer(
                    background: HWColor.hex("#38BDF8"),
                    radius: 8,
                    child: HWPadding(
                      HWInsets.symmetric(horizontal: 8, vertical: 6),
                      HWText(
                        "Refresh",
                        style: HWTextStyle(
                          color: HWColor.hex("#0F172A"),
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

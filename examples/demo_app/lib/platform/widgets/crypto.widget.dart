import 'package:hw_flutter/hw_dsl.dart';

HWDefinition buildCryptoWidget() {
  return HWDefinition(
    name: "CryptoWidget",
    width: 2,
    height: 2,
    resizeMode: HWResizeMode.both,
    root: HWContainer(
      gradient: const HWLinearGradient(
        colors: [
          HWColor.hex("#2563EB"),
          HWColor.hex("#1E3A8A"),
        ], // Blue-600 to Blue-900
      ),
      radius: 24,
      child: HWStack([
        // Top right glow
        const HWPositioned(
          top: -30,
          right: -30,
          child: HWContainer(
            width: 100,
            height: 100,
            radius: 50,
            background: HWColor.hex("#FFFFFF", opacity: 0.1),
            child: HWSpacer(),
          ),
        ),

        // Compact layout
        HWPadding(
          const HWInsets.all(12),
          HWColumn(
            mainAxisAlignment: HWMainAxisAlignment.spaceBetween,
            crossAxisAlignment: HWCrossAxisAlignment.start,
            [
              // Header
              HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                  const HWText(
                    "BITCOIN",
                    style: HWTextStyle(
                      color: HWColor.hex("#93C5FD"),
                      size: 10,
                      bold: true,
                    ),
                  ),
                  const HWText(
                    "BTC/USD",
                    style: HWTextStyle(
                      color: HWColor.hex("#FFFFFF"),
                      size: 14,
                      bold: true,
                    ),
                  ),
                ]),
                const HWContainer(
                  width: 32,
                  height: 32,
                  radius: 8,
                  background: HWColor.hex("#FFFFFF", opacity: 0.2),
                  child: HWCenter(
                    child: HWText("₿", style: HWTextStyle(size: 18)),
                  ),
                ),
              ]),

              // Price Block
              HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                HWText(
                  HWBind("btc_price"),
                  // Use 20 to fit better
                  style: const HWTextStyle(
                    color: HWColor.hex("#FFFFFF"),
                    size: 20,
                    bold: true,
                  ),
                ),
                HWRow([
                  HWText(
                    HWBind("btc_change"),
                    style: const HWTextStyle(
                      color: HWColor.hex("#4ADE80"),
                      size: 12,
                      bold: true,
                    ),
                  ),
                  const HWPadding(
                    HWInsets.only(left: 4),
                    HWText(
                      "24h",
                      style: HWTextStyle(
                        color: HWColor.hex("#93C5FD"),
                        size: 12,
                      ),
                    ),
                  ),
                ]),
              ]),

              // Footer
              HWRow(mainAxisAlignment: HWMainAxisAlignment.spaceBetween, [
                const HWButton(
                  action: HWRefreshAction(),
                  child: HWContainer(
                    background: HWColor.hex("#FFFFFF", opacity: 0.1),
                    radius: 10,
                    child: HWPadding(
                      HWInsets.symmetric(horizontal: 12, vertical: 6),
                      HWText(
                        "Refresh",
                        style: HWTextStyle(
                          color: HWColor.hex("#FFFFFF"),
                          size: 10,
                          bold: true,
                        ),
                      ),
                    ),
                  ),
                ),
                // Compact Session Timer
                HWRow([
                  const HWText(
                    "LIVE: ",
                    style: HWTextStyle(
                      color: HWColor.hex("#93C5FD"),
                      size: 8,
                      bold: true,
                    ),
                  ),
                  HWTimer(
                    target: DateTime.now(),
                    countUp: true,
                    style: const HWTextStyle(
                      color: HWColor.hex("#FFFFFF"),
                      size: 8,
                    ),
                  ),
                ]),
              ]),
            ],
          ),
        ),
      ]),
    ),
  );
}

import 'package:mosaic_widgets/dsl.dart';

MosaicDefinition buildCryptoWidget() {
  return MosaicDefinition(
    name: "CryptoWidget",
    width: 2,
    height: 2,
    resizeMode: MResizeMode.both,
    // User-configurable parameters surfaced in the OS configuration UI. Each
    // chosen value is written into the shared store under its key and resolves
    // via MBind of the same name.
    params: const [
      MParam(
        key: "pair",
        label: "Trading Pair",
        type: MParamType.choice,
        defaultValue: "BTC/USD",
        choices: ["BTC/USD", "ETH/USD", "SOL/USD"],
      ),
      MParam(
        key: "label",
        label: "Custom Label",
        type: MParamType.text,
        defaultValue: "BITCOIN",
      ),
      MParam(
        key: "decimals",
        label: "Decimals",
        type: MParamType.number,
        defaultValue: 2,
      ),
      MParam(
        key: "compact",
        label: "Compact Mode",
        type: MParamType.toggle,
        defaultValue: false,
      ),
    ],
    root: MContainer(
      gradient: const MLinearGradient(
        colors: [
          MColor.hex("#2563EB"),
          MColor.hex("#1E3A8A"),
        ], // Blue-600 to Blue-900
      ),
      radius: 24,
      child: MStack([
        // Top right glow
        const MPositioned(
          top: -30,
          right: -30,
          child: MContainer(
            width: 100,
            height: 100,
            radius: 50,
            // Runtime-bound accent colour: the app pushes green or red for the
            // day's direction. Held at low opacity so it tints the corner
            // rather than competing with the price — at full strength it read
            // as a solid blob.
            background: MColor.bind("accent", opacity: 0.28),
            child: MSpacer(),
          ),
        ),

        // Compact layout
        MPadding(
          const MInsets.all(12),
          MColumn(
            mainAxisAlignment: MMainAxisAlignment.spaceBetween,
            crossAxisAlignment: MCrossAxisAlignment.start,
            [
              // Header
              MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                  const MText(
                    "BITCOIN",
                    style: MTextStyle(
                      color: MColor.hex("#93C5FD"),
                      size: 10,
                      bold: true,
                    ),
                  ),
                  const MText(
                    "BTC/USD",
                    // Adaptive color: white in light mode, soft grey in dark.
                    style: MTextStyle(
                      color: MColor.hex("#FFFFFF", dark: "#E5E7EB"),
                      size: 14,
                      bold: true,
                    ),
                  ),
                ]),
                const MContainer(
                  width: 32,
                  height: 32,
                  radius: 8,
                  background: MColor.hex("#FFFFFF", opacity: 0.2),
                  child: MCenter(
                    child: MIcon(
                      sfSymbol: "bitcoinsign",
                      androidDrawable: "ic_bitcoin",
                      size: 18,
                      color: MColor.hex("#FFFFFF"),
                    ),
                  ),
                ),
              ]),

              // Price Block
              MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                MText(
                  MBind("btc_price", defaultValue: "64000"),
                  // The pair is BTC/USD, so the amount is dollars regardless of
                  // where the phone is. Without the code it rendered in the
                  // device currency — "JOD 64,510.000" on a phone set to
                  // Jordan, relabelling the number without converting it.
                  format: MFormat.currency,
                  currencyCode: 'USD',
                  // Digits roll when the price changes (iOS 17+; a no-op on
                  // Android, which has no equivalent).
                  contentTransition: MContentTransition.numericText,
                  style: const MTextStyle(
                    color: MColor.hex("#FFFFFF"),
                    size: 20,
                    bold: true,
                  ),
                ),
                MRow([
                  MText(
                    MBind("btc_change"),
                    // The native refresh source writes CoinGecko's raw
                    // usd_24h_change (1.327679510905918); this is what turns it
                    // into "+1.33%". Without it the widget showed the full
                    // double, which is what the screenshot caught.
                    format: MFormat.signedPercent,
                    style: const MTextStyle(
                      color: MColor.hex("#4ADE80"),
                      size: 12,
                      bold: true,
                    ),
                  ),
                  const MPadding(
                    MInsets.only(left: 4),
                    MText(
                      "24h",
                      style: MTextStyle(color: MColor.hex("#93C5FD"), size: 12),
                    ),
                  ),
                ]),
              ]),

              // 7-day price trend, directly under the figure it explains.
              // Rasterised natively on Android; a SwiftUI Path on iOS.
              MSizedBox(
                height: 26,
                child: MSparkline(
                  bind: MBind('btc_series'),
                  color: const MColor.hex('#7DD3FC'),
                  strokeWidth: 2,
                  fill: true,
                ),
              ),

              // Footer
              MRow(mainAxisAlignment: MMainAxisAlignment.spaceBetween, [
                const MButton(
                  action: MActionCallback("refresh_crypto"),
                  child: MContainer(
                    background: MColor.hex("#FFFFFF", opacity: 0.1),
                    radius: 10,
                    child: MPadding(
                      MInsets.symmetric(horizontal: 12, vertical: 6),
                      MText(
                        "Refresh",
                        style: MTextStyle(
                          color: MColor.hex("#FFFFFF"),
                          size: 10,
                          bold: true,
                        ),
                      ),
                    ),
                  ),
                ),
                // Compact Session Timer
                MRow([
                  const MText(
                    "LIVE: ",
                    style: MTextStyle(
                      color: MColor.hex("#93C5FD"),
                      size: 8,
                      bold: true,
                    ),
                  ),
                  MTimer(
                    target: DateTime.now(),
                    countUp: true,
                    style: const MTextStyle(
                      color: MColor.hex("#FFFFFF"),
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

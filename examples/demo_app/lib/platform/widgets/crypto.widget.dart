import 'package:mosaic/dsl.dart';

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
            // Runtime-bound accent color (app pushes an "accent" hex).
            background: MColor.bind("accent"),
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
                    child: MIcon(sfSymbol: "bitcoinsign", androidDrawable: "ic_bitcoin", size: 18, color: MColor.hex("#FFFFFF")),
                  ),
                ),
              ]),

              // Price Block
              MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                MText(
                  MBind("btc_price"),
                  // Locale-aware currency formatting of the bound numeric value.
                  format: MFormat.currency,
                  style: const MTextStyle(
                    color: MColor.hex("#FFFFFF"),
                    size: 20,
                    bold: true,
                  ),
                ),
                MRow([
                  MText(
                    MBind("btc_change"),
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
                      style: MTextStyle(
                        color: MColor.hex("#93C5FD"),
                        size: 12,
                      ),
                    ),
                  ),
                ]),
              ]),

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

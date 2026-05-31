import 'package:hw_flutter/hw_dsl.dart';

HWDefinition buildNewsWidget() {
  return HWDefinition(
    name: "NewsWidget",
    width: 4,
    height: 1,
    resizeMode: HWResizeMode.horizontal,
    updateInterval: const Duration(minutes: 15),
    root: HWContainer(
      gradient: const HWLinearGradient(
        colors: [
          HWColor.hex("#0F172A"),
          HWColor.hex("#1E293B"),
        ], // slate-900 to slate-800
      ),
      radius: 24,
      border: const HWBorder(color: HWColor.hex("#334155"), width: 1),
      child: HWStack([
        // Left accent stripe
        const HWPositioned(
          top: 0,
          left: 0,
          bottom: 0,
          child: HWContainer(
            width: 4,
            height: 100, // matched to parent
            background: HWColor.hex("#F43F5E"), // Rose-500
            child: HWSpacer(),
          ),
        ),

        HWPadding(
          const HWInsets.all(16),
          HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
            HWRow([
              const HWText(
                "TRENDING NOW",
                style: HWTextStyle(
                  color: HWColor.hex("#F43F5E"),
                  bold: true,
                  size: 10,
                ),
              ),
              const HWSpacer(),
              HWRow([
                HWTimer(
                  target: DateTime.now().add(const Duration(hours: 1)),
                  style: const HWTextStyle(
                    color: HWColor.hex("#22C55E"),
                    size: 10,
                    bold: true,
                  ),
                ),
                const HWPadding(
                  HWInsets.only(left: 4),
                  HWText(
                    "LIVE",
                    style: HWTextStyle(
                      color: HWColor.hex("#94A3B8"),
                      size: 10,
                      bold: true,
                    ),
                  ),
                ),
              ]),
            ]),
            const HWSpacer(),
            HWText(
              HWBind("news_title"),
              style: const HWTextStyle(
                color: HWColor.hex("#FFFFFF"),
                size: 14,
                bold: true,
              ),
            ),
            const HWSpacer(),
            HWRow([
              HWColumn(crossAxisAlignment: HWCrossAxisAlignment.start, [
                const HWText(
                  "World News • Just now",
                  style: HWTextStyle(color: HWColor.hex("#64748B"), size: 10),
                ),
              ]),
              const HWSpacer(),
              const HWButton(
                action: HWActionCallback("refresh_news"),
                child: HWContainer(
                  background: HWColor.hex("#F43F5E", opacity: 0.1),
                  radius: 8,
                  child: HWPadding(
                    HWInsets.symmetric(horizontal: 10, vertical: 4),
                    HWText(
                      "READ",
                      style: HWTextStyle(
                        color: HWColor.hex("#F43F5E"),
                        size: 10,
                        bold: true,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

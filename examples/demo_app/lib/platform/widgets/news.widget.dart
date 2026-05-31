import 'package:mosaic/mosaic.dart';

MosaicDefinition buildNewsWidget() {
  return MosaicDefinition(
    name: "NewsWidget",
    width: 4,
    height: 1,
    resizeMode: MResizeMode.horizontal,
    updateInterval: const Duration(minutes: 15),
    root: MContainer(
      gradient: const MLinearGradient(
        colors: [
          MColor.hex("#0F172A"),
          MColor.hex("#1E293B"),
        ], // slate-900 to slate-800
      ),
      radius: 24,
      border: const MBorder(color: MColor.hex("#334155"), width: 1),
      child: MStack([
        // Left accent stripe
        const MPositioned(
          top: 0,
          left: 0,
          bottom: 0,
          child: MContainer(
            width: 4,
            height: 100, // matched to parent
            background: MColor.hex("#F43F5E"), // Rose-500
            child: MSpacer(),
          ),
        ),

        MPadding(
          const MInsets.all(16),
          MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
            MRow([
              const MText(
                "TRENDING NOW",
                style: MTextStyle(
                  color: MColor.hex("#F43F5E"),
                  bold: true,
                  size: 10,
                ),
              ),
              const MSpacer(),
              MRow([
                MTimer(
                  target: DateTime.now().add(const Duration(hours: 1)),
                  style: const MTextStyle(
                    color: MColor.hex("#22C55E"),
                    size: 10,
                    bold: true,
                  ),
                ),
                const MPadding(
                  MInsets.only(left: 4),
                  MText(
                    "LIVE",
                    style: MTextStyle(
                      color: MColor.hex("#94A3B8"),
                      size: 10,
                      bold: true,
                    ),
                  ),
                ),
              ]),
            ]),
            const MSpacer(),
            MText(
              MBind("news_title"),
              style: const MTextStyle(
                color: MColor.hex("#FFFFFF"),
                size: 14,
                bold: true,
              ),
            ),
            const MSpacer(),
            MRow([
              MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
                const MText(
                  "World News • Just now",
                  style: MTextStyle(color: MColor.hex("#64748B"), size: 10),
                ),
              ]),
              const MSpacer(),
              const MButton(
                action: MActionCallback("refresh_news"),
                child: MContainer(
                  background: MColor.hex("#F43F5E", opacity: 0.1),
                  radius: 8,
                  child: MPadding(
                    MInsets.symmetric(horizontal: 10, vertical: 4),
                    MText(
                      "READ",
                      style: MTextStyle(
                        color: MColor.hex("#F43F5E"),
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

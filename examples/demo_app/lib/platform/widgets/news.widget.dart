import 'package:mosaic_widgets/dsl.dart';

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

        // Article thumbnail. The URL arrives from the same refresh source as
        // the headline (`news_image`), and the widget process downloads and
        // caches it without the app running.
        MPositioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: MContainer(
            width: 88,
            child: MNetworkImage(
              MBind('news_image'),
              placeholder: const MColor.hex('#1E293B'),
              radius: 16,
            ),
          ),
        ),

        MPadding(
          // The thumbnail is a sibling in the MStack, so it does not push this
          // content aside — the right inset (88 thumbnail + 16 gutter) is what
          // keeps the headline and READ button from running under the photo.
          const MInsets.only(left: 16, top: 16, bottom: 16, right: 104),
          MColumn(crossAxisAlignment: MCrossAxisAlignment.start, [
            MRow([
              MText(
                const MLocalized("trending_now"),
                style: MTextStyle(
                  color: MColor.hex("#F43F5E"),
                  bold: true,
                  size: 10,
                ),
              ),
              const MSpacer(),
              // How fresh the story is, formatted for the device locale —
              // "2 minutes ago" rather than a raw stamp.
              MText(
                MBind("news_updated"),
                format: MFormat.relativeTime,
                style: const MTextStyle(
                  color: MColor.hex("#94A3B8"),
                  size: 10,
                ),
              ),
            ]),
            const MSpacer(),
            // Rotates the top two stories. On Android a ViewFlipper advances
            // itself with the app closed; iOS shows the first child only, so
            // the lead story must be first.
            MFlipper(
              interval: const Duration(seconds: 6),
              [
                MText(
                  MBind("news_title"),
                  maxLines: 2,
                  style: const MTextStyle(
                    color: MColor.hex("#FFFFFF"),
                    size: 14,
                    bold: true,
                  ),
                ),
                MText(
                  MBind("news_title_2"),
                  maxLines: 2,
                  style: const MTextStyle(
                    color: MColor.hex("#FFFFFF"),
                    size: 14,
                    bold: true,
                  ),
                ),
              ],
            ),
            const MSpacer(),
            MRow([
              MText(
                MBind("news_source"),
                maxLines: 1,
                style: const MTextStyle(
                  color: MColor.hex("#64748B"),
                  size: 10,
                ),
              ),
              const MSpacer(),
              const MButton(
                action: MActionCallback("refresh_news"),
                child: MContainer(
                  background: MColor.hex("#F43F5E", opacity: 0.1),
                  radius: 8,
                  child: MPadding(
                    MInsets.symmetric(horizontal: 10, vertical: 4),
                    MText(
                      MLocalized("read_action"),
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

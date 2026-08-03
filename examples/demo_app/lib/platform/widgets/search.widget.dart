import 'package:mosaic_widgets/dsl.dart';

/// A search-bar widget, in the style of the system search pills.
///
/// Home-screen widgets cannot host a real text field — neither WidgetKit nor
/// Android's RemoteViews can inflate an editable input — so a search widget is
/// a tappable affordance that hands off to the app. This one deep-links to
/// `hwdemo://search`, which the demo app listens for via
/// `MosaicBridge.onDeepLink`.
///
/// The two trailing icons deep-link to their own routes, so a tap lands
/// directly on the right screen instead of a generic launch.
MosaicDefinition buildSearchBar() => MosaicDefinition(
  name: 'SearchBar',
  width: 4,
  height: 1,
  // Fills the widget rather than floating a fixed-height pill inside it.
  //
  // A centred 52pt pill looked right on Android, where a 4x1 cell is barely
  // taller than that. iOS has no 4x1 — the nearest family is systemMedium at
  // roughly 150pt — so the pill sat in the middle and the rest of the widget
  // fell back to the system's default backing, which reads as a black band.
  root: MContainer(
        // A radius larger than half the height renders as a pill on both
        // platforms.
        radius: 26,
        // Material You: on Android 12+ the pill picks up the user's
        // wallpaper palette. iOS and older Android use the fallbacks, which
        // are the colours it always had.
        background: const MColor.system(
          MSystemColor.surface,
          fallback: '#FFFFFF',
          fallbackDark: '#1E293B',
        ),
        border: const MBorder(color: MColor.hex('#E2E8F0'), width: 1),
        // Lifts the pill off the wallpaper. iOS blurs it; Android draws an
        // offset silhouette, which is as close as RemoteViews gets.
        shadow: const MShadow(
          color: MColor.hex('#000000', opacity: 0.18),
          blur: 10,
          dy: 2,
        ),
        child: MButton(
          action: const MLaunchUrlAction('hwdemo://search'),
          child: MPadding(
            const MInsets.symmetric(horizontal: 16, vertical: 12),
            MRow(crossAxisAlignment: MCrossAxisAlignment.center, [
              const MIcon(
                sfSymbol: 'magnifyingglass',
                androidDrawable: 'ic_search',
                size: 18,
                color: MColor.hex('#64748B', dark: '#94A3B8'),
              ),
              const MPadding(
                MInsets.only(left: 10),
                MText(
                  'Search anything',
                  style: MTextStyle(
                    color: MColor.hex('#64748B', dark: '#94A3B8'),
                    size: 14,
                  ),
                ),
              ),
              const MSpacer(),
              // MActivityIndicator animates only on Android; on iOS it is a
              // static glyph. Rather than ship a frozen spinner there, each
              // platform gets what it can actually render.
              const MAdaptive(
                ios: MIcon(
                  sfSymbol: 'waveform',
                  androidDrawable: 'ic_mic',
                  size: 14,
                  color: MColor.hex('#94A3B8'),
                ),
                android: MActivityIndicator(size: 14),
              ),
              const MSizedBox.width(10),
              MButton(
                action: const MLaunchUrlAction('hwdemo://search?mode=voice'),
                child: const MIcon(
                  sfSymbol: 'mic.fill',
                  androidDrawable: 'ic_mic',
                  size: 18,
                  color: MColor.system(
                    MSystemColor.accent,
                    fallback: '#2563EB',
                  ),
                ),
              ),
              MButton(
                action: const MLaunchUrlAction('hwdemo://search?mode=lens'),
                child: const MPadding(
                  MInsets.only(left: 14),
                  MIcon(
                    sfSymbol: 'camera.fill',
                    androidDrawable: 'ic_lens',
                    size: 18,
                    color: MColor.hex('#2563EB'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
);

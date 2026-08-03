/// Base class for all home widget nodes.
abstract class MNode {
  const MNode();
  Map<String, dynamic> toJson();
}

/// A dynamic binding that resolves from a key-value store.
/// Two subtrees, one per platform — the escape hatch for what genuinely cannot
/// be expressed once.
///
/// Chosen at **generation time**, not at render: each generator emits only its
/// own branch, so nothing platform-specific reaches the other side. There is no
/// Dart on the home screen, so a runtime check is not possible.
///
/// Reach for this **last**. Prefer, in order: the per-node platform fields
/// (`sfSymbol` / `androidDrawable`), `MosaicDefinition(compactRoot:)` for size,
/// then this. Every use erodes the single-tree promise the package exists for.
///
/// It earns its place where a node behaves differently by platform and the DSL
/// says so: `MFlipper` renders only its first child on iOS, `MActivityIndicator`
/// animates only on Android, and `MFlexible` ratios hold only on Android.
///
/// ```dart
/// MAdaptive(
///   ios: MText('Swipe for more'),        // no self-cycling on iOS
///   android: MFlipper([a, b]),
/// )
/// ```
class MAdaptive extends MNode {
  /// Rendered on iOS, macOS and watchOS.
  final MNode ios;

  /// Rendered on Android, including Android TV.
  final MNode android;

  /// Creates an [MAdaptive].
  const MAdaptive({required this.ios, required this.android});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWAdaptive',
        'ios': ios.toJson(),
        'android': android.toJson(),
      };
}

class MBind {
  final String key;

  /// Rendered when [key] has never been written.
  ///
  /// Without one a widget shows `--` until the app runs and pushes data — and
  /// the OS gallery preview, which runs before the app ever has, shows `--` for
  /// every bound value. That preview is what a user sees when deciding whether
  /// to add the widget at all.
  final String? defaultValue;

  const MBind(this.key, {this.defaultValue});

  @override
  String toString() => 'MBind($key)';

  // NOTE: the `__type` tag values (e.g. 'HWBind', 'HWText', ...) are a stable
  // internal wire-protocol identifier shared with the generators and golden
  // test fixtures. Do NOT rename them when renaming the DSL symbols.
  Map<String, dynamic> toJson() => {
        '__type': 'HWBind',
        'key': key,
        // Omitted when absent so the wire shape is unchanged for the common case.
        if (defaultValue != null) 'defaultValue': defaultValue,
      };
}

/// Text looked up from the platform's own string resources, so the OS picks the
/// device language.
///
/// A widget renders outside the Flutter engine, so Dart's localization stack is
/// not available to it. Declare the text under `strings:` in `mosaic.yaml` and
/// reference it here:
///
/// ```yaml
/// strings:
///   en: { trending: "TRENDING NOW" }
///   ar: { trending: "الأكثر تداولاً" }
/// ```
/// ```dart
/// MText(MLocalized('trending'))
/// ```
///
/// Becomes `Localizable.strings` on iOS and `values-<locale>/strings.xml` on
/// Android — real platform resources, selected by the system. Unlike [MBind]
/// this is resolved at render time from the bundle, not from stored data, so it
/// needs no app involvement at all.
class MLocalized {
  final String key;

  const MLocalized(this.key);

  @override
  String toString() => 'MLocalized($key)';

  Map<String, dynamic> toJson() => {'__type': 'HWLocalized', 'key': key};
}

/// Value formatting modes for text bindings.
/// How a bound numeric value is rendered.
///
/// [percent] treats the value as a *fraction* (`0.15` → `15%`), matching
/// `NumberFormat.getPercentInstance` and SwiftUI's `.percent`. Most web APIs
/// instead return a change already expressed in percent units (`1.33` meaning
/// `1.33%`) — use [signedPercent] for those, or they render 100× too large.
enum MFormat {
  /// Locale-grouped number: `1234.5` → `1,234.5`.
  decimal,

  /// Locale currency: `1234.5` → `$1,234.50`.
  currency,

  /// Fraction as a percentage: `0.15` → `15%`.
  percent,

  /// A signed change already in percent units: `1.327679` → `+1.33%`,
  /// `-0.4` → `-0.94%`. Two decimals, explicit sign, no scaling — the shape
  /// almost every finance and analytics API returns.
  signedPercent,

  /// Epoch milliseconds as a date.
  date,

  /// Epoch milliseconds as "3 hours ago".
  relativeTime,
}

/// Horizontal text alignment.
enum MTextAlign { start, center, end }

/// Text widget for home widgets.
class MText extends MNode {
  final Object text; // String, MBind OR MLocalized
  final MTextStyle style;
  final MFormat? format;

  /// ISO 4217 code for [MFormat.currency], e.g. `'USD'`.
  ///
  /// Without it the value is formatted in the *device's* currency, so a
  /// BTC/USD widget rendered "JOD 64,510.000" on a phone set to Jordan — the
  /// number was never converted, only relabelled. Set this whenever the amount
  /// is in a known currency rather than the user's own.
  final String? currencyCode;

  final int? maxLines;
  final MTextAlign? align;

  /// How the value animates when it changes. iOS 17+ only — see
  /// [MContentTransition].
  final MContentTransition? contentTransition;

  const MText(
    this.text, {
    this.style = const MTextStyle(),
    this.format,
    this.currencyCode,
    this.maxLines,
    this.align,
    this.contentTransition,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWText',
        'text': switch (text) {
          MBind() => (text as MBind).toJson(),
          MLocalized() => (text as MLocalized).toJson(),
          _ => text,
        },
        'style': style.toJson(),
        'format': format?.name,
        'currencyCode': currencyCode,
        'maxLines': maxLines,
        'align': align?.name,
        'contentTransition': contentTransition?.name,
      };
}

/// Column layout.
enum MMainAxisAlignment {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

enum MCrossAxisAlignment { start, center, end, stretch }

class MColumn extends MNode {
  final List<MNode> children;
  final MMainAxisAlignment mainAxisAlignment;
  final MCrossAxisAlignment crossAxisAlignment;

  const MColumn(
    this.children, {
    this.mainAxisAlignment = MMainAxisAlignment.start,
    this.crossAxisAlignment = MCrossAxisAlignment.center,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWColumn',
        'children': children.map((e) => e.toJson()).toList(),
        'mainAxisAlignment': mainAxisAlignment.name,
        'crossAxisAlignment': crossAxisAlignment.name,
      };
}

class MRow extends MNode {
  final List<MNode> children;
  final MMainAxisAlignment mainAxisAlignment;
  final MCrossAxisAlignment crossAxisAlignment;

  const MRow(
    this.children, {
    this.mainAxisAlignment = MMainAxisAlignment.start,
    this.crossAxisAlignment = MCrossAxisAlignment.center,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWRow',
        'children': children.map((e) => e.toJson()).toList(),
        'mainAxisAlignment': mainAxisAlignment.name,
        'crossAxisAlignment': crossAxisAlignment.name,
      };
}

/// Padding widget.
class MPadding extends MNode {
  final MInsets insets;
  final MNode child;
  const MPadding(this.insets, this.child);

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWPadding',
        'insets': insets.toJson(),
        'child': child.toJson(),
      };
}

/// Container widget (background, radius).
class MContainer extends MNode {
  final MNode child;
  final MColor? background;
  final MGradient? gradient;
  final double radius;
  final MBorder? border;
  final double? width;
  final double? height;

  final MInsets? margin;
  final MShadow? shadow;

  /// Space between the container's edge and its [child], inside the
  /// background and border — the same meaning as Flutter's
  /// `Container(padding:)`. Saves wrapping the child in an [MPadding].
  final MInsets? padding;

  /// Per-corner radius. When non-null, takes precedence over the scalar
  /// [radius] field for rounding.
  final MRadius? corners;

  const MContainer({
    required this.child,
    this.background,
    this.gradient,
    this.radius = 0,
    this.border,
    this.width,
    this.height,
    this.margin,
    this.shadow,
    this.padding,
    this.corners,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWContainer',
        'child': child.toJson(),
        'background': background?.toJson(),
        'gradient': gradient?.toJson(),
        'radius': radius,
        'border': border?.toJson(),
        'width': width,
        'height': height,
        'margin': margin?.toJson(),
        'shadow': shadow?.toJson(),
        'padding': padding?.toJson(),
        'corners': corners?.toJson(),
      };
}

/// Drop shadow for a container.
class MShadow {
  final MColor? color;
  final double blur;
  final double dx;
  final double dy;

  const MShadow({this.color, this.blur = 8, this.dx = 0, this.dy = 2});

  Map<String, dynamic> toJson() => {
        'color': color?.toJson(),
        'blur': blur,
        'dx': dx,
        'dy': dy,
      };
}

/// Per-corner radius for a container.
class MRadius {
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;

  const MRadius({
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomLeft = 0,
    this.bottomRight = 0,
  });

  const MRadius.all(double value)
      : topLeft = value,
        topRight = value,
        bottomLeft = value,
        bottomRight = value;

  Map<String, dynamic> toJson() => {
        'topLeft': topLeft,
        'topRight': topRight,
        'bottomLeft': bottomLeft,
        'bottomRight': bottomRight,
      };
}

class MBorder {
  final MColor color;
  final double width;
  const MBorder({required this.color, this.width = 1.0});

  Map<String, dynamic> toJson() => {'color': color.toJson(), 'width': width};
}

abstract class MGradient {
  const MGradient();
  Map<String, dynamic> toJson();
}

class MLinearGradient extends MGradient {
  final List<MColor> colors;
  final List<double>? stops;

  /// Direction in degrees. 0 = left→right, 90 = top→bottom.
  final double angle;

  const MLinearGradient({required this.colors, this.stops, this.angle = 0});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWLinearGradient',
        'colors': colors.map((c) => c.toJson()).toList(),
        'stops': stops,
        'angle': angle,
      };
}

/// Spacer widget.
class MSpacer extends MNode {
  const MSpacer();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWSpacer'};
}

/// Divider line (horizontal by default, optionally vertical).
class MDivider extends MNode {
  final double thickness;
  final MColor? color;
  final bool vertical;
  final double indent;

  const MDivider({
    this.thickness = 1,
    this.color,
    this.vertical = false,
    this.indent = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWDivider',
        'thickness': thickness,
        'color': color?.toJson(),
        'vertical': vertical,
        'indent': indent,
      };
}

/// Icon widget. iOS uses an SF Symbol name; Android uses a drawable resource
/// name. At least one should be provided.
class MIcon extends MNode {
  final String? sfSymbol;
  final String? androidDrawable;
  final double size;
  final MColor? color;

  const MIcon(
      {this.sfSymbol, this.androidDrawable, this.size = 24, this.color});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWIcon',
        'sfSymbol': sfSymbol,
        'androidDrawable': androidDrawable,
        'size': size,
        'color': color?.toJson(),
      };
}

/// Circular gauge / ring progress indicator.
class MGauge extends MNode {
  final Object value; // double OR MBind
  final double max;
  final MColor? trackColor;
  final MColor? fillColor;
  final double lineWidth;

  const MGauge({
    required this.value,
    this.max = 100,
    this.trackColor,
    this.fillColor,
    this.lineWidth = 6,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWGauge',
        'value': value is MBind ? (value as MBind).toJson() : value,
        'max': max,
        'trackColor': trackColor?.toJson(),
        'fillColor': fillColor?.toJson(),
        'lineWidth': lineWidth,
      };
}

/// Badge overlay showing a count on top of a child.
class MBadge extends MNode {
  final MNode child;
  final Object count; // String/int OR MBind
  final MColor? color;

  const MBadge({required this.child, required this.count, this.color});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWBadge',
        'child': child.toJson(),
        'count': count is MBind ? (count as MBind).toJson() : count,
        'color': color?.toJson(),
      };
}

/// Alignment for a [MStack] layer.
enum MStackAlignment {
  topLeading,
  top,
  topTrailing,
  leading,
  center,
  trailing,
  bottomLeading,
  bottom,
  bottomTrailing,
}

/// Stack layout (overlaps children).
class MStack extends MNode {
  final List<MNode> children;
  final MStackAlignment alignment;

  const MStack(this.children, {this.alignment = MStackAlignment.topLeading});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWStack',
        'children': children.map((e) => e.toJson()).toList(),
        'alignment': alignment.name,
      };
}

class MPositioned extends MNode {
  final MNode child;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const MPositioned({
    required this.child,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWPositioned',
        'child': child.toJson(),
        'top': top,
        'left': left,
        'right': right,
        'bottom': bottom,
      };
}

class MCenter extends MNode {
  final MNode child;
  const MCenter({required this.child});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWCenter',
        'child': child.toJson(),
      };
}

/// Where a child sits inside its parent's box.
enum MAlignment {
  topStart,
  topCenter,
  topEnd,
  centerStart,
  center,
  centerEnd,
  bottomStart,
  bottomCenter,
  bottomEnd,
}

/// Positions [child] within the space its parent gives it.
///
/// Start/end rather than left/right, so alignment mirrors in RTL locales the
/// same way the rest of the generated layout does.
class MAlign extends MNode {
  final MAlignment alignment;
  final MNode child;

  const MAlign({required this.alignment, required this.child});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWAlign',
        'alignment': alignment.name,
        'child': child.toJson(),
      };
}

/// A bar chart of a bound numeric series — step counts, weekly totals, hourly
/// rainfall: the "how much per bucket" glance.
///
/// The bound value is a list of numbers pushed with
/// `MosaicBridge.saveList('key', [1, 2, 3])`.
///
/// Unlike [MSparkline], bars are scaled **from zero**, not from the series
/// minimum: a bar's length is read as its magnitude, so starting the axis at the
/// smallest value would overstate small differences. A series with no positive
/// value therefore renders empty.
///
/// Rendering matches [MSparkline]: SwiftUI draws real shapes, while the Android
/// provider rasterises to a bitmap because RemoteViews cannot draw vectors.
class MBarChart extends MNode {
  /// Bound key holding the list of numbers.
  final MBind bind;

  /// Bar colour. A literal, for the same reason as [MSparkline.color].
  final MColor? color;

  /// Gap between bars, in logical pixels.
  final double spacing;

  /// Corner radius on each bar.
  final double radius;

  /// Fixed height; without it the chart fills the space it is given.
  final double? height;

  const MBarChart({
    required this.bind,
    this.color,
    this.spacing = 3,
    this.radius = 2,
    this.height,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWBarChart',
        'bind': bind.toJson(),
        'color': color?.toJson(),
        'spacing': spacing,
        'radius': radius,
        'height': height,
      };
}

/// A line chart of a bound numeric series — the "how has this moved" glance a
/// price, step count, or temperature widget is built around.
///
/// The bound value is a list of numbers pushed with
/// `MosaicBridge.saveList('key', [1, 2, 3])`. Values are normalised across the
/// series, so only the shape matters, not the absolute range.
///
/// Rendering differs by necessity: SwiftUI draws a real `Path`, while
/// RemoteViews cannot draw vectors at all — the Android provider rasterises the
/// series to a bitmap at update time and sets it on an `ImageView`. Both give
/// the same picture; only the Android one is resolution-fixed.
///
/// Fewer than two points renders nothing, since a line needs two ends.
class MSparkline extends MNode {
  /// Bound key holding the list of numbers.
  final MBind bind;

  /// Stroke colour. Bound colours are not supported here — the Android bitmap
  /// is rasterised with a fixed paint.
  final MColor? color;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  /// Translucent fill under the line.
  final bool fill;

  /// Fixed height; without it the chart fills the space it is given.
  final double? height;

  const MSparkline({
    required this.bind,
    this.color,
    this.strokeWidth = 2,
    this.fill = false,
    this.height,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWSparkline',
        'bind': bind.toJson(),
        'color': color?.toJson(),
        'strokeWidth': strokeWidth,
        'fill': fill,
        'height': height,
      };
}

/// Gives [child] a proportional share of the free space along its parent's
/// main axis. Only meaningful as a direct child of an [MRow] or [MColumn].
///
/// Two children with `flex: 1` split the room evenly; `flex: 2` beside `flex: 1`
/// takes twice as much.
///
/// **Platform limit:** Android honours the exact ratio via `layout_weight`.
/// SwiftUI has no proportional flex, so on iOS every `MFlexible` sibling shares
/// the space *equally* regardless of its `flex` value — `flex: 1` behaves the
/// same on both, while other ratios only take effect on Android. Use explicit
/// [MSizedBox] sizes when a ratio has to hold on both platforms.
///
/// Named `MFlexible` rather than `MExpanded` because [MExpanded] already names
/// the Dynamic Island's expanded region.
class MFlexible extends MNode {
  final int flex;
  final MNode child;

  const MFlexible({this.flex = 1, required this.child});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWFlexible',
        'flex': flex,
        'child': child.toJson(),
      };
}

/// A fixed-size box, optionally wrapping [child].
///
/// With no child it is blank space — the usual way to put a precise gap between
/// two nodes, where [MSpacer] would instead absorb whatever room is left. With a
/// child it constrains that child to the given size.
///
/// A null [width] or [height] leaves that axis to size itself.
class MSizedBox extends MNode {
  final double? width;
  final double? height;
  final MNode? child;

  const MSizedBox({this.width, this.height, this.child});

  /// A square box of [size] on both axes.
  const MSizedBox.square(double size, {this.child})
      : width = size,
        height = size;

  /// A fixed vertical gap — the common case inside an [MColumn].
  const MSizedBox.height(double this.height)
      : width = null,
        child = null;

  /// A fixed horizontal gap — the common case inside an [MRow].
  const MSizedBox.width(double this.width)
      : height = null,
        child = null;

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWSizedBox',
        'width': width,
        'height': height,
        if (child != null) 'child': child!.toJson(),
      };
}

/// A button that triggers an action.
class MButton extends MNode {
  final MNode child;
  final MAction action;

  const MButton({required this.child, required this.action});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWButton',
        'child': child.toJson(),
        'action': action.toJson(),
      };
}

/// Conditional visibility.
class MVisibility extends MNode {
  final MBind bind;
  final MNode child;
  final MNode? replacement;

  const MVisibility({
    required this.bind,
    required this.child,
    this.replacement,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWVisibility',
        'bind': bind.toJson(),
        'child': child.toJson(),
        'replacement': replacement?.toJson(),
      };
}

/// Actions for interactable widgets.
abstract class MAction {
  const MAction();
  Map<String, dynamic> toJson();
}

class MLaunchUrlAction extends MAction {
  final String url;
  const MLaunchUrlAction(this.url);

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWLaunchUrlAction', 'url': url};
}

/// Background Callback Action.
class MActionCallback extends MAction {
  final String callbackName;
  const MActionCallback(this.callbackName);

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWActionCallback',
        'callbackName': callbackName,
      };
}

/// Reloads the widget in place, without naming a callback.
///
/// iOS reloads the timeline via a `MosaicRefreshIntent` (iOS 17+, falling back
/// to a `hwrefresh://` link below that). Android refetches every `refresh:`
/// source in `mosaic.yaml` that supplies a key **this widget binds**, then
/// redraws. Both run in the widget process, so the button works with the app
/// closed.
///
/// Use [MActionCallback] instead when you want one named source, or to hand the
/// tap to Dart. While the fetch is in flight `mosaic_refreshing` is true, so an
/// [MActivityIndicator] bound to it shows a spinner.
class MRefreshAction extends MAction {
  /// Creates a refresh action.
  const MRefreshAction();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWRefreshAction'};
}

/// Flips a boolean in shared storage, then redraws the widget.
///
/// Runs entirely on-device — no app launch and no network — so it suits
/// in-widget state like a °C/°F switch. Pair it with
/// `MVisibility(bind: key, ...)` to show a different subtree per state, and
/// read or seed the same key from the app via `MosaicBridge.saveBool`.
/// Requires iOS 17+ for the in-widget button (older iOS opens the app).
class MToggleAction extends MAction {
  /// The shared-storage key holding the boolean.
  final String key;

  const MToggleAction(this.key);

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWToggleAction', 'key': key};
}

/// Timer widget.
class MTimer extends MNode {
  final DateTime target;
  final bool countUp;
  final MTextStyle style;

  const MTimer({
    required this.target,
    this.countUp = false,
    this.style = const MTextStyle(),
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWTimer',
        'target': target.millisecondsSinceEpoch,
        'countUp': countUp,
        'style': style.toJson(),
      };
}

/// Progress Bar widget.
/// How an image is rendered when the user tints their widgets.
///
/// From iOS 18 the Home Screen can render widgets in a tinted (accented) mode.
/// By default an image is drawn with the tint colour — right for icons and SF
/// Symbols, but it turns a photo into a flat silhouette. **iOS 18+ only**;
/// Android has no equivalent and ignores this.
enum MAccentedRendering {
  /// Drawn with the widget's tint colour. Good for icons and glyphs.
  accented,

  /// Tinted, with the image's own luminance preserved.
  accentedDesaturated,

  /// Greyscale, not tinted.
  desaturated,

  /// Left alone. The right choice for photos and artwork.
  fullColor,
}

/// A device metric the widget reads natively, with the app closed.
///
/// See [MDeviceValue].
enum MDeviceMetric {
  /// Battery charge, 0–100.
  ///
  /// **Android** reads this in the widget process, so it is correct even if the
  /// app has not run for days. **iOS cannot**: `isBatteryMonitoringEnabled` is
  /// a no-op inside an app extension, so `batteryLevel` there is always -1 —
  /// on a real device as well as the simulator. Mosaic therefore publishes it
  /// from the *app* (`MosaicPlugin`), which means on iOS the value appears only
  /// after the app has run once, and then tracks changes while it is alive.
  /// Until then the widget shows the missing-value placeholder.
  ///
  /// It never resolves in the iOS **simulator**, which has no battery to read —
  /// monitoring cannot even be enabled there.
  batteryLevel('mosaic_battery_level'),

  /// Whether the device is charging — use with `MVisibility`. Same iOS
  /// caveats as [batteryLevel].
  batteryCharging('mosaic_battery_charging'),

  /// Free space on the data volume, in GB.
  storageFreeGb('mosaic_storage_free_gb'),

  /// Percentage of the data volume in use, 0–100.
  storageUsedPercent('mosaic_storage_used_percent'),

  /// Free RAM in MB.
  ///
  /// **Android** reports system-wide free memory via `ActivityManager`.
  /// **iOS** has no public system-wide figure — apps are sandboxed from it — so
  /// this is the memory still available to *this* process
  /// (`os_proc_available_memory`, iOS 13+). Useful as a headroom gauge; do not
  /// present it to users as the device's free RAM.
  memoryFreeMb('mosaic_memory_free_mb'),

  /// Total RAM in MB. **Android only**; absent on iOS.
  memoryTotalMb('mosaic_memory_total_mb'),

  /// Percentage of RAM in use, 0–100. **Android only**; absent on iOS.
  memoryUsedPercent('mosaic_memory_used_percent');

  const MDeviceMetric(this.key);

  /// The reserved bind key this metric is published under.
  final String key;
}

/// Reads a device metric in the widget process, so it is correct even when the
/// app has not run for days.
///
/// It behaves exactly like an [MBind] — usable anywhere a bound value is
/// accepted, including `MProgressBar.value` and `MVisibility.bind`:
///
/// ```dart
/// MText(MDeviceValue(MDeviceMetric.batteryLevel))
/// MProgressBar(value: MDeviceValue(MDeviceMetric.batteryLevel), max: 100)
/// MVisibility(
///   bind: MDeviceValue(MDeviceMetric.batteryCharging),
///   child: const MIcon(sfSymbol: 'bolt.fill', androidDrawable: 'ic_lightning'),
/// )
/// ```
///
/// An app-supplied battery level goes stale the moment the app is backgrounded;
/// this does not. Only the metrics a widget actually references are collected.
class MDeviceValue extends MBind {
  final MDeviceMetric metric;

  /// [defaultValue] is forwarded, not inherited: Dart constructors do not pass
  /// named parameters up on their own, so without this a metric could never
  /// declare what to show before the first native read lands — which on iOS is
  /// every gallery preview, since the extension has not run yet.
  MDeviceValue(this.metric, {super.defaultValue}) : super(metric.key);
}

/// Gives [child] an accessibility label, so screen readers announce something
/// meaningful instead of reading raw values or nothing at all.
///
/// ```dart
/// MSemantics(
///   label: 'Battery 71 percent, charging',
///   child: MRow([batteryIcon, MText(MBind('battery_level'))]),
/// )
/// ```
///
/// [label] accepts an `MBind`, so it can describe live data.
///
/// [excludeChildren] makes the wrapper a single element and hides what is
/// inside — useful when the children are decorative fragments that read badly
/// one by one. Honoured on both platforms: iOS uses
/// `.accessibilityElement(children: .ignore)`, Android
/// `importantForAccessibility="noHideDescendants"` on the wrapper.
class MSemantics extends MNode {
  final Object label; // String OR MBind
  final MNode child;
  final bool excludeChildren;

  const MSemantics({
    required this.label,
    required this.child,
    this.excludeChildren = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWSemantics',
        'label': label is MBind ? (label as MBind).toJson() : label,
        'child': child.toJson(),
        'excludeChildren': excludeChildren,
      };
}

/// Cycles through [children] on a timer, without the app running.
///
/// **Android only.** RemoteViews permits `ViewFlipper`, which the system
/// advances on its own — the one way to get continuously changing content in a
/// widget. WidgetKit has no equivalent, so **on iOS only the first child
/// renders**; use it for a rotating headline or stat, not for anything a user
/// must be able to read in full.
class MFlipper extends MNode {
  final List<MNode> children;

  /// How long each child stays visible.
  final Duration interval;

  const MFlipper(this.children, {this.interval = const Duration(seconds: 4)});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWFlipper',
        'children': children.map((c) => c.toJson()).toList(),
        'intervalMs': interval.inMilliseconds,
      };
}

/// How a text value animates when it changes between renders.
enum MContentTransition {
  /// No transition.
  none,

  /// Digits roll to the new value. **iOS 17+ only**; Android ignores it.
  numericText,
}

/// An indeterminate circular activity indicator.
///
/// Pair it with `MVisibility(bind: MBind('mosaic_refreshing'), ...)` to show a
/// spinner while a refresh runs — Mosaic sets that key around the fetch:
///
/// ```dart
/// MVisibility(
///   bind: MBind('mosaic_refreshing'),
///   child: const MActivityIndicator(),
///   replacement: const MIcon(sfSymbol: 'arrow.clockwise', androidDrawable: 'ic_refresh'),
/// )
/// ```
///
/// **It only animates on Android**, where RemoteViews permits an indeterminate
/// `ProgressBar`. WidgetKit renders static timeline snapshots, so on iOS this
/// draws a non-spinning indicator — the state change is still visible, the
/// motion is not.
class MActivityIndicator extends MNode {
  final MColor? color;
  final double size;

  const MActivityIndicator({this.color, this.size = 20});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWActivityIndicator',
        'color': color?.toJson(),
        'size': size,
      };
}

class MProgressBar extends MNode {
  final Object value; // double OR MBind
  final double max;
  final MColor color;

  const MProgressBar({
    required this.value,
    this.max = 100.0,
    this.color = const MColor.hex("#4444FF"),
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWProgressBar',
        'value': value is MBind ? (value as MBind).toJson() : value,
        'max': max,
        'color': color.toJson(),
      };
}

/// Dynamic List view.
class MListView extends MNode {
  final MBind bind;
  final MNode itemTemplate;

  const MListView({required this.bind, required this.itemTemplate});

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWListView',
        'bind': bind.toJson(),
        'itemTemplate': itemTemplate.toJson(),
      };
}

/// Image widget.
class MImage extends MNode {
  final MImageSource source;
  final MBoxFit fit;

  /// Corner radius in logical pixels. Ignored when [circle] is true.
  final double? radius;

  /// Clips to a circle — the usual way to get an avatar.
  final bool circle;

  /// How this image renders when widgets are tinted (iOS 18+). Leave null to
  /// accept the system default, which tints the image.
  final MAccentedRendering? accentedMode;

  const MImage(
    this.source, {
    this.fit = MBoxFit.cover,
    this.radius,
    this.circle = false,
    this.accentedMode,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWImage',
        'source': source.toJson(),
        'fit': fit.name,
        'radius': radius,
        'circle': circle,
        'accentedMode': accentedMode?.name,
      };
}

/// An image loaded from the network and cached on disk.
///
/// The widget process downloads the URL on its own — no app launch — and stores
/// it in the shared container, keyed by URL. Later renders read the cached file,
/// so the image survives redraws and appears offline.
///
/// [url] accepts a literal or an `MBind`, so a URL fetched by a `refresh:`
/// source (e.g. an article thumbnail) can drive it.
///
/// Nothing is drawn until the first download completes; give the widget a
/// [placeholder] colour if an empty frame would look broken.
class MNetworkImage extends MNode {
  final Object url; // String OR MBind
  final MBoxFit fit;

  /// Fill shown before the first successful download.
  final MColor? placeholder;

  /// Corner radius in logical pixels. Ignored when [circle] is true.
  final double? radius;

  /// Clips to a circle — the usual way to get an avatar.
  final bool circle;

  /// How this image renders when widgets are tinted (iOS 18+).
  ///
  /// Defaults to [MAccentedRendering.fullColor]: a network image is almost
  /// always a photo or piece of artwork, and the system default would flatten it
  /// into a tinted silhouette.
  final MAccentedRendering accentedMode;

  const MNetworkImage(
    this.url, {
    this.fit = MBoxFit.cover,
    this.placeholder,
    this.radius,
    this.circle = false,
    this.accentedMode = MAccentedRendering.fullColor,
  });

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWNetworkImage',
        'url': url is MBind ? (url as MBind).toJson() : url,
        'fit': fit.name,
        'placeholder': placeholder?.toJson(),
        'radius': radius,
        'circle': circle,
        'accentedMode': accentedMode.name,
      };
}

/// Image sources.
abstract class MImageSource {
  const MImageSource();
  Map<String, dynamic> toJson();
}

class MAssetImage extends MImageSource {
  final String path;
  const MAssetImage(this.path);

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWAssetImage', 'path': path};
}

class MFileImage extends MImageSource {
  final Object path; // String OR MBind
  const MFileImage(this.path);

  @override
  Map<String, dynamic> toJson() => {
        '__type': 'HWFileImage',
        'path': path is MBind ? (path as MBind).toJson() : path,
      };
}

/// Styling types

/// Font weight, matching Flutter's `FontWeight` scale.
///
/// **Android collapses some of these.** `textFontWeight` is API 28 while the
/// minimum is 21, so weight is expressed through the `sans-serif-*` family
/// aliases the platform has always had — which offer thin, light, regular,
/// medium, bold and black. [w200], [w600] and [w800] therefore render as their
/// nearest neighbour there. iOS honours all nine.
enum MFontWeight {
  /// Thin.
  w100('thin', 'ultraLight'),

  /// Extra light — nearest Android family is thin.
  w200('thin', 'thin'),

  /// Light.
  w300('light', 'light'),

  /// Regular.
  w400('regular', 'regular'),

  /// Medium.
  w500('medium', 'medium'),

  /// Semibold — nearest Android family is medium.
  w600('medium', 'semibold'),

  /// Bold.
  w700('bold', 'bold'),

  /// Extra bold — nearest Android family is black.
  w800('black', 'heavy'),

  /// Black.
  w900('black', 'black');

  const MFontWeight(this.androidFamilySuffix, this.swiftWeight);

  /// The `sans-serif-<suffix>` family Android uses to approximate this weight.
  final String androidFamilySuffix;

  /// The SwiftUI `Font.Weight` case name.
  final String swiftWeight;
}

class MTextStyle {
  final double? size;
  final MColor? color;
  final double? opacity;
  final bool? bold;

  /// Font weight. Takes precedence over [bold] when both are set.
  final MFontWeight? weight;

  /// Renders italic.
  final bool? italic;

  /// A style to inherit from — anything set here is overridden by the fields
  /// on this instance.
  ///
  /// Resolved before serialization, so nothing downstream ever sees a chain.
  final MTextStyle? baseStyle;

  const MTextStyle({
    this.size,
    this.color,
    this.opacity,
    this.bold,
    this.weight,
    this.italic,
    this.baseStyle,
  });

  /// A copy with the given fields replaced.
  MTextStyle copyWith({
    double? size,
    MColor? color,
    double? opacity,
    bool? bold,
    MFontWeight? weight,
    bool? italic,
  }) =>
      MTextStyle(
        size: size ?? this.size,
        color: color ?? this.color,
        opacity: opacity ?? this.opacity,
        bold: bold ?? this.bold,
        weight: weight ?? this.weight,
        italic: italic ?? this.italic,
        baseStyle: baseStyle,
      );

  /// This style with [baseStyle] folded in, so callers never walk the chain.
  MTextStyle get _resolved {
    final base = baseStyle;
    if (base == null) return this;
    final flat = base._resolved;
    return MTextStyle(
      size: size ?? flat.size,
      color: color ?? flat.color,
      opacity: opacity ?? flat.opacity,
      bold: bold ?? flat.bold,
      weight: weight ?? flat.weight,
      italic: italic ?? flat.italic,
    );
  }

  Map<String, dynamic> toJson() {
    final s = _resolved;
    return {
      'size': s.size,
      'color': s.color?.toJson(),
      'opacity': s.opacity,
      'bold': s.bold,
      // Omitted when unset so the wire shape is unchanged for existing styles.
      if (s.weight != null) 'weight': s.weight!.name,
      if (s.italic != null) 'italic': s.italic,
    };
  }
}

/// A colour drawn from the user's own system theme.
///
/// On Android 12+ these resolve to the wallpaper-derived Material You palette,
/// so a widget picks up whatever the user has themed their phone to. Each is
/// semantic rather than a raw swatch, and each has a light and a dark form —
/// the same model [MColor.hex] already uses for `dark:`.
enum MSystemColor {
  /// The user's primary accent. Buttons, highlights, active states.
  accent('system_accent1_600', 'system_accent1_200'),

  /// A quieter companion to [accent], for secondary emphasis.
  accentMuted('system_accent2_600', 'system_accent2_200'),

  /// Widget background, matching the system's themed surfaces.
  surface('system_neutral1_50', 'system_neutral1_900'),

  /// Primary text and icons, legible on [surface].
  onSurface('system_neutral1_900', 'system_neutral1_50'),

  /// Secondary text, dividers, and other de-emphasised marks.
  onSurfaceMuted('system_neutral2_700', 'system_neutral2_200');

  const MSystemColor(this.androidLight, this.androidDark);

  /// The `@android:color/...` resource used in light mode.
  final String androidLight;

  /// The `@android:color/...` resource used in dark mode.
  final String androidDark;
}

class MColor {
  final String? hex; // light value (null only for bind form)
  final String? dark; // optional OS dark-mode value
  final String? bind; // runtime data key (mutually exclusive with hex)
  final double opacity;

  /// Set only by [MColor.system]; names the system palette entry to use where
  /// one is available. [hex]/[dark] stay populated as the fallback.
  final MSystemColor? system;

  const MColor.hex(this.hex, {this.dark, this.opacity = 1.0})
      : bind = null,
        system = null;
  const MColor.bind(this.bind, {this.opacity = 1.0})
      : hex = null,
        dark = null,
        system = null;

  /// A colour from the user's system theme, with a fallback for everywhere it
  /// is unavailable.
  ///
  /// **Android 12+ (API 31)** resolves this to the live Material You palette.
  /// **Older Android, and iOS**, use [fallback] and [fallbackDark] — iOS has no
  /// wallpaper-derived palette, so the fallback is what actually renders there.
  /// Pick fallbacks that look right on their own; most widgets are seen on iOS
  /// or pre-31 devices too.
  const MColor.system(
    MSystemColor this.system, {
    required String fallback,
    String? fallbackDark,
    this.opacity = 1.0,
  })  : hex = fallback,
        dark = fallbackDark,
        bind = null;

  Map<String, dynamic> toJson() => bind != null
      ? {'bind': bind, 'opacity': opacity}
      : {
          'hex': hex,
          'dark': dark,
          'opacity': opacity,
          // Omitted entirely for ordinary colours, so the wire shape and every
          // consumer of it stay unchanged unless a system colour is asked for.
          if (system != null) 'system': system!.name,
        };
}

class MInsets {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const MInsets.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const MInsets.symmetric({double vertical = 0, double horizontal = 0})
      : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  const MInsets.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };
}

enum MBoxFit { fill, contain, cover, fitWidth, fitHeight, none, scaleDown }

/// The type of a user-editable widget [MParam].
enum MParamType { text, number, toggle, choice }

/// A user-editable parameter a widget declares for OS configuration.
///
/// When the user adds or edits the widget, the OS presents an editor for each
/// declared parameter (iOS via an `AppIntentConfiguration` whose `AppIntent`
/// exposes the parameters; Android via a configuration `Activity`). The value
/// the user picks is exposed to the widget tree under the same bind namespace
/// as live data: reference it with `MBind(key)`. A param [key] therefore
/// shadows/feeds the bind key of the same name (resolved at render).
class MParam {
  /// Stable identifier; also the bind key the chosen value is exposed under.
  final String key;

  /// Human-readable label shown in the OS configuration UI.
  final String label;

  /// The kind of editor/control to present.
  final MParamType type;

  /// Optional initial value used until the user picks one.
  final Object? defaultValue;

  /// Allowed values for [MParamType.choice]; `null` for other types.
  final List<String>? choices;

  const MParam({
    required this.key,
    required this.label,
    this.type = MParamType.text,
    this.defaultValue,
    this.choices,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'defaultValue': defaultValue,
        'choices': choices,
      };
}

/// The final definition of a widget.
class MosaicDefinition {
  final String name;
  final MNode root;

  /// An alternate tree for the smallest sizes — `systemSmall` on iOS, and a
  /// narrow tile on Android.
  ///
  /// Without it a 2x2 widget renders exactly what a 4x4 does, which is the
  /// usual reason a small widget looks cramped: the same four rows squeezed
  /// into a quarter of the space. Give it the one thing worth seeing small.
  ///
  /// Optional — when null every size renders [root].
  ///
  /// Honoured on both platforms. iOS picks the tree at render from
  /// `@Environment(\.widgetFamily)`; Android hands the launcher a
  /// `RemoteViews(Map<SizeF, RemoteViews>)` (API 31+) keyed on the widget's own
  /// declared minimum size, and falls back to [root] below API 31.
  final MNode? compactRoot;

  final Duration? updateInterval;
  final int width;
  final int height;
  final String? previewImage;
  final MResizeMode resizeMode;

  /// User-editable parameters exposed via the OS configuration UI. Each
  /// param's chosen value is available to [root] via `MBind(param.key)`.
  /// Defaults to no params.
  final List<MParam> params;

  const MosaicDefinition({
    required this.name,
    required this.root,
    this.compactRoot,
    this.updateInterval,
    this.width = 2,
    this.height = 2,
    this.previewImage,
    this.resizeMode = MResizeMode.none,
    this.params = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'root': root.toJson(),
        if (compactRoot != null) 'compactRoot': compactRoot!.toJson(),
        'updateInterval': updateInterval?.inMilliseconds,
        'width': width,
        'height': height,
        'previewImage': previewImage,
        'resizeMode': resizeMode.name,
        'params': params.map((p) => p.toJson()).toList(),
      };
}

enum MResizeMode { none, horizontal, vertical, both }

/// The canonical definition of a Live Activity (iOS) / ongoing notification.
class MosaicLiveActivity {
  final String name;
  final MNode lockScreen;
  final MDynamicIsland dynamicIsland;
  const MosaicLiveActivity({
    required this.name,
    required this.lockScreen,
    required this.dynamicIsland,
  });
  Map<String, dynamic> toJson() => {
        '__type': 'HWLiveActivity',
        'name': name,
        'lockScreen': lockScreen.toJson(),
        'dynamicIsland': dynamicIsland.toJson(),
      };
}

/// The interaction kind of an [MControl].
enum MControlKind { toggle, button }

/// A Control Center / Lock Screen control (iOS 18+) or Quick Settings tile
/// (Android).
///
/// Declared in a `*.control.dart` entry that exports `MControl build<Name>()`
/// and registered under the `controls:` list in `mosaic.yaml`.
class MControl {
  /// Logical name; used to derive the builder function name (`build<Name>`).
  final String name;

  /// Whether this control is a stateful [MControlKind.toggle] or a stateless
  /// [MControlKind.button].
  final MControlKind kind;

  /// Label shown under the control.
  final String label;

  /// iOS SF Symbol icon name.
  final String? sfSymbol;

  /// Android drawable name for the tile icon.
  final String? androidIcon;

  /// For toggles: the bound bool key reflecting the current on/off state.
  final String? valueKey;

  /// What tapping the control does. Toggles typically use [MActionCallback].
  final MAction action;

  const MControl({
    required this.name,
    required this.kind,
    required this.label,
    this.sfSymbol,
    this.androidIcon,
    this.valueKey,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
        '__type': 'HWControl',
        'name': name,
        'kind': kind.name,
        'label': label,
        'sfSymbol': sfSymbol,
        'androidIcon': androidIcon,
        'valueKey': valueKey,
        'action': action.toJson(),
      };
}

/// Dynamic Island presentation regions.
class MDynamicIsland {
  final MNode compactLeading;
  final MNode compactTrailing;
  final MNode minimal;
  final MExpanded expanded;
  const MDynamicIsland({
    required this.compactLeading,
    required this.compactTrailing,
    required this.minimal,
    required this.expanded,
  });
  Map<String, dynamic> toJson() => {
        '__type': 'HWDynamicIsland',
        'compactLeading': compactLeading.toJson(),
        'compactTrailing': compactTrailing.toJson(),
        'minimal': minimal.toJson(),
        'expanded': expanded.toJson(),
      };
}

/// The expanded Dynamic Island layout slots.
class MExpanded {
  final MNode? leading;
  final MNode? trailing;
  final MNode? center;
  final MNode? bottom;
  const MExpanded({this.leading, this.trailing, this.center, this.bottom});
  Map<String, dynamic> toJson() => {
        '__type': 'HWExpanded',
        'leading': leading?.toJson(),
        'trailing': trailing?.toJson(),
        'center': center?.toJson(),
        'bottom': bottom?.toJson(),
      };
}

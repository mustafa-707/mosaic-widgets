/// Base class for all home widget nodes.
abstract class MNode {
  const MNode();
  Map<String, dynamic> toJson();
}

/// A dynamic binding that resolves from a key-value store.
class MBind {
  final String key;
  const MBind(this.key);

  @override
  String toString() => 'MBind($key)';

  // NOTE: the `__type` tag values (e.g. 'HWBind', 'HWText', ...) are a stable
  // internal wire-protocol identifier shared with the generators and golden
  // test fixtures. Do NOT rename them when renaming the DSL symbols.
  Map<String, dynamic> toJson() => {'__type': 'HWBind', 'key': key};
}

/// Value formatting modes for text bindings.
enum MFormat { decimal, currency, percent, date, relativeTime }

/// Horizontal text alignment.
enum MTextAlign { start, center, end }

/// Text widget for home widgets.
class MText extends MNode {
  final Object text; // String OR MBind
  final MTextStyle style;
  final MFormat? format;
  final int? maxLines;
  final MTextAlign? align;

  const MText(
    this.text, {
    this.style = const MTextStyle(),
    this.format,
    this.maxLines,
    this.align,
  });

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWText',
    'text': text is MBind ? (text as MBind).toJson() : text,
    'style': style.toJson(),
    'format': format?.name,
    'maxLines': maxLines,
    'align': align?.name,
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

  const MIcon({this.sfSymbol, this.androidDrawable, this.size = 24, this.color});

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

class MRefreshAction extends MAction {
  const MRefreshAction();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWRefreshAction'};
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

  const MImage(this.source, {this.fit = MBoxFit.cover});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWImage',
    'source': source.toJson(),
    'fit': fit.name,
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

class MTextStyle {
  final double? size;
  final MColor? color;
  final double? opacity;
  final bool? bold;

  const MTextStyle({this.size, this.color, this.opacity, this.bold});

  Map<String, dynamic> toJson() => {
    'size': size,
    'color': color?.toJson(),
    'opacity': opacity,
    'bold': bold,
  };
}

class MColor {
  final String? hex; // light value (null only for bind form)
  final String? dark; // optional OS dark-mode value
  final String? bind; // runtime data key (mutually exclusive with hex)
  final double opacity;

  const MColor.hex(this.hex, {this.dark, this.opacity = 1.0}) : bind = null;
  const MColor.bind(this.bind, {this.opacity = 1.0})
    : hex = null,
      dark = null;

  Map<String, dynamic> toJson() => bind != null
      ? {'bind': bind, 'opacity': opacity}
      : {'hex': hex, 'dark': dark, 'opacity': opacity};
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

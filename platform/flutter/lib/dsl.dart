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

/// Text widget for home widgets.
class MText extends MNode {
  final Object text; // String OR MBind
  final MTextStyle style;
  final MFormat? format;

  const MText(this.text, {this.style = const MTextStyle(), this.format});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWText',
    'text': text is MBind ? (text as MBind).toJson() : text,
    'style': style.toJson(),
    'format': format?.name,
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

  const MContainer({
    required this.child,
    this.background,
    this.gradient,
    this.radius = 0,
    this.border,
    this.width,
    this.height,
    this.margin,
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
  const MLinearGradient({required this.colors, this.stops});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWLinearGradient',
    'colors': colors.map((c) => c.toJson()).toList(),
    'stops': stops,
  };
}

/// Spacer widget.
class MSpacer extends MNode {
  const MSpacer();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWSpacer'};
}

/// Stack layout (overlaps children).
class MStack extends MNode {
  final List<MNode> children;
  const MStack(this.children);

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWStack',
    'children': children.map((e) => e.toJson()).toList(),
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

/// The final definition of a widget.
class MosaicDefinition {
  final String name;
  final MNode root;
  final Duration? updateInterval;
  final int width;
  final int height;
  final String? previewImage;
  final MResizeMode resizeMode;

  const MosaicDefinition({
    required this.name,
    required this.root,
    this.updateInterval,
    this.width = 2,
    this.height = 2,
    this.previewImage,
    this.resizeMode = MResizeMode.none,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'root': root.toJson(),
    'updateInterval': updateInterval?.inMilliseconds,
    'width': width,
    'height': height,
    'previewImage': previewImage,
    'resizeMode': resizeMode.name,
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

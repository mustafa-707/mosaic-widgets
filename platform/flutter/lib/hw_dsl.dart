/// Base class for all home widget nodes.
abstract class HWNode {
  const HWNode();
  Map<String, dynamic> toJson();
}

/// A dynamic binding that resolves from a key-value store.
class HWBind {
  final String key;
  const HWBind(this.key);

  @override
  String toString() => 'HWBind($key)';

  Map<String, dynamic> toJson() => {'__type': 'HWBind', 'key': key};
}

/// Text widget for home widgets.
class HWText extends HWNode {
  final Object text; // String OR HWBind
  final HWTextStyle style;

  const HWText(this.text, {this.style = const HWTextStyle()});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWText',
    'text': text is HWBind ? (text as HWBind).toJson() : text,
    'style': style.toJson(),
  };
}

/// Column layout.
enum HWMainAxisAlignment {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

enum HWCrossAxisAlignment { start, center, end, stretch }

class HWColumn extends HWNode {
  final List<HWNode> children;
  final HWMainAxisAlignment mainAxisAlignment;
  final HWCrossAxisAlignment crossAxisAlignment;

  const HWColumn(
    this.children, {
    this.mainAxisAlignment = HWMainAxisAlignment.start,
    this.crossAxisAlignment = HWCrossAxisAlignment.center,
  });

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWColumn',
    'children': children.map((e) => e.toJson()).toList(),
    'mainAxisAlignment': mainAxisAlignment.name,
    'crossAxisAlignment': crossAxisAlignment.name,
  };
}

class HWRow extends HWNode {
  final List<HWNode> children;
  final HWMainAxisAlignment mainAxisAlignment;
  final HWCrossAxisAlignment crossAxisAlignment;

  const HWRow(
    this.children, {
    this.mainAxisAlignment = HWMainAxisAlignment.start,
    this.crossAxisAlignment = HWCrossAxisAlignment.center,
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
class HWPadding extends HWNode {
  final HWInsets insets;
  final HWNode child;
  const HWPadding(this.insets, this.child);

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWPadding',
    'insets': insets.toJson(),
    'child': child.toJson(),
  };
}

/// Container widget (background, radius).
class HWContainer extends HWNode {
  final HWNode child;
  final HWColor? background;
  final HWGradient? gradient;
  final double radius;
  final HWBorder? border;
  final double? width;
  final double? height;

  final HWInsets? margin;

  const HWContainer({
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

class HWBorder {
  final HWColor color;
  final double width;
  const HWBorder({required this.color, this.width = 1.0});

  Map<String, dynamic> toJson() => {'color': color.toJson(), 'width': width};
}

abstract class HWGradient {
  const HWGradient();
  Map<String, dynamic> toJson();
}

class HWLinearGradient extends HWGradient {
  final List<HWColor> colors;
  final List<double>? stops;
  const HWLinearGradient({required this.colors, this.stops});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWLinearGradient',
    'colors': colors.map((c) => c.toJson()).toList(),
    'stops': stops,
  };
}

/// Spacer widget.
class HWSpacer extends HWNode {
  const HWSpacer();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWSpacer'};
}

/// Stack layout (overlaps children).
class HWStack extends HWNode {
  final List<HWNode> children;
  const HWStack(this.children);

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWStack',
    'children': children.map((e) => e.toJson()).toList(),
  };
}

class HWPositioned extends HWNode {
  final HWNode child;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const HWPositioned({
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

class HWCenter extends HWNode {
  final HWNode child;
  const HWCenter({required this.child});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWCenter',
    'child': child.toJson(),
  };
}

/// A button that triggers an action.
class HWButton extends HWNode {
  final HWNode child;
  final HWAction action;

  const HWButton({required this.child, required this.action});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWButton',
    'child': child.toJson(),
    'action': action.toJson(),
  };
}

/// Conditional visibility.
class HWVisibility extends HWNode {
  final HWBind bind;
  final HWNode child;
  final HWNode? replacement;

  const HWVisibility({
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
abstract class HWAction {
  const HWAction();
  Map<String, dynamic> toJson();
}

class HWLaunchUrlAction extends HWAction {
  final String url;
  const HWLaunchUrlAction(this.url);

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWLaunchUrlAction', 'url': url};
}

/// Background Callback Action.
class HWActionCallback extends HWAction {
  final String callbackName;
  const HWActionCallback(this.callbackName);

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWActionCallback',
    'callbackName': callbackName,
  };
}

class HWRefreshAction extends HWAction {
  const HWRefreshAction();

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWRefreshAction'};
}

/// Timer widget.
class HWTimer extends HWNode {
  final DateTime target;
  final bool countUp;
  final HWTextStyle style;

  const HWTimer({
    required this.target,
    this.countUp = false,
    this.style = const HWTextStyle(),
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
class HWProgressBar extends HWNode {
  final Object value; // double OR HWBind
  final double max;
  final HWColor color;

  const HWProgressBar({
    required this.value,
    this.max = 100.0,
    this.color = const HWColor.hex("#4444FF"),
  });

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWProgressBar',
    'value': value is HWBind ? (value as HWBind).toJson() : value,
    'max': max,
    'color': color.toJson(),
  };
}

/// Dynamic List view.
class HWListView extends HWNode {
  final HWBind bind;
  final HWNode itemTemplate;

  const HWListView({required this.bind, required this.itemTemplate});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWListView',
    'bind': bind.toJson(),
    'itemTemplate': itemTemplate.toJson(),
  };
}

/// Image widget.
class HWImage extends HWNode {
  final HWImageSource source;
  final HWBoxFit fit;

  const HWImage(this.source, {this.fit = HWBoxFit.cover});

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWImage',
    'source': source.toJson(),
    'fit': fit.name,
  };
}

/// Image sources.
abstract class HWImageSource {
  const HWImageSource();
  Map<String, dynamic> toJson();
}

class HWAssetImage extends HWImageSource {
  final String path;
  const HWAssetImage(this.path);

  @override
  Map<String, dynamic> toJson() => {'__type': 'HWAssetImage', 'path': path};
}

class HWFileImage extends HWImageSource {
  final Object path; // String OR HWBind
  const HWFileImage(this.path);

  @override
  Map<String, dynamic> toJson() => {
    '__type': 'HWFileImage',
    'path': path is HWBind ? (path as HWBind).toJson() : path,
  };
}

/// Styling types

class HWTextStyle {
  final double? size;
  final HWColor? color;
  final double? opacity;
  final bool? bold;

  const HWTextStyle({this.size, this.color, this.opacity, this.bold});

  Map<String, dynamic> toJson() => {
    'size': size,
    'color': color?.toJson(),
    'opacity': opacity,
    'bold': bold,
  };
}

class HWColor {
  final String hex;
  final double opacity;
  const HWColor.hex(this.hex, {this.opacity = 1.0});

  Map<String, dynamic> toJson() => {'hex': hex, 'opacity': opacity};
}

class HWInsets {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const HWInsets.all(double value)
    : left = value,
      top = value,
      right = value,
      bottom = value;

  const HWInsets.symmetric({double vertical = 0, double horizontal = 0})
    : left = horizontal,
      top = vertical,
      right = horizontal,
      bottom = vertical;

  const HWInsets.only({
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

enum HWBoxFit { fill, contain, cover, fitWidth, fitHeight, none, scaleDown }

/// The final definition of a widget.
class HWDefinition {
  final String name;
  final HWNode root;
  final Duration? updateInterval;
  final int width;
  final int height;
  final String? previewImage;
  final HWResizeMode resizeMode;

  const HWDefinition({
    required this.name,
    required this.root,
    this.updateInterval,
    this.width = 2,
    this.height = 2,
    this.previewImage,
    this.resizeMode = HWResizeMode.none,
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

enum HWResizeMode { none, horizontal, vertical, both }

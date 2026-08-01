// Handlers for leaf and interaction nodes, plus the image-modifier helpers
// (fit, clipping, tinted-mode rendering) they share.
part of '../ios.dart';

class ButtonHandler extends IosNodeHandler {
  @override
  String get type => 'HWButton';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final action = node.data['action'];
    final childSwift = context.nodeToSwiftUI(child);

    if (action['__type'] == 'HWLaunchUrlAction') {
      final url = swiftEscape(action['url'] as String);
      return '''
if let _u = URL(string: "$url") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else if (action['__type'] == 'HWActionCallback') {
      final callbackName = swiftEscape(action['callbackName'] as String);
      // iOS 17+: dispatch a real AppIntent that records the pending callback in
      // the App Group (the host app fires the Dart backgroundCallback on
      // resume). Pre-iOS17: fall back to the mosaic-callback:// deep link Link,
      // which only re-opens the app. The mosaic-callback URL is built at
      // runtime via percent-encoding to stay force-unwrap-free.
      return '''
if #available(iOS 17.0, *) {
    Button(intent: MosaicCallbackIntent(callbackName: "$callbackName")) {
        $childSwift
    }
    .buttonStyle(.plain)
} else if let _encoded = "$callbackName".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          let _u = URL(string: "mosaic-callback://\\(_encoded)") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else if (action['__type'] == 'HWToggleAction') {
      final key = swiftEscape(action['key'] as String);
      // iOS 17+: flip the stored bool in-process and redraw — no app launch.
      // Pre-iOS17 there are no interactive widgets, so fall back to opening the
      // app, which is the most a Link can do.
      return '''
if #available(iOS 17.0, *) {
    Button(intent: MosaicToggleIntent(key: "$key")) {
        $childSwift
    }
    .buttonStyle(.plain)
} else if let _u = URL(string: "hwrefresh://") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else {
      // hwrefresh. iOS 17+: AppIntent reloads timelines in-process. Pre-iOS17:
      // fall back to the hwrefresh:// deep link Link (static well-formed URL,
      // still no force-unwrap).
      return '''
if #available(iOS 17.0, *) {
    Button(intent: MosaicRefreshIntent()) {
        $childSwift
    }
    .buttonStyle(.plain)
} else if let _u = URL(string: "hwrefresh://") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    }
  }
}

class VisibilityHandler extends IosNodeHandler {
  @override
  String get type => 'HWVisibility';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final replacement = node.data['replacement'] != null
        ? IRNode.fromJson(node.data['replacement'] as Map<String, dynamic>)
        : null;
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = swiftEscape(bindMap['key'] as String);
    final condition = 'mosaicBool(${context.bindSource}["$key"])';
    // Wrapped in Group: a bare if/else is a statement, and a parent applying
    // `.padding(...)` to its closing brace is invalid Swift. Group turns it
    // back into a single view that modifiers can attach to.
    return '''
Group {
    if $condition {
        ${context.nodeToSwiftUI(child)}
    } else {
        ${replacement != null ? context.nodeToSwiftUI(replacement) : 'EmptyView()'}
    }
}''';
  }
}

class ImageHandler extends IosNodeHandler {
  @override
  String get type => 'HWImage';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final source = node.data['source'];
    final type = source['__type'];
    final fit = node.data['fit'];

    String imageCode;
    if (type == 'HWAssetImage') {
      // iOS asset catalogs reference assets by name without a file extension.
      final rawPath = source['path'] as String;
      final dot = rawPath.lastIndexOf('.');
      final slash = rawPath.lastIndexOf('/');
      final assetName =
          (dot > slash && dot != -1) ? rawPath.substring(0, dot) : rawPath;
      imageCode = 'Image("${swiftEscape(assetName)}")';
    } else if (type == 'HWFileImage') {
      final path = source['path'];
      final isBind = path is Map && path['__type'] == 'HWBind';
      final pathValue = isBind
          ? 'mosaicStr(${context.bindSource}["${swiftEscape(path['key'] as String)}"])'
          : '"${swiftEscape(path.toString())}"';
      // Resolve the file via the shared helper (absolute paths used as-is,
      // relative paths resolved against the App Group container). Nil-safe.
      imageCode =
          'Image(mosaic: resolveFileImage($pathValue) ?? MosaicImage())';
    } else {
      return '// Unsupported Image Source';
    }

    final parts = iosImageFitParts(fit);
    return '$imageCode${parts.image}${iosAccentedRendering(node)}'
        '${parts.view}${iosImageClip(node)}';
  }
}

/// Applies an accessibility label to a subtree.
///
/// Without this, VoiceOver reads whatever text happens to be present — often
/// bare numbers with no unit or context.
class SemanticsHandler extends IosNodeHandler {
  @override
  String get type => 'HWSemantics';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final label = node.data['label'];
    final isBind = label is Map && label['__type'] == 'HWBind';
    final labelExpr = isBind
        ? 'mosaicStr(${context.bindSource}["${swiftEscape(label['key'] as String)}"]) ?? ""'
        : '"${swiftEscape(label.toString())}"';

    // .accessibilityElement(children: .ignore) must precede the label, or the
    // children's own labels win.
    final combine = node.data['excludeChildren'] == true
        ? '.accessibilityElement(children: .ignore)'
        : '';
    return '${context.nodeToSwiftUI(child)}'
        '$combine'
        '.accessibilityLabel(Text($labelExpr))';
  }
}

/// Renders an `HWFlipper` as its FIRST child.
///
/// WidgetKit renders static timeline snapshots and has no self-advancing
/// container, so the cycling Android gets from `ViewFlipper` cannot be
/// reproduced. Emitting the first child keeps the layout intact and honest
/// rather than dropping the node.
class FlipperHandler extends IosNodeHandler {
  @override
  String get type => 'HWFlipper';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final children = (node.data['children'] as List?) ?? const [];
    if (children.isEmpty) return '// flipper has no children';
    final first = IRNode.fromJson(children.first as Map<String, dynamic>);
    return '// MFlipper cycles on Android only; showing the first child.\n'
        '${context.nodeToSwiftUI(first)}';
  }
}

/// The tinted-mode rendering modifier, or empty when unset.
///
/// Must be applied to the `Image` itself, before `.resizable()` and friends —
/// `widgetAccentedRenderingMode` is declared on Image, not View.
String iosAccentedRendering(IRNode node) {
  final mode = node.data['accentedMode'];
  if (mode is! String || mode.isEmpty) return '';
  return '.mosaicAccentedRendering("$mode")';
}

/// The clip modifier for an image's `circle`/`radius`, or empty when neither is
/// set. Shared by the asset, file and network image handlers.
///
/// `.clipped()` precedes the shape so a `cover` fit is cropped to the frame
/// rather than overflowing it.
String iosImageClip(IRNode node) {
  if (node.data['circle'] == true) {
    return '.clipShape(Circle())';
  }
  final radius = node.data['radius'];
  if (radius != null) {
    return '.clipShape(RoundedRectangle(cornerRadius: $radius))';
  }
  return '';
}

/// An [MBoxFit] split into the part that must stay on `Image` and the part that
/// applies to a `View`.
///
/// `.resizable()` returns Image; everything else returns a View. Accented
/// rendering has to land between them — it is declared on Image but yields a
/// View — so the two groups cannot be emitted as one string.
({String image, String view}) iosImageFitParts(String? fit) {
  if (fit == 'none') return (image: '', view: '');
  final all = iosImageFitModifiers(fit);
  const resizable = '.resizable()';
  if (all.startsWith(resizable)) {
    return (image: resizable, view: all.substring(resizable.length));
  }
  return (image: '', view: all);
}

/// Maps an [MBoxFit] name onto SwiftUI image modifiers. Shared by the asset,
/// file and network image handlers.
String iosImageFitModifiers(String? fit) {
  switch (fit) {
    case 'cover':
      return '.resizable().aspectRatio(contentMode: .fill)';
    case 'contain':
      return '.resizable().aspectRatio(contentMode: .fit)';
    case 'fill':
      // Stretch to fill the frame on both axes — no aspectRatio.
      return '.resizable()';
    case 'fitWidth':
      return '.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)';
    case 'fitHeight':
      return '.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: .infinity)';
    case 'none':
      return '';
    case 'scaleDown':
      return '.resizable().aspectRatio(contentMode: .fit)';
    default:
      return '.resizable().aspectRatio(contentMode: .fit)';
  }
}

/// Renders an `HWNetworkImage` from the on-disk cache.
///
/// The render itself never touches the network — it reads whatever the timeline
/// provider already downloaded (see MosaicImageCache.prefetch), so a first paint
/// before the download completes shows the placeholder.
class NetworkImageHandler extends IosNodeHandler {
  @override
  String get type => 'HWNetworkImage';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final url = node.data['url'];
    final isBind = url is Map && url['__type'] == 'HWBind';
    final urlExpr = isBind
        ? 'mosaicStr(${context.bindSource}["${swiftEscape(url['key'] as String)}"])'
        : '"${swiftEscape(url.toString())}"';
    final parts = iosImageFitParts(node.data['fit'] as String?);

    final placeholder = node.data['placeholder'];
    final placeholderView = (placeholder is Map)
        ? context._colorToSwift(placeholder.cast<String, dynamic>())
        : 'Color.clear';

    final clip = iosImageClip(node);
    // Wrapped in Group for the same reason as MVisibility: a bare if/else is a
    // statement, so a parent applying modifiers to it would not compile.
    return '''
Group {
    if let _img = MosaicImageCache.cached($urlExpr) {
        Image(mosaic: _img)${parts.image}${iosAccentedRendering(node)}${parts.view}$clip
    } else {
        $placeholderView$clip
    }
}''';
  }
}

class ProgressBarHandler extends IosNodeHandler {
  @override
  String get type => 'HWProgressBar';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    // For binds, resolve the value from entry data at runtime. NSNumber covers
    // Int/Double/Bool stored in UserDefaults; fall back to parsing a String.
    final src = context.bindSource;
    final valStr = isBind
        ? '(mosaicNum($src["${swiftEscape(value['key'] as String)}"]) ?? 0)'
        : '$value';
    final max = node.data['max'] ?? 100.0;
    final color = node.data['color'];

    String tint = '';
    if (color != null) {
      tint = '.tint(${context._colorToSwift(color)})';
    }

    return 'ProgressView(value: $valStr, total: $max)$tint';
  }
}

class ListViewHandler extends IosNodeHandler {
  @override
  String get type => 'HWListView';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = swiftEscape(bindMap['key'] as String);
    final itemJson = node.data['itemTemplate'];
    if (itemJson == null) return '// missing itemTemplate';
    final itemTemplate = IRNode.fromJson(itemJson as Map<String, dynamic>);

    // Render the item template with binds resolved against the per-element
    // `item` dictionary instead of the global `entry.data`. Save and restore
    // the bind source so nested generation outside the loop is unaffected.
    final previousSource = context.bindSource;
    context.bindSource = 'item';
    final String itemSwift;
    try {
      itemSwift = context.nodeToSwiftUI(itemTemplate);
    } finally {
      context.bindSource = previousSource;
    }

    // Decode the bound JSON array from entry data and iterate. A stable id is
    // derived from the enumeration offset so SwiftUI can diff elements.
    return '''
ForEach(Array(mosaicRowList(entry.data["$key"]).enumerated()), id: \\.offset) { _, item in
    $itemSwift
}''';
  }
}

class TimerHandler extends IosNodeHandler {
  @override
  String get type => 'HWTimer';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final targetEpoch = node.data['target'];
    final isBind = targetEpoch is Map && targetEpoch['__type'] == 'HWBind';

    final String dateExpr;
    if (isBind) {
      // Read the target epoch (milliseconds) from entry data at runtime.
      final key = swiftEscape(targetEpoch['key'] as String);
      dateExpr =
          'Date(timeIntervalSince1970: (mosaicNum(${context.bindSource}["$key"]) ?? 0) / 1000.0)';
    } else {
      final DateTime target;
      if (targetEpoch is int) {
        target = DateTime.fromMillisecondsSinceEpoch(targetEpoch);
      } else {
        target = DateTime.parse(targetEpoch.toString());
      }
      final seconds = target.millisecondsSinceEpoch / 1000.0;
      dateExpr = 'Date(timeIntervalSince1970: $seconds)';
    }

    final style = node.data['style'] ?? {};
    final bold = style['bold'] == true ? '.bold()' : '';
    final color = style['color'] != null
        ? '.foregroundColor(${context._colorToSwift(style['color'])})'
        : '';
    final size =
        style['size'] != null ? '.font(.system(size: ${style['size']}))' : '';
    final modifiers = '$bold$color$size.monospacedDigit()';

    final countUp = node.data['countUp'] == true;
    if (countUp) {
      // Counting up: SwiftUI's relative timer Text counts down by default, so
      // we use Text(timerInterval:countsDown:) with countsDown: false to show
      // elapsed time from the target date. That initializer is iOS 16+, so we
      // gate it and fall back to the plain `.timer` style (which counts down)
      // on iOS 14/15 — the closest available behavior.
      return '''
Group {
    if #available(iOS 16.0, *) {
        Text(timerInterval: $dateExpr...Date.distantFuture, countsDown: false)
    } else {
        Text($dateExpr, style: .timer)
    }
}$modifiers''';
    }

    return 'Text($dateExpr, style: .timer)$modifiers';
  }
}

class CenterHandler extends IosNodeHandler {
  @override
  String get type => 'HWCenter';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    // Inside a stack an infinite frame squeezes every sibling to its minimum,
    // and there is nothing to centre within anyway — Flutter's Center wraps its
    // child when unconstrained, and the Android generator does the same.
    if (isInsideStack) return context.nodeToSwiftUI(child);
    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity)''';
  }
}

class DividerHandler extends IosNodeHandler {
  @override
  String get type => 'HWDivider';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final thickness = node.data['thickness'] ?? 1.0;
    final indent = node.data['indent'] ?? 0;
    final colorMap = node.data['color'];
    // Default to a faint separator color when none is given.
    final fill = colorMap != null
        ? context._colorToSwift(colorMap)
        : 'Color.gray.opacity(0.3)';
    final vertical = node.data['vertical'] == true;
    if (vertical) {
      // A vertical rule: width = thickness, stretch height. Indent pads
      // top/bottom via .vertical so the rule doesn't touch the edges.
      return 'Rectangle().fill($fill).frame(width: $thickness).padding(.vertical, $indent)';
    }
    // Horizontal rule: height = thickness, indent pads the sides.
    return 'Rectangle().fill($fill).frame(height: $thickness).padding(.horizontal, $indent)';
  }
}

class IconHandler extends IosNodeHandler {
  @override
  String get type => 'HWIcon';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final sfSymbol = node.data['sfSymbol'] as String?;
    // SwiftUI needs a concrete SF Symbol name; when the DSL only supplied an
    // androidDrawable (sfSymbol null) fall back to a stable placeholder glyph.
    final symbol = (sfSymbol != null && sfSymbol.isNotEmpty)
        ? swiftEscape(sfSymbol)
        : 'questionmark';
    final size = node.data['size'] ?? 24.0;
    final colorMap = node.data['color'];
    final color = colorMap != null
        ? '.foregroundColor(${context._colorToSwift(colorMap)})'
        : '';
    return 'Image(systemName: "$symbol").font(.system(size: $size))$color';
  }
}

class GaugeHandler extends IosNodeHandler {
  @override
  String get type => 'HWGauge';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    final src = context.bindSource;
    // Resolve the value as a Double. Binds parse NSNumber/String from the data
    // dictionary; a literal is emitted verbatim.
    final String valStr;
    if (isBind) {
      final key = swiftEscape(value['key'] as String);
      valStr = '(mosaicNum($src["$key"]) ?? 0)';
    } else {
      valStr = '$value';
    }
    final max = node.data['max'] ?? 100.0;
    final lineWidth = node.data['lineWidth'] ?? 6.0;
    final trackMap = node.data['trackColor'];
    final fillMap = node.data['fillColor'];
    final track = trackMap != null
        ? context._colorToSwift(trackMap)
        : 'Color.gray.opacity(0.3)';
    final fill =
        fillMap != null ? context._colorToSwift(fillMap) : 'Color.blue';
    // Trim fraction guarded against a zero max to avoid NaN.
    final fraction = 'min(max(($valStr) / ${max == 0 ? 1.0 : max}, 0), 1)';
    return '''
ZStack {
    Circle().stroke($track, lineWidth: $lineWidth)
    Circle().trim(from: 0, to: $fraction).stroke($fill, style: StrokeStyle(lineWidth: $lineWidth, lineCap: .round)).rotationEffect(.degrees(-90))
}''';
  }
}

class BadgeHandler extends IosNodeHandler {
  @override
  String get type => 'HWBadge';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final childSwift = context.nodeToSwiftUI(child);
    final count = node.data['count'];
    final isBind = count is Map && count['__type'] == 'HWBind';
    final src = context.bindSource;
    final String countExpr;
    if (isBind) {
      final key = swiftEscape(count['key'] as String);
      // Render the bound count as a string (covers Int/Double/String stored
      // in the data dictionary).
      countExpr = '"\\(mosaicStr($src["$key"]) ?? "")"';
    } else {
      countExpr = '"${swiftEscape(count.toString())}"';
    }
    final colorMap = node.data['color'];
    final color =
        colorMap != null ? context._colorToSwift(colorMap) : 'Color.red';
    return '''
$childSwift
    .overlay(alignment: .topTrailing) {
        Text($countExpr)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill($color))
    }''';
  }
}

class PositionedHandler extends IosNodeHandler {
  @override
  String get type => 'HWPositioned';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final top = node.data['top'];
    final left = node.data['left'];
    final right = node.data['right'];
    final bottom = node.data['bottom'];

    String alignment = '.topLeading';
    if (top != null && right != null) {
      alignment = '.topTrailing';
    } else if (bottom != null && left != null) {
      alignment = '.bottomLeading';
    } else if (bottom != null && right != null) {
      alignment = '.bottomTrailing';
    } else if (top != null) {
      alignment = '.top';
    } else if (bottom != null) {
      alignment = '.bottom';
    } else if (left != null) {
      alignment = '.leading';
    } else if (right != null) {
      alignment = '.trailing';
    }

    // The alignment picks the corner; the offsets say how far from it. Without
    // this second part `top: -34` and `top: 10` rendered identically — pinned
    // flush to the corner — so every decorative element bled off the edge on
    // Android (negative margins) and sat fully visible on iOS.
    //
    // A trailing/bottom inset moves the opposite way: `right: -20` means 20
    // points *past* the trailing edge, which is +20 on x.
    double edge(Object? near, Object? far) {
      if (near != null) return (near as num).toDouble();
      if (far != null) return -(far as num).toDouble();
      return 0;
    }

    final dx = edge(left, right);
    final dy = edge(top, bottom);
    final offset = (dx == 0 && dy == 0) ? '' : '\n    .offset(x: $dx, y: $dy)';

    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: $alignment)$offset''';
  }
}

/// Maps [MAlignment] to a SwiftUI `Alignment`.
///
/// leading/trailing rather than left/right, so it mirrors in RTL locales.
String swiftAlignment(String? name) => switch (name) {
      'topStart' => '.topLeading',
      'topCenter' => '.top',
      'topEnd' => '.topTrailing',
      'centerStart' => '.leading',
      'center' => '.center',
      'centerEnd' => '.trailing',
      'bottomStart' => '.bottomLeading',
      'bottomCenter' => '.bottom',
      'bottomEnd' => '.bottomTrailing',
      _ => '.center',
    };

class AlignHandler extends IosNodeHandler {
  @override
  String get type => 'HWAlign';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final alignment = swiftAlignment(node.data['alignment'] as String?);
    // Claim the offered space, then place the child within it. Inside a stack
    // only the cross axis is claimed: filling the main axis too would starve
    // every sibling, which is not what aligning one child should do.
    final frame = isInsideStack
        ? (isVertical
            ? '.frame(maxWidth: .infinity, alignment: $alignment)'
            : '.frame(maxHeight: .infinity, alignment: $alignment)')
        : '.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: $alignment)';
    return '''
${context.nodeToSwiftUI(child)}
    $frame''';
  }
}

class SizedBoxHandler extends IosNodeHandler {
  @override
  String get type => 'HWSizedBox';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final w = node.data['width'];
    final h = node.data['height'];
    // Only the axes given are constrained; SwiftUI sizes the rest.
    final parts = [
      if (w != null) 'width: $w',
      if (h != null) 'height: $h',
    ];
    final frame = parts.isEmpty ? '' : '\n    .frame(${parts.join(', ')})';

    final childJson = node.data['child'];
    if (childJson == null) {
      // Color.clear rather than Spacer(): a Spacer would absorb leftover space
      // instead of being exactly the size asked for.
      return 'Color.clear$frame';
    }
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    return '${context.nodeToSwiftUI(child)}$frame';
  }
}

class FlexibleHandler extends IosNodeHandler {
  @override
  String get type => 'HWFlexible';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    // SwiftUI has no proportional flex: an infinite frame divides the free
    // space equally among siblings that ask for it, so `flex` cannot be
    // honoured as a ratio here. Documented on MFlexible rather than faked with
    // GeometryReader arithmetic, which would break as soon as the widget is
    // resized to another family.
    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity)''';
  }
}

/// Renders an `HWSparkline` as a real SwiftUI `Path`.
///
/// The series is normalised in Swift rather than at generation time, because the
/// values only exist at render.
class SparklineHandler extends IosNodeHandler {
  @override
  String get type => 'HWSparkline';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final bindMap = node.data['bind'];
    if (bindMap is! Map || bindMap['key'] == null) {
      return '// sparkline has no bound series';
    }
    final key = swiftEscape(bindMap['key'] as String);
    final stroke = (node.data['strokeWidth'] ?? 2).toString();
    final fill = node.data['fill'] == true;
    final colorData = node.data['color'];
    final color = (colorData is Map && colorData['hex'] != null)
        ? context._colorToSwift(colorData.cast<String, dynamic>())
        : 'Color.accentColor';
    final height = node.data['height'];
    final heightMod = height != null ? '\n    .frame(height: $height)' : '';

    // GeometryReader supplies the box to normalise into; a Path cannot know its
    // own size otherwise.
    final fillLayer = fill
        ? '''
                    Path { p in
                        guard points.count > 1 else { return }
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (i, pt) in points.enumerated() {
                            p.addLine(to: CGPoint(
                                x: geo.size.width * CGFloat(i) / CGFloat(points.count - 1),
                                y: pt))
                        }
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill($color.opacity(0.18))
'''
        : '';

    return '''
GeometryReader { geo in
    let raw = mosaicNumList(entry.data["$key"])
    let lo = raw.min() ?? 0
    let hi = raw.max() ?? 1
    // A flat series would divide by zero; render it down the middle instead.
    let span = (hi - lo) == 0 ? 1 : (hi - lo)
    let points: [CGFloat] = raw.map { v in
        geo.size.height - (geo.size.height * CGFloat((v - lo) / span))
    }
    ZStack {
$fillLayer        Path { p in
            guard points.count > 1 else { return }
            p.move(to: CGPoint(x: 0, y: points[0]))
            for (i, pt) in points.enumerated().dropFirst() {
                p.addLine(to: CGPoint(
                    x: geo.size.width * CGFloat(i) / CGFloat(points.count - 1),
                    y: pt))
            }
        }
        .stroke($color, style: StrokeStyle(lineWidth: $stroke, lineCap: .round, lineJoin: .round))
    }
}$heightMod''';
  }
}

/// Renders an `HWBarChart` as real SwiftUI shapes.
class BarChartHandler extends IosNodeHandler {
  @override
  String get type => 'HWBarChart';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final bindMap = node.data['bind'];
    if (bindMap is! Map || bindMap['key'] == null) {
      return '// bar chart has no bound series';
    }
    final key = swiftEscape(bindMap['key'] as String);
    final spacing = (node.data['spacing'] ?? 3).toString();
    final radius = (node.data['radius'] ?? 2).toString();
    final colorData = node.data['color'];
    final color = (colorData is Map && colorData['hex'] != null)
        ? context._colorToSwift(colorData.cast<String, dynamic>())
        : 'Color.accentColor';
    final height = node.data['height'];
    final heightMod = height != null ? '\n    .frame(height: $height)' : '';

    // Scaled from zero, so a bar's length reads as its magnitude. `hi` guards
    // an all-zero series, which would otherwise divide by zero.
    return '''
GeometryReader { geo in
    let raw = mosaicNumList(entry.data["$key"])
    let hi = raw.max() ?? 0
    let scale = hi <= 0 ? 0 : hi
    HStack(alignment: .bottom, spacing: $spacing) {
        ForEach(Array(raw.enumerated()), id: \\.offset) { _, v in
            RoundedRectangle(cornerRadius: $radius)
                .fill($color)
                .frame(height: scale == 0
                    ? 0
                    : max(1, geo.size.height * CGFloat(max(0, v) / scale)))
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
}$heightMod''';
  }
}

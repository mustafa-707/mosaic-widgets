// Handlers for nodes that arrange other nodes.
part of '../ios.dart';

class ColumnHandler extends IosNodeHandler {
  @override
  String get type => 'HWColumn';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(
            IRNode.fromJson(e as Map<String, dynamic>),
            isInsideStack: true,
            isVertical: true))
        .toList();

    final mainAxis = node.data['mainAxisAlignment'] ?? 'start';
    if (mainAxis == 'spaceBetween' && childrenNodes.length > 1) {
      final newChildren = <String>[];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        if (i < childrenNodes.length - 1) newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceEvenly') {
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceAround') {
      // Approx for spaceAround: spacer at ends, 2 spacers between?
      // Or just use spaceEvenly logic but start/end are smaller?
      // SwiftUI spacers are equal. Let's map to spaceEvenly for simplicity/robustness.
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'center') {
      childrenNodes.insert(0, 'Spacer()');
      childrenNodes.add('Spacer()');
    } else if (mainAxis == 'end') {
      childrenNodes.insert(0, 'Spacer()');
    }
    // start is default (no spacers needed if alignment maps to leading/top)

    final cross = node.data['crossAxisAlignment'] as String?;
    final alignment = _mapAlignment(cross);
    final alignComment = cross == 'stretch'
        ? ' // stretch approximated as center (SwiftUI parent cannot stretch children)'
        : '';
    // Force spacing 0 because we handle distribution with Spacers
    return '''
VStack(alignment: $alignment, spacing: 0) {$alignComment
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.leading';
      case 'end':
        return '.trailing';
      case 'stretch':
        return '.center';
      default:
        return '.center';
    }
  }
}

class RowHandler extends IosNodeHandler {
  @override
  String get type => 'HWRow';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(
            IRNode.fromJson(e as Map<String, dynamic>),
            isInsideStack: true,
            isVertical: false))
        .toList();

    final mainAxis = node.data['mainAxisAlignment'] ?? 'start';
    if (mainAxis == 'spaceBetween' && childrenNodes.length > 1) {
      final newChildren = <String>[];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        if (i < childrenNodes.length - 1) newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceEvenly') {
      final newChildren = <String>['Spacer()'];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceAround') {
      // spaceAround approximated as spaceEvenly: SwiftUI Spacers are equal, so
      // the half-size leading/trailing gaps of Flutter's spaceAround can't be
      // expressed exactly here. Comment kept for visibility (Column does too).
      final newChildren = <String>[
        'Spacer() // spaceAround approximated as spaceEvenly'
      ];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'center') {
      childrenNodes.insert(0, 'Spacer()');
      childrenNodes.add('Spacer()');
    } else if (mainAxis == 'end') {
      childrenNodes.insert(0, 'Spacer()');
    }

    final cross = node.data['crossAxisAlignment'] as String?;
    final alignment = _mapAlignment(cross);
    final alignComment = cross == 'stretch'
        ? ' // stretch approximated as center (SwiftUI parent cannot stretch children)'
        : '';
    return '''
HStack(alignment: $alignment, spacing: 0) {$alignComment
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.top';
      case 'end':
        return '.bottom';
      case 'stretch':
        return '.center';
      default:
        return '.center'; // vertically centered
    }
  }
}

class TextHandler extends IosNodeHandler {
  @override
  String get type => 'HWText';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final text = node.data['text'];
    final isBind = text is Map && text['__type'] == 'HWBind';
    final src = context.bindSource;
    final format = node.data['format'] as String?;

    // Build the `Text(...)` expression. Formatting only applies to bound text;
    // a static literal is rendered verbatim.
    final String textExpr;
    if (isBind && format != null) {
      textExpr = _formattedText(format, swiftEscape(text['key'] as String), src,
          currencyCode: node.data['currencyCode'] as String?);
    } else {
      if (text is Map && text['__type'] == 'HWLocalized') {
        // LocalizedStringKey resolves against the extension's own bundle, so the
        // system picks the language — no app involvement.
        textExpr =
            'Text(LocalizedStringKey("${swiftEscape(text['key'] as String)}"))';
      } else {
        final textValue = isBind
            ? '"\\(mosaicStr($src["${swiftEscape(text['key'] as String)}"]) ?? "${swiftEscape(bindDefault(text))}")"'
            : '"${swiftEscape(text as String)}"';
        textExpr = 'Text($textValue)';
      }
    }

    final style = node.data['style'] ?? {};
    // weight wins over bold when both are set, matching the DSL's own rule.
    // SwiftUI has all nine, so nothing is approximated here.
    const swiftWeights = {
      'w100': 'ultraLight',
      'w200': 'thin',
      'w300': 'light',
      'w400': 'regular',
      'w500': 'medium',
      'w600': 'semibold',
      'w700': 'bold',
      'w800': 'heavy',
      'w900': 'black',
    };
    final weightName = swiftWeights[style['weight']];
    final bold = weightName != null
        ? '.fontWeight(.$weightName)'
        : (style['bold'] == true ? '.bold()' : '');
    final italic = style['italic'] == true ? '.italic()' : '';
    final color = style['color'] != null
        ? '.foregroundColor(${context._colorToSwift(style['color'])})'
        : '';
    // An explicit size wins over a role: naming a number is the more specific
    // instruction. Otherwise the role supplies the platform's own type case.
    final roleFont = style['roleSwiftFont'];
    final size = style['size'] != null
        ? '.font(.system(size: ${style['size']}))'
        : (roleFont != null ? '.font(.$roleFont)' : '');
    final opacity =
        style['opacity'] != null ? '.opacity(${style['opacity']})' : '';
    // maxLines → .lineLimit(n); align (start|center|end) →
    // .multilineTextAlignment(.leading|.center|.trailing).
    // NOTE: maxLines and align are serialized as top-level fields on the node,
    // NOT inside the style sub-map (see MText.toJson()).
    final maxLines = node.data['maxLines'];
    final lineLimit = maxLines != null ? '.lineLimit($maxLines)' : '';
    final align = node.data['align'];
    String alignMod = '';
    switch (align) {
      case 'start':
        alignMod = '.multilineTextAlignment(.leading)';
        break;
      case 'center':
        alignMod = '.multilineTextAlignment(.center)';
        break;
      case 'end':
        alignMod = '.multilineTextAlignment(.trailing)';
        break;
    }
    // Use dynamicTypeSize to prevent text scaling with device accessibility settings
    // Digit-rolling on value change, gated to iOS 17+ inside the helper.
    final transition = node.data['contentTransition'] == 'numericText'
        ? '.mosaicNumericTransition()'
        : '';
    return '$textExpr$bold$italic$color$size$opacity$lineLimit$alignMod'
        '$transition.dynamicTypeSize(.large)';
  }

  /// Emits a `Text(...)` for a bound value formatted per MFormat, localized via
  /// `Locale.current`. decimal/currency/percent parse the bound value as a
  /// Double; date/relativeTime read it as epoch milliseconds (Double) and
  /// divide by 1000.0 to obtain epoch seconds — matching Flutter's
  /// `millisecondsSinceEpoch` convention used on Android. The `.formatted`
  /// style APIs used here are iOS15+.
  /// The literal a bind falls back to when its key was never written.
  ///
  /// `--` remains the default default: it is what every bind rendered before
  /// `MBind(defaultValue:)` existed, so omitting one changes nothing.
  String bindDefault(Map<dynamic, dynamic> bind) =>
      (bind['defaultValue'] as String?) ?? '--';

  String _formattedText(String format, String key, String src,
      {String? currencyCode, String fallback = '--'}) {
    // Parse a Double from the bound entry value (NSNumber or String).
    final dbl = '(mosaicNum($src["$key"]) ?? 0)';
    switch (format) {
      case 'decimal':
        return 'Text($dbl.formatted(.number))';
      case 'currency':
        // A declared code wins; otherwise fall back to the device's currency.
        final code = currencyCode == null
            ? 'Locale.current.currency?.identifier ?? "USD"'
            : '"$currencyCode"';
        return 'Text($dbl.formatted(.currency(code: $code)))';
      case 'percent':
        return 'Text($dbl.formatted(.percent))';
      case 'signedPercent':
        // Already in percent units: sign and scale only, never a 100x scaling.
        return 'Text($dbl.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())) + "%")';
      case 'date':
        return 'Text((Date(timeIntervalSince1970: $dbl / 1000.0)).formatted(date: .abbreviated, time: .omitted))';
      case 'relativeTime':
        return 'Text(Date(timeIntervalSince1970: $dbl / 1000.0), style: .relative)';
      default:
        // Unknown format: fall back to the plain interpolated string.
        return 'Text("\\(mosaicStr($src["$key"]) ?? "${swiftEscape(fallback)}")")';
    }
  }
}

class ContainerHandler extends IosNodeHandler {
  @override
  String get type => 'HWContainer';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    // Consume the root-fill flag here so only the outermost container expands.
    final fillRoot = context.fillRoot;
    context.fillRoot = false;
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final radius = node.data['radius'] ?? 0;
    // A background is present whether it carries a hex or a runtime bind key.
    final background = node.data['background'];
    final gradient = node.data['gradient'];
    final border = node.data['border'];
    final padding = node.data['padding'] ?? {};

    // Build modifiers in correct order
    List<String> modifiers = [];

    // 1. Frame (size)
    final width = node.data['width'];
    final height = node.data['height'];
    if (width != null || height != null) {
      modifiers.add(
        '.frame(${width != null ? 'width: $width' : ''}${width != null && height != null ? ', ' : ''}${height != null ? 'height: $height' : ''})',
      );
    }

    // 2. Internal padding
    if (padding.isNotEmpty) {
      modifiers.add(
        '.padding(EdgeInsets(top: ${padding['top'] ?? 0}, leading: ${padding['left'] ?? 0}, bottom: ${padding['bottom'] ?? 0}, trailing: ${padding['right'] ?? 0}))',
      );
    }

    // 2b. Root fill — after padding (so the padding stays inside the tile) and
    // before the background (so the background covers the whole tile).
    if (fillRoot && width == null && height == null) {
      modifiers.add('.frame(maxWidth: .infinity, maxHeight: .infinity)');
    }

    // 3. Background
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      final colorMaps = (gradient['colors'] as List)
          .map((c) => (c as Map).cast<String, dynamic>())
          .toList();
      final stops = gradient['stops'] as List?;
      final String gradientExpr;
      if (stops != null && stops.length == colorMaps.length) {
        // SwiftUI supports arbitrary stops via Gradient.Stop.
        final stopExprs = <String>[];
        for (var i = 0; i < colorMaps.length; i++) {
          stopExprs.add(
              '.init(color: ${context._colorToSwift(colorMaps[i])}, location: ${stops[i]})');
        }
        gradientExpr = 'Gradient(stops: [${stopExprs.join(', ')}])';
      } else {
        final colors =
            colorMaps.map((c) => context._colorToSwift(c)).join(', ');
        gradientExpr = 'Gradient(colors: [$colors])';
      }
      final angle = (gradient['angle'] ?? 0).toDouble();
      final pts = context._gradientPoints(angle);
      modifiers.add(
        '.background(LinearGradient(gradient: $gradientExpr, startPoint: ${pts[0]}, endPoint: ${pts[1]}))',
      );
    } else if (background != null) {
      modifiers.add(
        '.background(${context._colorToSwift(node.data['background'])})',
      );
    }

    // 4. Clip shape. Per-corner `corners` take precedence over scalar radius.
    // Uneven corners use UnevenRoundedRectangle (iOS 16.4+), so the clip goes
    // through the availability-gated `mosaicCornerClip` helper which falls back
    // to a uniform RoundedRectangle (max corner) on <16.4.
    final corners = node.data['corners'] as Map<String, dynamic>?;
    if (corners != null) {
      final tl = corners['topLeft'] ?? 0;
      final tr = corners['topRight'] ?? 0;
      final bl = corners['bottomLeft'] ?? 0;
      final br = corners['bottomRight'] ?? 0;
      modifiers.add('.mosaicCornerClip(topLeft: $tl, topRight: $tr, '
          'bottomLeft: $bl, bottomRight: $br)');
    } else if (radius > 0) {
      modifiers.add('.clipShape(RoundedRectangle(cornerRadius: $radius))');
    } else if (width != null || height != null) {
      // Ensure content doesn't overflow if explicit size is set
      modifiers.add('.clipped()');
    }

    // 4.5 Drop shadow. Applied after the clip so the shadow follows the
    // clipped silhouette. color defaults to black when unspecified.
    final shadow = node.data['shadow'] as Map<String, dynamic>?;
    if (shadow != null) {
      final shadowColor = shadow['color'] != null
          ? context._colorToSwift(shadow['color'] as Map<String, dynamic>)
          : 'Color.black';
      final blur = shadow['blur'] ?? 8.0;
      final dx = shadow['dx'] ?? 0.0;
      final dy = shadow['dy'] ?? 2.0;
      modifiers
          .add('.shadow(color: $shadowColor, radius: $blur, x: $dx, y: $dy)');
    }

    // 5. Border using overlay (preserves rounded corners)
    if (border != null) {
      final borderColor = (border['color'] as Map).cast<String, dynamic>();
      final lineWidth = (border['width'] ?? 1.0);
      modifiers.add(
        '.overlay(RoundedRectangle(cornerRadius: $radius).stroke(${context._colorToSwift(borderColor)}, lineWidth: $lineWidth))',
      );
    }

    // 6. Margin (external padding)
    final margin = node.data['margin'] ?? {};
    if (margin.isNotEmpty) {
      modifiers.add(
        '.padding(EdgeInsets(top: ${margin['top'] ?? 0}, leading: ${margin['left'] ?? 0}, bottom: ${margin['bottom'] ?? 0}, trailing: ${margin['right'] ?? 0}))',
      );
    }

    return '''
${context.nodeToSwiftUI(child)}
    ${modifiers.join('\n    ')}''';
  }
}

class PaddingHandler extends IosNodeHandler {
  @override
  String get type => 'HWPadding';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final insets = node.data['insets'] ?? {};
    return '${context.nodeToSwiftUI(child)}.padding(EdgeInsets(top: ${insets['top'] ?? 0}, leading: ${insets['left'] ?? 0}, bottom: ${insets['bottom'] ?? 0}, trailing: ${insets['right'] ?? 0}))';
  }
}

class StackHandler extends IosNodeHandler {
  @override
  String get type => 'HWStack';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final alignment = _mapStackAlignment(node.data['alignment']);
    return '''
ZStack(alignment: $alignment) {
    ${children.map((c) => context.nodeToSwiftUI(c)).join('\n')}
}''';
  }

  String _mapStackAlignment(String? align) {
    switch (align) {
      case 'topLeading':
        return '.topLeading';
      case 'top':
        return '.top';
      case 'topTrailing':
        return '.topTrailing';
      case 'leading':
        return '.leading';
      case 'center':
        return '.center';
      case 'trailing':
        return '.trailing';
      case 'bottomLeading':
        return '.bottomLeading';
      case 'bottom':
        return '.bottom';
      case 'bottomTrailing':
        return '.bottomTrailing';
      default:
        return '.topLeading';
    }
  }
}

/// Renders an `HWActivityIndicator` as a circular `ProgressView`.
///
/// WidgetKit renders static timeline snapshots, so this does NOT spin on iOS —
/// the indicator appears while `mosaic_refreshing` is set and disappears after,
/// but the motion Android gets from an indeterminate ProgressBar has no
/// WidgetKit equivalent.
class ActivityIndicatorHandler extends IosNodeHandler {
  @override
  String get type => 'HWActivityIndicator';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    final size = (node.data['size'] ?? 20).toDouble();
    final colorData = node.data['color'];
    final tint = (colorData is Map)
        ? '.tint(${context._colorToSwift(colorData.cast<String, dynamic>())})'
        : '';
    return 'ProgressView()'
        '.progressViewStyle(.circular)'
        '$tint'
        '.frame(width: $size, height: $size)';
  }
}

class SpacerHandler extends IosNodeHandler {
  @override
  String get type => 'HWSpacer';
  @override
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true}) {
    return 'Spacer()';
  }
}

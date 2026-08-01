// Handlers for nodes that arrange other nodes — plus the hashing and
// image-clipping helpers the rest of the generator shares.
part of '../android.dart';

class ColumnHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWColumn';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final mainAxis = node.data['mainAxisAlignment'] as String?;
    final crossAxis = node.data['crossAxisAlignment'] as String?;
    final gravity = _mapGravity(
      mainAxis,
      crossAxis,
    );
    var rendered = children
        .map((c) => context.nodeToXml(
            c, usedBinds, visibilityKeys, timers, buttons,
            isInsideLinearLayout: true, isVertical: true))
        .toList();
    if (crossAxis == 'stretch') {
      rendered = rendered.map((c) => _applyCrossAxisStretch(c, true)).toList();
    }
    final withSpacers = _injectMainAxisSpacers(rendered, mainAxis, true);
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '''
<LinearLayout
    android:layout_width="${size.width}"
    android:layout_height="${size.height}"
    android:orientation="vertical"
    android:gravity="$gravity">
    ${withSpacers.join('\n')}
</LinearLayout>''';
  }

  String _mapGravity(String? main, String? cross) {
    String g = '';
    if (main == 'center') {
      g += 'center_vertical';
    } else if (main == 'end') {
      g += 'bottom';
    } else {
      g += 'top';
    }

    g += '|';

    if (cross == 'center') {
      g += 'center_horizontal';
    } else if (cross == 'end') {
      g += 'end';
    } else {
      g += 'start';
    }

    return g;
  }
}

class RowHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWRow';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final mainAxis = node.data['mainAxisAlignment'] as String?;
    final crossAxis = node.data['crossAxisAlignment'] as String?;
    final gravity = _mapGravity(
      mainAxis,
      crossAxis,
    );
    var rendered = children
        .map((c) => context.nodeToXml(
            c, usedBinds, visibilityKeys, timers, buttons,
            isInsideLinearLayout: true, isVertical: false))
        .toList();
    if (crossAxis == 'stretch') {
      rendered = rendered.map((c) => _applyCrossAxisStretch(c, false)).toList();
    }
    final withSpacers = _injectMainAxisSpacers(rendered, mainAxis, false);
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    // A row never fills height: it sizes to its tallest child. When the parent
    // is a FrameLayout (a container, a button, a stack) that is taller, the
    // default top|start would pin the row to the top — while the same widget
    // centres on iOS, because SwiftUI centres an HStack in an infinite frame.
    // Inside a LinearLayout the parent's own gravity places it, so this only
    // applies outside one.
    final selfGravity = isInsideLinearLayout
        ? ''
        : '\n    android:layout_gravity="center_vertical"';
    return '''
<LinearLayout
    android:layout_width="${size.width}"
    android:layout_height="wrap_content"$selfGravity
    android:orientation="horizontal"
    android:gravity="$gravity">
    ${withSpacers.join('\n')}
</LinearLayout>''';
  }

  String _mapGravity(String? main, String? cross) {
    String g = '';
    if (main == 'center') {
      g += 'center_horizontal';
    } else if (main == 'end') {
      g += 'end';
    } else {
      g += 'start';
    }

    g += '|';

    if (cross == 'center') {
      g += 'center_vertical';
    } else if (cross == 'end') {
      g += 'bottom';
    } else {
      g += 'top';
    }

    return g;
  }
}

class TextHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWText';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final text = node.data['text'];
    final isBind = text is Map && text['__type'] == 'HWBind';
    String idAttr = '';
    String textValue = '';
    String? localizedRes;
    if (isBind && context.inItemTemplate) {
      // Inside a list item template the bound field is set PER ROW by the
      // RemoteViewsFactory, not by the provider, so use a stable per-field id
      // and collect the field rather than registering a global bind.
      final key = text['key'] as String;
      context.collectItemField(key);
      idAttr = 'android:id="@+id/hw_item_${AndroidGenerator.idForKey(key)}"';
    } else if (isBind) {
      final key = text['key'] as String;
      (usedBinds[key] ??= <String>{}).add('text');
      final viewId = context.uniqueViewId('hw_text', key);
      context.registerBoundView(viewId, key, 'text');
      idAttr = 'android:id="@+id/$viewId"';
      // Bound text may carry a format directive applied at render time.
      final format = node.data['format'] as String?;
      if (format != null) {
        context.registerTextFormat(key, format,
            currencyCode: node.data['currencyCode'] as String?);
      }
    } else if (text is Map && text['__type'] == 'HWLocalized') {
      // A string resource reference, so the platform picks the language. No
      // provider work and no id needed — AAPT resolves it at inflation.
      localizedRes = AndroidGenerator.localizedRes(text['key'] as String);
    } else {
      textValue = text.toString();
    }
    final colorData = node.data['style']?['color'] ?? {'hex': '#FFFFFF'};
    final color = context.parseColor(
      (colorData as Map).cast<String, dynamic>(),
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';
    // Standalone opacity applies to the whole view regardless of color alpha.
    final opacity = node.data['style']?['opacity'];
    final alphaAttr = opacity != null ? ' android:alpha="$opacity"' : '';

    // maxLines: clamp the line count and ellipsize the overflow with "...".
    final maxLines = node.data['maxLines'];
    final maxLinesAttr = maxLines != null
        ? ' android:maxLines="$maxLines" android:ellipsize="end"'
        : '';

    // align: map the logical MTextAlign to BOTH gravity (pre-API-17 / layout
    // positioning) and textAlignment (RTL-aware, API 17+). start->viewStart,
    // center->center, end->viewEnd.
    final align = node.data['align'] as String?;
    String alignAttr = '';
    if (align != null) {
      final gravity = switch (align) {
        'center' => 'center',
        'end' => 'end',
        _ => 'start',
      };
      final textAlignment = switch (align) {
        'center' => 'center',
        'end' => 'viewEnd',
        _ => 'viewStart',
      };
      alignAttr =
          ' android:gravity="$gravity" android:textAlignment="$textAlignment"';
    }

    // Bind-form text color: the TextView needs a stable id so the provider can
    // resolve+apply the color at update. Reuse the text bind id when present;
    // otherwise allocate a color-bind id.
    if (context.isColorBind(colorData)) {
      final colorKey = colorData['bind'] as String;
      String viewId;
      if (isBind) {
        viewId = 'hw_text_${AndroidGenerator.idForKey(text['key'] as String)}';
      } else {
        viewId = 'hw_textcolor_${AndroidGenerator.idForKey(colorKey)}';
        idAttr = 'android:id="@+id/$viewId"';
      }
      context.registerColorBind(viewId, colorKey, 'text',
          opacity: (colorData['opacity'] ?? 1.0).toDouble());
    }

    final textAttr = localizedRes != null
        ? 'android:text="@string/$localizedRes"'
        : 'android:text="${xmlEscape(textValue)}"';
    return '<TextView $idAttr android:layout_width="wrap_content" android:layout_height="wrap_content" $textAttr android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style"$alphaAttr$maxLinesAttr$alignAttr />';
  }
}

class ContainerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWContainer';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final backgroundMap = node.data['background'] as Map?;
    final isBgBind =
        backgroundMap != null && context.isColorBind(backgroundMap);
    // A non-bind background is "present" only if it carries a static color.
    final background =
        (backgroundMap != null && !isBgBind) ? backgroundMap['hex'] : null;
    final gradient = node.data['gradient'];
    final border = node.data['border'];
    final radius = (node.data['radius'] ?? 0).toDouble();
    // Per-corner radii take precedence over the scalar radius when present.
    final cornersData = node.data['corners'] as Map?;
    final widthVal = node.data['width'];
    final heightVal = node.data['height'];

    // RemoteViews has no real drop shadow: `elevation` needs a view hierarchy
    // the launcher will not give us, and there is no blur primitive at all.
    // What a layer-list *can* do is put an offset silhouette behind the shape,
    // which reads as a shadow at a glance and is what the docs describe.
    //
    // `blur` is therefore accepted and ignored on Android — a hard edge is the
    // honest limit. Two containers differing only in blur produce byte-identical
    // Android drawables and share one resource, which is correct: the value
    // changes nothing here. It still differs on iOS, where `.shadow` blurs.
    final shadow = node.data['shadow'] as Map?;
    final shadowComment = shadow != null
        ? '<!-- shadow: offset silhouette; RemoteViews cannot blur -->\n'
        : '';

    // Bind-form background: the FrameLayout needs an id so the provider can
    // resolve+apply the background color at update time.
    // A rounded bind-form background needs a shape in the layout to tint at
    // update time; a square one can keep the cheaper flat fill.
    final bindWantsShape = isBgBind &&
        ((node.data['radius'] ?? 0).toDouble() > 0 ||
            node.data['corners'] != null);

    String idAttr = '';
    if (isBgBind) {
      final colorKey = backgroundMap['bind'] as String;
      final viewId = 'hw_bgcolor_${AndroidGenerator.idForKey(colorKey)}';
      idAttr = ' android:id="@+id/$viewId"';
      context.registerColorBind(
          viewId, colorKey, bindWantsShape ? 'backgroundTint' : 'background',
          opacity: (backgroundMap['opacity'] ?? 1.0).toDouble());
    }

    String bgAttr = '';
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      // Real gradient: write a <shape><gradient> drawable and reference it.
      final colors = (gradient['colors'] as List).cast<Map>();
      if (colors.isNotEmpty) {
        final hasStops = (gradient['stops'] as List?)?.isNotEmpty ?? false;
        final angle = (gradient['angle'] ?? 0).toDouble();
        final xml = _gradientDrawableXml(
          context,
          colors,
          radius,
          border,
          angle: angle,
          corners: cornersData,
          hasStops: hasStops,
        );
        final name = 'hw_gradient_${_stableHash(xml)}';
        final ref = context.registerDrawable(name, xml);
        bgAttr = ' android:background="$ref"';
      }
    } else if (border != null ||
        cornersData != null ||
        (background != null && radius > 0)) {
      // Border, per-corner radii and/or rounded background: combine into a
      // single shape drawable.
      final xml = _shapeDrawableXml(
        context,
        background != null ? node.data['background'] as Map : null,
        border,
        radius,
        corners: cornersData,
      );
      final name = 'hw_bg_${_stableHash(xml)}';
      final ref = context.registerDrawable(name, xml);
      bgAttr = ' android:background="$ref"';
    } else if (background != null) {
      final color = context.parseColor(node.data['background']);
      bgAttr = ' android:background="$color"';
    } else if (bindWantsShape) {
      // Solid white: the default tint mode is SRC_IN, which replaces the
      // colour outright, so the placeholder never shows through.
      final xml = _shapeDrawableXml(
        context,
        {'hex': '#FFFFFFFF', 'opacity': 1.0},
        border,
        radius,
        corners: cornersData,
      );
      final name = 'hw_bgtint_${_stableHash(xml)}';
      bgAttr = ' android:background="${context.registerDrawable(name, xml)}"';
    }

    // A rounded background does not clip children on Android: the shape is only
    // painted behind them, so anything inside — a decorative circle bled into a
    // corner, an image, a coloured row — keeps its square edges and juts past
    // the curve. iOS `.clipShape` clips the subtree, so the same tree looked
    // right there and wrong here.
    //
    // `setClipToOutline` makes the view clip to its background's outline, which
    // a rounded shape provides. RemoteViews cannot set it as a layout attribute
    // but can invoke the setter, which the provider does via the clip registry.
    //
    // Not applied when the container casts a shadow: the silhouette is drawn
    // *outside* the shape, so clipping to the outline erases exactly the part
    // that makes it read as a shadow.
    final hasRoundedBackground = (radius > 0 || cornersData != null) &&
        bgAttr.contains('@drawable/') &&
        shadow == null;
    if (hasRoundedBackground) {
      if (idAttr.isEmpty) {
        final viewId =
            context.uniqueViewId('hw_clip', '${radius}_${widthVal}_$heightVal');
        idAttr = ' android:id="@+id/$viewId"';
        context.registerClippedView(viewId);
      } else {
        final existing = RegExp(r'@\+id/(\w+)').firstMatch(idAttr)?.group(1);
        if (existing != null) context.registerClippedView(existing);
      }
    }

    // Wrap whatever background was chosen in a layer-list with the silhouette
    // behind it. Done last so it composes with every branch above — gradient,
    // shape, plain colour, or nothing at all.
    if (shadow != null) {
      bgAttr = _shadowLayerXml(
        context,
        shadow,
        bgAttr,
        radius,
        corners: cornersData,
      );
    }

    // Consume the root-fill flag so only the outermost container expands.
    final isRootContainer = context.fillRoot;
    context.fillRoot = false;
    final fallbackSize = isRootContainer ? 'match_parent' : 'wrap_content';
    final width = widthVal != null ? '${widthVal}dp' : fallbackSize;
    final height = heightVal != null ? '${heightVal}dp' : fallbackSize;

    final margin = node.data['margin'];
    String marginAttr = '';
    if (margin != null) {
      // Use start/end (RTL-aware) for horizontal margins so layouts mirror in
      // RTL locales. The IR keys stay logical left/right.
      if (margin['left'] != null) {
        marginAttr += ' android:layout_marginStart="${margin['left']}dp"';
      }
      if (margin['top'] != null) {
        marginAttr += ' android:layout_marginTop="${margin['top']}dp"';
      }
      if (margin['right'] != null) {
        marginAttr += ' android:layout_marginEnd="${margin['right']}dp"';
      }
      if (margin['bottom'] != null) {
        marginAttr += ' android:layout_marginBottom="${margin['bottom']}dp"';
      }
    }

    // Inside the background and border, like Flutter's Container(padding:).
    // Start/end rather than left/right so it mirrors in RTL locales.
    final padding = node.data['padding'];
    String paddingAttr = '';
    if (padding is Map && padding.isNotEmpty) {
      paddingAttr = ' android:paddingStart="${padding['left'] ?? 0}dp"'
          ' android:paddingEnd="${padding['right'] ?? 0}dp"'
          ' android:paddingTop="${padding['top'] ?? 0}dp"'
          ' android:paddingBottom="${padding['bottom'] ?? 0}dp"';
    }

    return '''$shadowComment<FrameLayout$idAttr
    android:layout_width="$width" android:layout_height="$height"$paddingAttr
    $bgAttr
    $marginAttr>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
</FrameLayout>''';
  }

  String _stableHash(String s) => stableHash(s);

  /// Builds a `<shape><gradient>` drawable. Uses startColor/endColor for the
  /// common 2-color case and adds centerColor for 3-stop gradients. Optionally
  /// includes corner radius, a stroke (border) and is angle 0.
  String _gradientDrawableXml(
    AndroidGenerator context,
    List<Map> colors,
    double radius,
    Object? border, {
    double angle = 0,
    Map? corners,
    bool hasStops = false,
  }) {
    final parsed = colors
        .map((c) => context.parseColor(c.cast<String, dynamic>()))
        .toList();
    // Android <gradient android:angle> accepts ONLY multiples of 45 (0=L->R,
    // 90=top->bottom, ...). Quantize the DSL degrees to the nearest 45.
    final quantized = _quantizeAngle45(angle);
    String gradientTag;
    if (parsed.length >= 3) {
      gradientTag =
          '    <gradient android:type="linear" android:angle="$quantized"\n        android:startColor="${parsed.first}"\n        android:centerColor="${parsed[parsed.length ~/ 2]}"\n        android:endColor="${parsed.last}" />';
    } else {
      final end = parsed.length >= 2 ? parsed[1] : parsed.first;
      gradientTag =
          '    <gradient android:type="linear" android:angle="$quantized"\n        android:startColor="${parsed.first}"\n        android:endColor="$end" />';
    }
    final cornersTag = _cornersTag(corners, radius);
    final stroke = _strokeTag(context, border);
    // Android <shape><gradient> only expresses start/center/end positions, so
    // arbitrary N-stop gradients are approximated. Surface the limitation as a
    // comment (after the XML declaration so AAPT still accepts the file)
    // instead of dropping the stops silently.
    final stopsComment = hasStops
        ? '\n<!-- gradient stops approximated: Android shape gradients support up to 3 positions -->'
        : '';
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel$stopsComment
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
$gradientTag$cornersTag$stroke
</shape>''';
  }

  /// Quantizes an angle in degrees to the nearest multiple of 45 in [0, 315].
  /// Android `<gradient android:angle>` only accepts multiples of 45.
  int _quantizeAngle45(double angle) {
    var rounded = (angle / 45).round() * 45;
    rounded = rounded % 360;
    if (rounded < 0) rounded += 360;
    return rounded;
  }

  /// Builds a `<corners>` tag. Per-corner [corners] (topLeft/topRight/
  /// bottomLeft/bottomRight) take precedence over the scalar [radius]. Returns
  /// an empty string when neither rounds anything.
  String _cornersTag(Map? corners, double radius) {
    if (corners != null) {
      final tl = (corners['topLeft'] ?? 0).toDouble();
      final tr = (corners['topRight'] ?? 0).toDouble();
      final bl = (corners['bottomLeft'] ?? 0).toDouble();
      final br = (corners['bottomRight'] ?? 0).toDouble();
      return '\n    <corners android:topLeftRadius="${tl}dp" android:topRightRadius="${tr}dp" android:bottomLeftRadius="${bl}dp" android:bottomRightRadius="${br}dp" />';
    }
    if (radius > 0) {
      return '\n    <corners android:radius="${radius}dp" />';
    }
    return '';
  }

  /// Builds a `<shape>` drawable combining a solid fill (background), a stroke
  /// (border) and corner radius. Any may be omitted.
  /// Builds a `layer-list` placing an offset silhouette behind [bgAttr].
  ///
  /// Insets cannot be negative, so a shadow offset left or up is expressed by
  /// insetting the *foreground* from the opposite side instead. Both layers end
  /// up the same size, which keeps the shape from appearing to shift when a
  /// shadow is added.
  String _shadowLayerXml(
    AndroidGenerator context,
    Map shadow,
    String bgAttr,
    double radius, {
    Map? corners,
  }) {
    final dx = (shadow['dx'] ?? 0).toDouble();
    final dy = (shadow['dy'] ?? 0).toDouble();

    // Default matches the DSL's own default: a soft black.
    final colorMap = shadow['color'] as Map?;
    final color = colorMap != null
        ? context.parseColor(colorMap.cast<String, dynamic>())
        : '#33000000';

    final silhouette = _shapeDrawableXml(
      context,
      {'hex': color, 'opacity': 1.0},
      null,
      radius,
      corners: corners,
    );
    final silhouetteRef = context.registerDrawable(
        'hw_shadow_${_stableHash(silhouette)}', silhouette);

    // A background that resolved to a bare colour rather than a drawable has no
    // shape to stack, so give it one.
    final fg =
        RegExp(r'android:background="([^"]+)"').firstMatch(bgAttr)?.group(1);
    String fgRef;
    if (fg == null) {
      return bgAttr; // nothing to cast a shadow for
    } else if (fg.startsWith('@drawable/')) {
      fgRef = fg;
    } else {
      final shape = _shapeDrawableXml(
          context, {'hex': fg, 'opacity': 1.0}, null, radius,
          corners: corners);
      fgRef = context.registerDrawable('hw_bg_${_stableHash(shape)}', shape);
    }

    String inset(double v) => '${v.abs()}dp';
    final layer = '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="$silhouetteRef"
        android:left="${inset(dx > 0 ? dx : 0)}" android:top="${inset(dy > 0 ? dy : 0)}"
        android:right="${inset(dx < 0 ? dx : 0)}" android:bottom="${inset(dy < 0 ? dy : 0)}" />
    <item android:drawable="$fgRef"
        android:left="${inset(dx < 0 ? dx : 0)}" android:top="${inset(dy < 0 ? dy : 0)}"
        android:right="${inset(dx > 0 ? dx : 0)}" android:bottom="${inset(dy > 0 ? dy : 0)}" />
</layer-list>''';
    final ref =
        context.registerDrawable('hw_shadowed_${_stableHash(layer)}', layer);
    return ' android:background="$ref"';
  }

  String _shapeDrawableXml(
    AndroidGenerator context,
    Map? background,
    Object? border,
    double radius, {
    Map? corners,
  }) {
    final solid = background != null
        ? '\n    <solid android:color="${context.parseColor(background.cast<String, dynamic>())}" />'
        : '';
    final cornersTag = _cornersTag(corners, radius);
    final stroke = _strokeTag(context, border);
    return '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">$solid$stroke$cornersTag
</shape>''';
  }

  String _strokeTag(AndroidGenerator context, Object? border) {
    if (border == null) return '';
    final b = border as Map;
    final width = (b['width'] ?? 1.0).toDouble();
    final color =
        context.parseColor((b['color'] as Map).cast<String, dynamic>());
    return '\n    <stroke android:width="${width}dp" android:color="$color" />';
  }
}

class PaddingHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWPadding';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final childJson = node.data['child'];
    if (childJson == null) return '<!-- missing child -->';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final insets = node.data['insets'];
    final pLeft = insets['left'] ?? 0;
    final pRight = insets['right'] ?? 0;
    final pTop = insets['top'] ?? 0;
    final pBottom = insets['bottom'] ?? 0;

    // Use padding directly on a FrameLayout wrapper.
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr =
        (isInsideLinearLayout && isSpacer) ? ' android:layout_weight="1"' : '';
    // A wrapper around a spacer keeps the weighted fill behaviour. Otherwise it
    // must size to the parent's axis like any other LinearLayout child: a
    // hard-coded match_parent width let a padded label swallow the whole row,
    // pushing the trailing icons out of the widget.
    final linear = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? '0dp'
            : linear.width);
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? 'match_parent'
            : linear.height);

    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height"$weightAttr
    android:paddingStart="${pLeft}dp" android:paddingEnd="${pRight}dp"
    android:paddingTop="${pTop}dp" android:paddingBottom="${pBottom}dp">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
</FrameLayout>''';
  }
}

class StackHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWStack';
  @override
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  }) {
    final children = ((node.data['children'] as List?) ?? const [])
        .map((e) => IRNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final gravity = _stackAlignmentGravity(node.data['alignment'] as String?);
    final renderedChildren = children
        .map((c) => context.nodeToXml(
            c, usedBinds, visibilityKeys, timers, buttons,
            isInsideLinearLayout: isInsideLinearLayout, isVertical: isVertical))
        .map((xml) => _applyStackAlignment(xml, gravity))
        .toList();
    // Inside a Row the parent is wrap_content tall, so a match_parent height is
    // a circular constraint Android resolves to zero — the whole stack, and
    // everything layered in it, would silently disappear.
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '''
<FrameLayout
    android:layout_width="${size.width}"
    android:layout_height="${size.height}">
    ${renderedChildren.join('\n')}
</FrameLayout>''';
  }
}

/// Deterministic non-negative hash of generated content, used to name drawable
/// files so identical drawables collapse and distinct ones differ.
String stableHash(String s) {
  int h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h.toString();
}

/// Background attribute and view id needed to clip an image to a circle or
/// rounded corners, plus whether clipping applies at all.
///
/// RemoteViews cannot call `setClipToOutline` through a layout attribute and has
/// no clip API of its own, so the shape is expressed as a background drawable
/// and the provider enables outline clipping on that view — the only route to a
/// rounded image in an app widget.
({String bgAttr, bool clips}) androidImageClip(
  IRNode node,
  AndroidGenerator context,
) {
  final circle = node.data['circle'] == true;
  final radius = node.data['radius'];
  if (!circle && radius == null) return (bgAttr: '', clips: false);

  final xml = circle
      ? '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#FF000000" />
</shape>'''
      : '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FF000000" />
    <corners android:radius="${radius}dp" />
</shape>''';

  final name = 'hw_clip_${stableHash(xml)}';
  final ref = context.registerDrawable(name, xml);
  return (bgAttr: ' android:background="$ref"', clips: true);
}

/// Wraps a subtree in a view carrying `contentDescription`, so TalkBack
/// announces something meaningful instead of reading raw values.
///
/// A static label goes straight into the layout; a bound one is applied by the
/// provider via `setContentDescription`.

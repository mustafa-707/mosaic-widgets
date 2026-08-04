// Handlers for leaf and interaction nodes: text-adjacent content, images,
// indicators, buttons, and visibility.
part of '../android.dart';

class SemanticsHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWSemantics';
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
    final label = node.data['label'];
    final isBind = label is Map && label['__type'] == 'HWBind';

    String idAttr = '';
    String descAttr = '';
    if (isBind) {
      final key = label['key'] as String;
      final viewId = context.uniqueViewId('hw_a11y', key);
      idAttr = ' android:id="@+id/$viewId"';
      context.registerContentDescription(viewId, key);
    } else {
      descAttr = ' android:contentDescription="${xmlEscape(label.toString())}"';
    }

    // excludeChildren: collapse the subtree into this one element, so a screen
    // reader announces the label instead of walking every fragment inside.
    //
    // This was previously left to iOS on the theory that RemoteViews could not
    // mark descendants unimportant. RemoteViews restricts which *classes* may be
    // inflated, not which attributes they carry — and `importantForAccessibility`
    // is a plain View attribute resolved by the LayoutInflater, in a layout this
    // generator writes. Nothing has to cross the RemoteViews boundary at all.
    final excludeAttr = node.data['excludeChildren'] == true
        ? ' android:importantForAccessibility="noHideDescendants"'
        : '';

    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final rendered = context.nodeToXml(
        child, usedBinds, visibilityKeys, timers, buttons,
        isInsideLinearLayout: false, isVertical: isVertical);

    return '''
<FrameLayout$idAttr$descAttr$excludeAttr
    android:layout_width="${size.width}" android:layout_height="${size.height}">
$rendered
</FrameLayout>''';
  }
}

/// Renders an `HWFlipper` as a `ViewFlipper` that advances itself.
///
/// `ViewFlipper` is `@RemoteView` and, with `autoStart`, the system drives the
/// cycling without the app running — the only continuously changing content an
/// app widget can show.
/// Renders only the `android:` branch of an [MAdaptive].
///
/// The iOS branch never reaches this generator, so an SF Symbol or an
/// iOS-only node inside it produces no XML — and, because the bind and button
/// collectors are threaded through this traversal, nothing from that branch is
/// registered for the provider either.
/// Emits an [MRaw]'s layout XML verbatim.
///
/// Unchecked by design. Note RemoteViews only inflates whitelisted classes, so
/// a view Android refuses to inflate fails on the home screen at run time —
/// "Can't load widget" — rather than at build time.
class RawHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWRaw';
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
    // Declared binds are registered so the provider still resolves them; the
    // generator cannot see inside the snippet to discover them itself.
    for (final key in (node.data['binds'] as List?) ?? const []) {
      if (key is String) (usedBinds[key] ??= <String>{}).add('text');
    }
    final xml = node.data['androidXml'];
    if (xml is! String || xml.isEmpty) {
      return '<!-- MRaw: no androidXml for this platform -->';
    }
    return '<!-- MRaw — hand-written, not generated -->\n$xml';
  }
}

class AdaptiveHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWAdaptive';
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
    final branch = node.data['android'];
    if (branch is! Map) return '<!-- MAdaptive has no android branch -->';
    return context.nodeToXml(
      IRNode.fromJson(branch.cast<String, dynamic>()),
      usedBinds,
      visibilityKeys,
      timers,
      buttons,
      isInsideLinearLayout: isInsideLinearLayout,
      isVertical: isVertical,
    );
  }
}

class FlipperHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWFlipper';
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
    if (children.isEmpty) return '<!-- flipper has no children -->';

    final interval = (node.data['intervalMs'] ?? 4000).toInt();
    // Children render outside a LinearLayout: a ViewFlipper is a FrameLayout,
    // so weights do not apply.
    final rendered = children
        .map((c) => context.nodeToXml(
            c, usedBinds, visibilityKeys, timers, buttons,
            isInsideLinearLayout: false, isVertical: isVertical))
        .join('\n');

    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '''
<ViewFlipper
    android:layout_width="${size.width}"
    android:layout_height="${size.height}"
    android:flipInterval="$interval"
    android:autoStart="true"
    android:measureAllChildren="false">
$rendered
</ViewFlipper>''';
  }
}

/// Renders an `HWNetworkImage` as an `ImageView` fed from the on-disk cache.
///
/// The layout only reserves the view; the provider sets the bitmap at update
/// time (see MosaicImageCache), because RemoteViews cannot reference a file
/// path and a layout pass cannot wait on the network.
class NetworkImageHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWNetworkImage';
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
    final url = node.data['url'];
    final isBind = url is Map && url['__type'] == 'HWBind';
    final key = isBind ? url['key'] as String : url.toString();
    final viewId = context.uniqueViewId('hw_netimg', key);
    context.registerNetworkImage(viewId, key, isBind: isBind);

    final scaleType = switch (node.data['fit'] as String?) {
      'cover' => 'centerCrop',
      'contain' => 'fitCenter',
      'fill' => 'fitXY',
      'fitWidth' => 'fitStart',
      'fitHeight' => 'fitEnd',
      'none' => 'center',
      _ => 'fitCenter',
    };

    // A clip shape needs the background slot, so it wins over the placeholder
    // colour when both are given.
    final clip = androidImageClip(node, context);
    final placeholder = node.data['placeholder'];
    final bgAttr = clip.clips
        ? clip.bgAttr
        : ((placeholder is Map && placeholder['hex'] != null)
            ? ' android:background="${context.parseColor(placeholder.cast<String, dynamic>())}"'
            : '');
    if (clip.clips) context.registerClippedView(viewId);

    // A Row is wrap_content tall, so a match_parent height there is a circular
    // constraint Android resolves to zero — the image would silently not render.
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '<ImageView android:id="@+id/$viewId" '
        'android:layout_width="${size.width}" android:layout_height="${size.height}" '
        'android:scaleType="$scaleType"$bgAttr />';
  }
}

/// Renders an `HWActivityIndicator` as an indeterminate `ProgressBar`.
///
/// This is the one genuinely animating element available to a widget:
/// `ProgressBar` is `@RemoteView`, and in indeterminate mode the system drives
/// the spin without the app running.
class ActivityIndicatorHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWActivityIndicator';
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
    final size = (node.data['size'] ?? 20).toDouble();
    final colorData = node.data['color'];
    final tint = (colorData is Map && colorData['hex'] != null)
        ? ' android:indeterminateTint="${context.parseColor(colorData.cast<String, dynamic>())}"'
        : '';
    return '<ProgressBar style="?android:attr/progressBarStyleSmall" '
        'android:indeterminate="true" '
        'android:layout_width="${size}dp" android:layout_height="${size}dp"$tint />';
  }
}

class SpacerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWSpacer';
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
    if (!isInsideLinearLayout) {
      return '<FrameLayout android:layout_width="0dp" android:layout_height="0dp" />';
    }
    final width = isVertical ? "match_parent" : "0dp";
    final height = isVertical ? "0dp" : "match_parent";
    return '<FrameLayout android:layout_width="$width" android:layout_height="$height" android:layout_weight="1" />';
  }
}

class ButtonHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWButton';
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
    final action = node.data['action'];
    final index = buttons.length;
    buttons.add(action);
    final id = index == 0 ? "hw_button_main" : "hw_button_$index";
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr =
        (isInsideLinearLayout && isSpacer) ? ' android:layout_weight="1"' : '';
    // A wrapper around a spacer keeps the weighted fill behaviour. Otherwise it
    // sizes to the parent's axis: a hard-coded match_parent width made the
    // first child of a Row swallow the whole width, pushing its siblings — a
    // second button, a toggle — out of the widget entirely.
    final linear = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? '0dp'
            : linear.width);
    // Outside a LinearLayout this fills the parent rather than wrapping. A
    // hard-coded wrap_content pinned a button that fills its widget — a search
    // pill, a full-bleed tap target — to the top, while the same widget centres
    // on iOS because SwiftUI centres into an infinite frame.
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? 'match_parent'
            : linear.height);

    return '''
<FrameLayout
    android:id="@+id/$id"
    android:layout_width="$width" android:layout_height="$height"$weightAttr
    android:clickable="true" android:focusable="true">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
</FrameLayout>''';
  }
}

class VisibilityHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWVisibility';
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
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '<!-- missing bind -->';
    final key = bindMap['key'] as String;
    // The same key may drive more than one MVisibility in a widget — a unit
    // toggle switching both a temperature and its range, say. Deriving the view
    // id from the key alone gave every occurrence the SAME id, and RemoteViews
    // acts on the first match only: the later ones never toggled, so both
    // branches rendered stacked on top of each other.
    final occurrence = visibilityKeys.where((k) => k == key).length;
    visibilityKeys.add(key);
    final visId = occurrence == 0
        ? AndroidGenerator.idForKey(key)
        : '${AndroidGenerator.idForKey(key)}_${occurrence + 1}';
    final isSpacer = child.type == 'HWSpacer';
    final weightAttr =
        (isInsideLinearLayout && isSpacer) ? ' android:layout_weight="1"' : '';
    // A wrapper around a spacer keeps the weighted fill behaviour. Otherwise it
    // sizes to the parent's axis: a hard-coded match_parent width made the
    // first child of a Row swallow the whole width, pushing its siblings — a
    // second button, a toggle — out of the widget entirely.
    final width = (isInsideLinearLayout && isSpacer && isVertical)
        ? 'match_parent'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? '0dp'
            : linearChildSize(
                isInsideLinearLayout: isInsideLinearLayout,
                parentIsVertical: isVertical,
              ).width);
    final height = (isInsideLinearLayout && isSpacer && isVertical)
        ? '0dp'
        : (isInsideLinearLayout && isSpacer && !isVertical
            ? 'match_parent'
            // Was hard-coded wrap_content. Inside a Row or Column that is what
            // linearChildSize returns anyway, but inside a FrameLayout — a
            // Container, a Button — it collapsed the slot to its content, so a
            // child asking to fill the cell got the height of its own icon.
            : linearChildSize(
                isInsideLinearLayout: isInsideLinearLayout,
                parentIsVertical: isVertical,
              ).height);

    final replacementJson = node.data['replacement'];
    if (replacementJson == null) {
      // No replacement: keep legacy single-view GONE behavior. The slot
      // dimensions/weight live directly on the toggled view.
      return '''
<FrameLayout
    android:id="@+id/hw_visibility_$visId"
    android:layout_width="$width" android:layout_height="$height"$weightAttr>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
</FrameLayout>''';
    }

    // Replacement present: wrap BOTH toggled views inside a SINGLE container so
    // the handler returns exactly ONE layout element occupying one slot. The
    // slot dimensions/weight live on the wrapper (so main-axis spacers align and
    // cross-axis stretch rewrites the wrapper's dimension once); the two inner
    // views are wrap_content and toggled inversely by the provider via their
    // ids, which remain discoverable for setViewVisibility.
    context.registerVisibilityReplacement(key);
    final replacement =
        IRNode.fromJson(replacementJson as Map<String, dynamic>);

    // The two branches are alternative roots of one slot, so each must start
    // from the same state. `fillRoot` is consumed by the first container it
    // reaches; without restoring it the shown branch filled the cell and the
    // hidden one sized to its content, so toggling visibly resized the widget.
    final fillRootForBranches = context.fillRoot;
    final shown = context.nodeToXml(
        child, usedBinds, visibilityKeys, timers, buttons,
        isInsideLinearLayout: false);
    context.fillRoot = fillRootForBranches;
    final hidden = context.nodeToXml(
        replacement, usedBinds, visibilityKeys, timers, buttons,
        isInsideLinearLayout: false);

    // The inner wrappers fill the slot rather than hugging their content: a
    // FrameLayout parent that is itself wrap_content still measures a
    // match_parent child down to content, so this is safe in both cases and
    // lets a filling design actually fill.
    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height"$weightAttr>
    <FrameLayout
        android:id="@+id/hw_visibility_$visId"
        android:layout_width="match_parent" android:layout_height="match_parent">
        $shown
    </FrameLayout>
    <FrameLayout
        android:id="@+id/hw_visibility_${visId}_alt"
        android:layout_width="match_parent" android:layout_height="match_parent">
        $hidden
    </FrameLayout>
</FrameLayout>''';
  }
}

class ImageHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWImage';
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
    final source = node.data['source'];
    final type = source['__type'];
    String idAttr = '';
    String srcAttr = '';
    if (type == 'HWAssetImage') {
      // Asset: reference a bundled drawable by sanitized basename (no ext).
      final path = (source['path'] as String?) ?? '';
      final base = p.basenameWithoutExtension(path);
      final res = sanitizeIdentifier(base).toLowerCase();
      if (res.isNotEmpty) {
        srcAttr = ' android:src="@drawable/$res"';
      }
    } else if (type == 'HWFileImage') {
      final path = source['path'];
      if (path is Map && path['__type'] == 'HWBind') {
        final key = path['key'] as String;
        if (context.inItemTemplate) {
          // Per-row image: set by the factory via hw_item_<field>.
          context.collectItemField(key, kind: 'image');
          idAttr =
              'android:id="@+id/hw_item_${AndroidGenerator.idForKey(key)}"';
        } else {
          // Dynamic file image: resolved at update time via the provider.
          (usedBinds[key] ??= <String>{}).add('image');
          idAttr =
              'android:id="@+id/hw_image_${AndroidGenerator.idForKey(key)}"';
        }
      } else if (path is String && path.isNotEmpty) {
        // Static file image: wire a fixed Uri in the provider.
        final suffix = sanitizeIdentifier(path).toLowerCase();
        idAttr = 'android:id="@+id/hw_image_$suffix"';
        context.registerStaticImageUri(suffix, path);
      }
    }
    final scaleType = _mapFit(node.data['fit'] as String?);
    // Rounded/circular clipping needs a stable id: the provider enables outline
    // clipping on the view, since RemoteViews has no clip attribute.
    final clip = androidImageClip(node, context);
    if (clip.clips && idAttr.isEmpty) {
      final id = 'hw_imageclip_${stableHash(node.data.toString())}';
      idAttr = 'android:id="@+id/$id"';
      context.registerClippedView(id);
    } else if (clip.clips) {
      final match = RegExp(r'@\+id/([a-z0-9_]+)').firstMatch(idAttr);
      if (match != null) context.registerClippedView(match.group(1)!);
    }
    return '<ImageView $idAttr$srcAttr android:layout_width="match_parent" android:layout_height="wrap_content" android:scaleType="$scaleType"${clip.bgAttr} />';
  }

  /// Maps a Flutter MBoxFit value to the closest Android ImageView scaleType.
  /// Defaults to centerCrop (BoxFit.cover) when unset or unrecognized.
  String _mapFit(String? fit) {
    switch (fit) {
      case 'contain':
        return 'fitCenter';
      case 'fill':
        return 'fitXY';
      case 'fitWidth':
        return 'fitStart';
      case 'fitHeight':
        return 'fitEnd';
      case 'none':
        return 'center';
      case 'scaleDown':
        return 'centerInside';
      case 'cover':
      default:
        return 'centerCrop';
    }
  }
}

class ProgressBarHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWProgressBar';
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
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    String idAttr = '';
    String progressAttr = '';
    if (isBind) {
      final key = value['key'] as String;
      (usedBinds[key] ??= <String>{}).add('progress');
      final viewId = context.uniqueViewId('hw_progress', key);
      context.registerBoundView(viewId, key, 'progress');
      idAttr = 'android:id="@+id/$viewId"';
    } else if (value != null) {
      // Static value: emit it directly into the layout (set at runtime for binds).
      final progress = (value as num).toInt();
      progressAttr = ' android:progress="$progress"';
    }
    final max = (node.data['max'] ?? 100).toInt();
    // android:progressTint requires API 21+ (the configured min_sdk).
    final colorData = node.data['color'];
    String tintAttr = '';
    if (colorData is Map) {
      final colorMap = colorData.cast<String, dynamic>();
      if (context.isColorBind(colorMap)) {
        // Bind-form tint: the ProgressBar needs a stable id so the provider can
        // resolve+apply the color at update time via setColorFilter. Reuse the
        // value bind id when present; otherwise allocate a color-bind id.
        final colorKey = colorMap['bind'] as String;
        String viewId;
        if (isBind) {
          viewId =
              'hw_progress_${AndroidGenerator.idForKey(value['key'] as String)}';
        } else {
          viewId = 'hw_progresscolor_${AndroidGenerator.idForKey(colorKey)}';
          idAttr = 'android:id="@+id/$viewId"';
        }
        context.registerColorBind(viewId, colorKey, 'progress',
            opacity: (colorMap['opacity'] ?? 1.0).toDouble());
      } else {
        final color = context.parseColor(colorMap);
        tintAttr = ' android:progressTint="$color"';
      }
    }
    return '<ProgressBar $idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max"$progressAttr$tintAttr />';
  }
}

class ListViewHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWListView';
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
    // Real Android collection view: emit a ListView whose adapter is wired in
    // the provider via setRemoteAdapter to the shared MosaicListService. The
    // item template is rendered into a per-row item layout, and each bound
    // field maps to a hw_item_<field> view set per row by the factory.
    final bindMap = node.data['bind'] as Map?;
    if (bindMap == null) return '<!-- missing bind -->';
    final key = bindMap['key'] as String;
    final itemJson = node.data['itemTemplate'];
    if (itemJson == null) return '<!-- missing itemTemplate -->';
    final itemTemplate = IRNode.fromJson(
      (itemJson as Map).cast<String, dynamic>(),
    );

    final idKey = context.registerListView(key, itemTemplate);

    // Weighted fill along a Row's main axis; otherwise sized to the parent's
    // axis, because a match_parent height inside a wrap_content Row resolves to
    // zero and the list would not appear at all.
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final horizontalInRow = isInsideLinearLayout && !isVertical;
    final width = horizontalInRow ? '0dp' : size.width;
    final height = horizontalInRow ? size.height : 'match_parent';
    final weightAttr = horizontalInRow ? ' android:layout_weight="1"' : '';
    return '<ListView android:id="@+id/hw_list_$idKey" android:layout_width="$width" android:layout_height="$height"$weightAttr />';
  }
}

class TimerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWTimer';
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
    final target = node.data['target'];
    final id = timers.length.toString();
    timers[id] = target.toString();
    if (node.data['countUp'] == true) {
      context.registerTimerCountUp(id);
    }

    final color = context.parseColor(
      node.data['style']?['color'] ?? {'hex': '#FFFFFF'},
    );
    final size = node.data['style']?['size'] ?? 14;
    final style = node.data['style']?['bold'] == true ? 'bold' : 'normal';
    // Standalone opacity applies to the whole view (mirror TextHandler).
    final opacity = node.data['style']?['opacity'];
    final alphaAttr = opacity != null ? ' android:alpha="$opacity"' : '';

    return '<Chronometer android:id="@+id/hw_timer_$id" android:layout_width="wrap_content" android:layout_height="wrap_content" android:textColor="$color" android:textSize="${size}sp" android:textStyle="$style"$alphaAttr />';
  }
}

class PositionedHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWPositioned';
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
    final top = node.data['top'];
    final left = node.data['left'];
    final right = node.data['right'];
    final bottom = node.data['bottom'];

    String gravity = 'top|start';
    String margins = '';
    if (top != null) margins += ' android:layout_marginTop="${top}dp"';
    // RTL-aware: logical left/right map to start/end so positioning mirrors.
    if (left != null) margins += ' android:layout_marginStart="${left}dp"';
    if (right != null) {
      margins += ' android:layout_marginEnd="${right}dp"';
      gravity = gravity.replaceFirst('start', 'end');
    }
    if (bottom != null) {
      margins += ' android:layout_marginBottom="${bottom}dp"';
      gravity = gravity.replaceFirst('top', 'bottom');
    }

    return '''
<FrameLayout
    android:layout_width="wrap_content" android:layout_height="wrap_content"
    android:layout_gravity="$gravity"
    $margins>
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons)}
</FrameLayout>''';
  }
}

/// Renders an `HWDivider` as a plain `<View>` with a solid background color.
/// A horizontal divider fills the available width and is [thickness]dp tall; a
/// vertical divider is [thickness]dp wide and fills the available height.
/// `indent` is applied as symmetric RTL-aware start/end margins.
class DividerHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWDivider';
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
    final thickness = (node.data['thickness'] ?? 1).toDouble();
    final isVerticalDivider = node.data['vertical'] == true;
    final indent = (node.data['indent'] ?? 0).toDouble();
    final colorData = node.data['color'];
    final color = colorData is Map
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FFFFFF';

    final width = isVerticalDivider ? '${thickness}dp' : 'match_parent';
    final height = isVerticalDivider ? 'match_parent' : '${thickness}dp';

    String marginAttr = '';
    if (indent > 0) {
      marginAttr =
          ' android:layout_marginStart="${indent}dp" android:layout_marginEnd="${indent}dp"';
    }

    // FrameLayout, not View: RemoteViews only inflates `@RemoteView` classes,
    // and android.view.View is not one — it would fail the entire layout.
    return '<FrameLayout android:layout_width="$width" android:layout_height="$height" android:background="$color"$marginAttr />';
  }
}

/// Renders an `HWIcon` as an `<ImageView>` referencing the Android drawable
/// resource named by `androidDrawable`, tinted with `color` and sized to
/// `size`dp. When `androidDrawable` is null (an iOS-only SF Symbol was given)
/// the icon cannot be resolved on Android: emit a documented comment and a
/// blank sized `<View>` placeholder rather than crashing or emitting a dangling
/// `@drawable/null` reference.
class IconHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWIcon';
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
    final size = (node.data['size'] ?? 24).toDouble();
    final drawable = node.data['androidDrawable'] as String?;
    if (drawable == null || drawable.isEmpty) {
      // FrameLayout, not View: android.view.View is not `@RemoteView` and
      // would fail the entire layout to inflate.
      return '<!-- icon has no androidDrawable -->\n'
          '<FrameLayout android:layout_width="${size}dp" android:layout_height="${size}dp" />';
    }
    final res = sanitizeIdentifier(drawable).toLowerCase();
    final colorData = node.data['color'];
    String tintAttr = '';
    if (colorData is Map) {
      final color = context.parseColor(colorData.cast<String, dynamic>());
      tintAttr = ' android:tint="$color"';
    }
    return '<ImageView android:src="@drawable/$res"$tintAttr android:layout_width="${size}dp" android:layout_height="${size}dp" />';
  }
}

/// Renders an `HWGauge` (a circular ring/arc indicator on iOS) as a horizontal
/// determinate `<ProgressBar>`. RemoteViews/AppWidgets cannot draw arbitrary
/// arcs, so this is a DOCUMENTED best-effort approximation surfaced via a
/// comment. `fillColor` maps to `progressTint`, `trackColor` to
/// `backgroundTint`. A bound `value` reuses the exact same `progress` runtime
/// bind path as `HWProgressBar` (id `hw_progress_<key>` + `setProgressBar`).
class GaugeHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWGauge';
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
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    String idAttr = '';
    String progressAttr = '';
    if (isBind) {
      final key = value['key'] as String;
      (usedBinds[key] ??= <String>{}).add('progress');
      final viewId = context.uniqueViewId('hw_progress', key);
      context.registerBoundView(viewId, key, 'progress');
      idAttr = ' android:id="@+id/$viewId"';
    } else if (value != null) {
      progressAttr = ' android:progress="${(value as num).toInt()}"';
    }
    final max = (node.data['max'] ?? 100).toInt();

    String tintAttr = '';
    final fill = node.data['fillColor'];
    if (fill is Map) {
      tintAttr +=
          ' android:progressTint="${context.parseColor(fill.cast<String, dynamic>())}"';
    }
    final track = node.data['trackColor'];
    if (track is Map) {
      tintAttr +=
          ' android:backgroundTint="${context.parseColor(track.cast<String, dynamic>())}"';
    }

    // lineWidth styles the arc stroke on iOS; a linear ProgressBar has no arc,
    // so the value is dropped. Surface the drop with a comment when present.
    final lineWidthComment = node.data['lineWidth'] != null
        ? '<!-- gauge lineWidth ignored: approximated as linear ProgressBar on Android -->\n'
        : '';

    return '<!-- gauge approximated as linear progress on Android (RemoteViews has no arc) -->\n'
        '$lineWidthComment'
        '<ProgressBar$idAttr style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="wrap_content" android:max="$max"$progressAttr$tintAttr />';
  }
}

/// Renders an `HWBadge` as a `<FrameLayout>` holding the child plus a small
/// `<TextView>` (the count) pinned to the `top|end` corner. The count text view
/// gets a generated rounded shape drawable as its background (registered via
/// [AndroidGenerator.registerDrawable]). A bound `count` reuses the standard
/// text bind path (id `hw_text_<key>` + `setTextViewText`).
class BadgeHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWBadge';
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

    final count = node.data['count'];
    final isBind = count is Map && count['__type'] == 'HWBind';
    String countIdAttr = '';
    String countText = '';
    if (isBind) {
      final key = count['key'] as String;
      (usedBinds[key] ??= <String>{}).add('text');
      final viewId = context.uniqueViewId('hw_text', key);
      context.registerBoundView(viewId, key, 'text',
          fallback: AndroidGenerator.bindFallback(count));
      countIdAttr = ' android:id="@+id/$viewId"';
    } else {
      countText = count == null ? '' : count.toString();
    }

    // Rounded background for the badge bubble. A pill is achieved with a large
    // corner radius; the color comes from the optional `color` field.
    final colorData = node.data['color'];
    final bgColor = colorData is Map
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FF0000';
    final shapeXml = '''<?xml version="1.0" encoding="utf-8"?>
$xmlSentinel
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="$bgColor" />
    <corners android:radius="100dp" />
</shape>''';
    final badgeName = 'hw_badge_${_badgeHash(shapeXml)}';
    final bgRef = context.registerDrawable(badgeName, shapeXml);

    return '''
<FrameLayout
    android:layout_width="wrap_content" android:layout_height="wrap_content">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    <TextView$countIdAttr
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="top|end"
        android:background="$bgRef"
        android:paddingStart="4dp" android:paddingEnd="4dp"
        android:text="${xmlEscape(countText)}"
        android:textColor="#FFFFFF" android:textSize="10sp" />
</FrameLayout>''';
  }

  String _badgeHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h.toString();
  }
}

class CenterHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWCenter';
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
    // Sized to the parent's axis: inside a wrap_content Row a match_parent
    // height resolves to zero and the centred child never renders. There is
    // nothing to centre within in that case anyway, which matches Flutter —
    // an unconstrained Center just wraps its child.
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '''
<FrameLayout
    android:layout_width="${size.width}" android:layout_height="${size.height}">
    <FrameLayout
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="center">
        ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
    </FrameLayout>
</FrameLayout>''';
  }
}

/// Maps [MAlignment] to an Android gravity string.
///
/// start/end rather than left/right so alignment mirrors in RTL locales.
String alignmentGravity(String? name) => switch (name) {
      'topStart' => 'top|start',
      'topCenter' => 'top|center_horizontal',
      'topEnd' => 'top|end',
      'centerStart' => 'center_vertical|start',
      'center' => 'center',
      'centerEnd' => 'center_vertical|end',
      'bottomStart' => 'bottom|start',
      'bottomCenter' => 'bottom|center_horizontal',
      'bottomEnd' => 'bottom|end',
      _ => 'center',
    };

class AlignHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWAlign';
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
    final gravity = alignmentGravity(node.data['alignment'] as String?);
    // The outer box claims the space; layout_gravity on the inner one places the
    // child inside it, which is what FrameLayout honours (android:gravity does
    // not position children).
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    return '''
<FrameLayout
    android:layout_width="${size.width}" android:layout_height="${size.height}">
    <FrameLayout
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:layout_gravity="$gravity">
        ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons)}
    </FrameLayout>
</FrameLayout>''';
  }
}

class SizedBoxHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWSizedBox';
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
    final w = node.data['width'];
    final h = node.data['height'];
    // An unset axis adopts the parent's constraint, as Flutter's SizedBox does:
    // inside a Column a height-only box still spans the width. Hard-coding
    // wrap_content made a full-width pill collapse to its content.
    // Outside a LinearLayout linearChildSize gives match_parent, so a bare gap
    // in a stack still fills — which is what a spacer there should do.
    final parent = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final width = w != null ? '${w}dp' : parent.width;
    final height = h != null ? '${h}dp' : parent.height;

    final childJson = node.data['child'];
    if (childJson == null) {
      // FrameLayout, not Space or View: RemoteViews refuses to inflate either.
      return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height" />''';
    }
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons)}
</FrameLayout>''';
  }
}

class FlexibleHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWFlexible';
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
    // A weight below 1 would silently collapse the child to nothing.
    final flexValue = node.data['flex'];
    final flex = (flexValue is num && flexValue >= 1) ? flexValue.toInt() : 1;

    if (!isInsideLinearLayout) {
      // Weights only mean anything to a LinearLayout. Outside one, fill instead
      // of emitting a weight the parent will ignore.
      return '''
<FrameLayout
    android:layout_width="match_parent" android:layout_height="match_parent">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons)}
</FrameLayout>''';
    }

    // 0dp on the main axis is what makes the weight decide the size; anything
    // else is added to the measured content first.
    //
    // The cross axis must match linearChildSize: a Row is wrap_content tall, so
    // a match_parent child height is a circular constraint that Android resolves
    // to zero — which made the child disappear entirely.
    final cross = linearChildSize(
      isInsideLinearLayout: true,
      parentIsVertical: isVertical,
    );
    final width = isVertical ? cross.width : '0dp';
    final height = isVertical ? '0dp' : cross.height;
    return '''
<FrameLayout
    android:layout_width="$width" android:layout_height="$height"
    android:layout_weight="$flex">
    ${context.nodeToXml(child, usedBinds, visibilityKeys, timers, buttons, isInsideLinearLayout: false)}
</FrameLayout>''';
  }
}

/// Reserves the `ImageView` a sparkline is rasterised into.
///
/// RemoteViews has no vector drawing at all, so unlike iOS the chart cannot be
/// described in the layout — the provider draws it with Canvas at update time
/// and sets the resulting bitmap.
class SparklineHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWSparkline';
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
    final bindMap = node.data['bind'];
    if (bindMap is! Map || bindMap['key'] == null) {
      return '<!-- sparkline has no bound series -->';
    }
    final key = bindMap['key'] as String;
    final viewId = context.uniqueViewId('hw_spark', key);

    final colorData = node.data['color'];
    final color = (colorData is Map && colorData['hex'] != null)
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FF38BDF8';
    context.registerSparkline(
      viewId,
      key,
      color: color,
      stroke: (node.data['strokeWidth'] ?? 2).toDouble(),
      fill: node.data['fill'] == true,
    );

    final height = node.data['height'];
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final h = height != null ? '${height}dp' : size.height;
    return '<ImageView android:id="@+id/$viewId" '
        'android:layout_width="${size.width}" android:layout_height="$h" '
        'android:scaleType="fitXY" />';
  }
}

/// Reserves the `ImageView` a bar chart is rasterised into.
class BarChartHandler extends AndroidNodeHandler {
  @override
  String get type => 'HWBarChart';
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
    final bindMap = node.data['bind'];
    if (bindMap is! Map || bindMap['key'] == null) {
      return '<!-- bar chart has no bound series -->';
    }
    final key = bindMap['key'] as String;
    final viewId = context.uniqueViewId('hw_bars', key);

    final colorData = node.data['color'];
    final color = (colorData is Map && colorData['hex'] != null)
        ? context.parseColor(colorData.cast<String, dynamic>())
        : '#FF38BDF8';
    context.registerBarChart(
      viewId,
      key,
      color: color,
      spacing: (node.data['spacing'] ?? 3).toDouble(),
      radius: (node.data['radius'] ?? 2).toDouble(),
    );

    final height = node.data['height'];
    final size = linearChildSize(
      isInsideLinearLayout: isInsideLinearLayout,
      parentIsVertical: isVertical,
    );
    final h = height != null ? '${height}dp' : size.height;
    return '<ImageView android:id="@+id/$viewId" '
        'android:layout_width="${size.width}" android:layout_height="$h" '
        'android:scaleType="fitXY" />';
  }
}

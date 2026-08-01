// Layout primitives and shared helpers for the Android generator.
part of '../android.dart';

abstract class AndroidNodeHandler {
  String get type;
  String handle(
    IRNode node,
    Map<String, Set<String>> usedBinds,
    List<String> visibilityKeys,
    Map<String, String> timers,
    List<Map<String, dynamic>> buttons,
    AndroidGenerator context, {
    bool isInsideLinearLayout = false,
    bool isVertical = true,
  });
}

/// Sentinel placed as the first line of generated XML files so the CLI
/// `clean` command can identify generated artifacts.
const String xmlSentinel = '<!-- MOSAIC-GENERATED -->';

/// Sentinel placed as the first line of generated Kotlin files.
const String kotlinSentinel = '// MOSAIC-GENERATED — do not edit';

/// Layout params for any node nested in a Column/Row, sized to the parent's
/// axis the way Flutter sizes them.
///
/// **Every handler that emits a container must use this** rather than
/// hard-coding sizes. A horizontal LinearLayout is `wrap_content` tall, so a
/// child asking for `match_parent` height is a circular constraint that Android
/// resolves to **zero** — the view, and everything inside it, silently does not
/// render. There is no error, no log, and the generated XML looks correct; the
/// only symptom is a blank space on the device.
///
/// That trap has been hit by MPadding, MFlexible, MCenter, MStack, MNetworkImage
/// and MListView at various points. `row_child_sizing_test.dart` sweeps for it,
/// so a new handler that hard-codes `match_parent` fails there rather than on
/// someone's home screen.
({String width, String height}) linearChildSize({
  required bool isInsideLinearLayout,
  required bool parentIsVertical,
}) {
  // Directly in the widget cell (or a FrameLayout): fill it.
  //
  // `isInsideLinearLayout` describes the node's **immediate** parent, so a
  // handler that emits its own `FrameLayout` wrapper must render its child with
  // `isInsideLinearLayout: false` — the child's parent is that FrameLayout, not
  // the Row or Column the wrapper itself sits in. Forwarding the flag instead
  // left `MCenter` inside a fixed-size `MContainer` sized `wrap_content`, so it
  // had no space to centre within and the icon pinned to the top-left corner.
  //
  // Filling here is safe: `FrameLayout.onMeasure` sizes itself from its
  // non-match_parent children first, then re-measures the match_parent ones
  // against that result. A `wrap_content` FrameLayout therefore still collapses
  // to its content rather than running away, while a fixed-size one finally
  // gives the child the box it needs.
  if (!isInsideLinearLayout) {
    return (width: 'match_parent', height: 'match_parent');
  }
  // Vertical parent: fill the cross axis, size to content on the main axis.
  if (parentIsVertical) {
    return (width: 'match_parent', height: 'wrap_content');
  }
  // Horizontal parent: size to content so siblings keep their space and the
  // row's wrap_content height stays resolvable.
  return (width: 'wrap_content', height: 'wrap_content');
}

/// Builds a single weighted spacer view for a LinearLayout. On a vertical
/// layout the spacer grows on height (0dp + weight); on a horizontal layout it
/// grows on width. Used to approximate Flutter's
/// spaceBetween/spaceAround/spaceEvenly main-axis alignments, which Android's
/// LinearLayout `gravity` cannot express directly.
///
/// Uses `FrameLayout` rather than the more natural `Space`: RemoteViews only
/// inflates classes annotated `@RemoteView`, and `android.widget.Space` is not
/// one of them. A `Space` here fails the whole layout with "Class not allowed
/// to be inflated", which the launcher reports as "Can't load widget".
String _mosaicSpacerView(bool isVertical, {String weight = '1'}) {
  final width = isVertical ? 'wrap_content' : '0dp';
  final height = isVertical ? '0dp' : 'wrap_content';
  return '<FrameLayout android:layout_width="$width" android:layout_height="$height" android:layout_weight="$weight" />';
}

/// Maps an [MStack] alignment name to an Android gravity string.
///
/// Uses RTL-friendly `start`/`end` rather than `left`/`right`. Absent or
/// unknown names fall back to `top|start` (matches the DSL default topLeading).
String _stackAlignmentGravity(String? alignment) {
  switch (alignment) {
    case 'topLeading':
      return 'top|start';
    case 'top':
      return 'top|center_horizontal';
    case 'topTrailing':
      return 'top|end';
    case 'leading':
      return 'center_vertical|start';
    case 'center':
      return 'center';
    case 'trailing':
      return 'center_vertical|end';
    case 'bottomLeading':
      return 'bottom|start';
    case 'bottom':
      return 'bottom|center_horizontal';
    case 'bottomTrailing':
      return 'bottom|end';
    default:
      return 'top|start';
  }
}

/// Injects `android:layout_gravity="[gravity]"` into [renderedChild] if and
/// only if the child's root element does not already carry a `layout_gravity`
/// attribute. This preserves `MPositioned` children which set their own
/// `layout_gravity` via [PositionedHandler].
///
/// Only the FIRST element open-tag is touched — nested descendants are left
/// intact. Children that are pure XML comments are returned unchanged.
String _applyStackAlignment(String renderedChild, String gravity) {
  // If the child already carries layout_gravity, leave it untouched.
  if (renderedChild.contains('android:layout_gravity=')) return renderedChild;
  // Inject just before the first `>` or `/>` that closes the root open tag.
  final re = RegExp(r'(\s*)(\/?>)');
  var done = false;
  return renderedChild.replaceFirstMapped(re, (m) {
    if (done) return m.group(0)!;
    done = true;
    return '${m.group(1)} android:layout_gravity="$gravity"${m.group(2)}';
  });
}

/// Rewrites the cross-axis dimension of a rendered child element to
/// `match_parent` to implement Flutter's `CrossAxisAlignment.stretch`. For a
/// vertical column the cross axis is width; for a horizontal row it is height.
/// Only the FIRST matching attribute is rewritten — that is the child's own
/// root element, leaving any nested descendants untouched. Children that are
/// pure comments (no element) are returned unchanged.
String _applyCrossAxisStretch(String renderedChild, bool isVertical) {
  final attr = isVertical ? 'android:layout_width' : 'android:layout_height';
  final re = RegExp('$attr="[^"]*"');
  if (!re.hasMatch(renderedChild)) return renderedChild;
  var done = false;
  return renderedChild.replaceFirstMapped(re, (m) {
    if (done) return m.group(0)!;
    done = true;
    return '$attr="match_parent"';
  });
}

/// Interleaves [renderedChildren] with weighted spacer views to approximate the
/// given main-axis [alignment] (one of spaceBetween/spaceAround/spaceEvenly).
/// Returns the children list unchanged for any other alignment. The returned
/// list may be prefixed with an approximation comment for spaceAround, whose
/// exact per-child symmetric spacing is not expressible with integer LinearLayout
/// weights — it is approximated with half-weight end spacers.
List<String> _injectMainAxisSpacers(
  List<String> renderedChildren,
  String? alignment,
  bool isVertical,
) {
  if (renderedChildren.isEmpty) return renderedChildren;
  switch (alignment) {
    case 'spaceBetween':
      final out = <String>[];
      for (var i = 0; i < renderedChildren.length; i++) {
        if (i > 0) out.add(_mosaicSpacerView(isVertical));
        out.add(renderedChildren[i]);
      }
      return out;
    case 'spaceEvenly':
      final out = <String>[_mosaicSpacerView(isVertical)];
      for (final c in renderedChildren) {
        out.add(c);
        out.add(_mosaicSpacerView(isVertical));
      }
      return out;
    case 'spaceAround':
      // Exact spaceAround would need half-weight gaps at the ends and
      // full-weight gaps between. Android LinearLayout supports fractional
      // weights, so approximate with weight 0.5 ends and weight 1 between.
      final out = <String>[
        '<!-- spaceAround approximated -->',
        _mosaicSpacerView(isVertical, weight: '0.5'),
      ];
      for (var i = 0; i < renderedChildren.length; i++) {
        if (i > 0) out.add(_mosaicSpacerView(isVertical));
        out.add(renderedChildren[i]);
      }
      out.add(_mosaicSpacerView(isVertical, weight: '0.5'));
      return out;
    default:
      return renderedChildren;
  }
}

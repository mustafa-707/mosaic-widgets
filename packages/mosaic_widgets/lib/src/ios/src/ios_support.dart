// Shared constants, escaping, and the node-handler interface.
part of '../ios.dart';

/// Sentinel marker that must be the FIRST line of every generated .swift file.
/// The CLI `clean` command checks the first line for this marker.
const String kGeneratedSentinel = '// MOSAIC-GENERATED — do not edit';

/// Wraps [content] in `#if os(iOS)` while keeping [kGeneratedSentinel] on the
/// first line.
///
/// Used for the frameworks that have no macOS counterpart — ActivityKit and
/// ControlWidget. A shared widget-extension target can be built for both
/// platforms, so those files still have to compile on macOS even though the
/// feature cannot ship there; fencing beats omitting the file, which would
/// leave the bundle referencing a type that does not exist.
///
/// The fence must come *after* the sentinel: `clean` and orphan pruning
/// recognise generated files by that first line, and putting `#if` above it
/// made them look hand-written.
String fenceIOSOnly(String content) {
  final lines = content.split('\n');
  if (lines.isNotEmpty && lines.first.contains('MOSAIC-GENERATED')) {
    return '${lines.first}\n#if os(iOS)\n${lines.skip(1).join('\n')}\n#endif\n';
  }
  return '#if os(iOS)\n$content\n#endif\n';
}

/// Tags the `CFBundleURLTypes` block Mosaic writes into the host `Info.plist`,
/// so a changed `deep_link_scheme` replaces it instead of accumulating.
const String plistUrlTypesMarker = 'MOSAIC-GENERATED';

/// Closes the fence opened by [plistUrlTypesMarker]. The block nests an
/// `<array>` inside an `<array>`, so an explicit end marker is what lets it be
/// removed as a unit rather than up to the first closing tag.
const String plistUrlTypesEndMarker = '/MOSAIC-GENERATED';

/// Escapes the five XML entities. A plist is XML, so an unescaped `&` in a
/// bundle id or scheme would corrupt the file and fail the Xcode build.
String xmlEscapeIos(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

abstract class IosNodeHandler {
  String get type;

  /// Renders [node].
  ///
  /// [isInsideStack] is true when the parent is an HStack/VStack, with
  /// [isVertical] telling which. A node that fills unconditionally squeezes
  /// its siblings inside a stack, so anything emitting an infinite frame has
  /// to consult these — the Android generator has carried the same two flags
  /// since layout bugs there proved parent-blind handlers cannot be correct.
  String handle(IRNode node, IosGenerator context,
      {bool isInsideStack = false, bool isVertical = true});
}

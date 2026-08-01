// Shared constants, escaping, and the node-handler interface.
part of '../ios.dart';

/// Sentinel marker that must be the FIRST line of every generated .swift file.
/// The CLI `clean` command checks the first line for this marker.
const String kGeneratedSentinel = '// MOSAIC-GENERATED — do not edit';

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

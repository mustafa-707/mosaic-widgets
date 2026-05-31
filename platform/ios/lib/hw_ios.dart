import 'dart:io';
import 'package:hw_core/hw_core.dart';
import 'package:path/path.dart' as p;

/// Sentinel marker that must be the FIRST line of every generated .swift file.
/// The CLI `clean` command checks the first line for this marker.
const String kGeneratedSentinel = '// MOSAIC-GENERATED — do not edit';

abstract class IosNodeHandler {
  String get type;
  String handle(IRNode node, IosGenerator context);
}

class IosGenerator {
  final HWConfig config;
  final List<IRDefinition> definitions;
  final Map<String, IosNodeHandler> _handlers = {};

  IosGenerator({required this.config, required this.definitions}) {
    _registerHandlers();
  }

  void _registerHandlers() {
    _register(ColumnHandler());
    _register(RowHandler());
    _register(TextHandler());
    _register(ContainerHandler());
    _register(PaddingHandler());
    _register(StackHandler());
    _register(SpacerHandler());
    _register(ButtonHandler());
    _register(VisibilityHandler());
    _register(ImageHandler());
    _register(ProgressBarHandler());
    _register(ListViewHandler());
    _register(TimerHandler());
    _register(CenterHandler());
    _register(PositionedHandler());
  }

  void _register(IosNodeHandler handler) {
    _handlers[handler.type] = handler;
  }

  Future<void> generate(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    for (final def in definitions) {
      final swiftFile = File(p.join(iosDir.path, '${def.name}.swift'));
      await swiftFile.writeAsString(_generateSwiftUiWidget(def));
    }

    final bundleFile = File(p.join(iosDir.path, 'HomeWidgetBundle.swift'));
    await bundleFile.writeAsString(_generateWidgetBundle());

    await generateCore(projectRoot);
  }

  String _generateWidgetBundle() {
    final widgets = definitions
        .map((def) => '        ${def.name}Widget()')
        .join('\n');
    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit

@main
struct HomeWidgetBundle: WidgetBundle {
    var body: some Widget {
$widgets
    }
}
''';
  }

  Future<void> generateCore(String projectRoot) async {
    final iosDir = Directory(p.join(projectRoot, 'ios', 'HomeWidgetExtension'));
    if (!iosDir.existsSync()) iosDir.createSync(recursive: true);

    final coreFile = File(p.join(iosDir.path, 'HomeWidgetCore.swift'));
    await coreFile.writeAsString('''$kGeneratedSentinel
import SwiftUI
import UIKit

let kMosaicAppGroup = "${config.app.iosAppGroup}"

/// Resolves a file-image path to a UIImage. Absolute paths are loaded directly;
/// relative paths are resolved against the App Group container. Returns nil when
/// the path is nil/empty or no image could be loaded.
func resolveFileImage(_ path: String?) -> UIImage? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("/") {
        return UIImage(contentsOfFile: path)
    }
    if let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: kMosaicAppGroup) {
        let full = container.appendingPathComponent(path).path
        if let img = UIImage(contentsOfFile: full) { return img }
    }
    return UIImage(contentsOfFile: path)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
''');
  }

  String _generateSwiftUiWidget(IRDefinition def) {
    final usedKeys = collectBindKeys(def.root).toList()..sort();
    final keyList =
        usedKeys.map((k) => '"${swiftEscape(k)}"').join(', ');
    return '''$kGeneratedSentinel
import SwiftUI
import WidgetKit

struct ${def.name}Entry: TimelineEntry {
    let date: Date
    let data: [String: Any]
}

struct ${def.name}Provider: TimelineProvider {
    func placeholder(in context: Context) -> ${def.name}Entry {
        ${def.name}Entry(date: Date(), data: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (${def.name}Entry) -> ()) {
        let entry = ${def.name}Entry(date: Date(), data: loadData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = ${def.name}Entry(date: Date(), data: loadData())
        
        ${def.updateInterval != null ? '''
        let nextUpdate = Calendar.current.date(byAdding: .second, value: ${def.updateInterval! ~/ 1000}, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        ''' : '''
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        '''}
        
        completion(timeline)
    }

    // The App Group container path, used to resolve relative image file paths.
    private static let appGroup = "${config.app.iosAppGroup}"

    private func loadData() -> [String: Any] {
        var data: [String: Any] = [:]
        guard let defaults = UserDefaults(suiteName: ${def.name}Provider.appGroup) else {
            return ["btc_price": "GRP ERR", "battery_level": "ERR", "news_title": "App Group Config Error"]
        }
        for k in [$keyList] {
            if let v = defaults.object(forKey: k) {
                data[k] = v
            }
        }
        return data
    }
}

struct ${def.name}View: View {
    var entry: ${def.name}Entry
    
    var body: some View {
        GeometryReader { geometry in
            ${nodeToSwiftUI(def.root)}
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .widgetURL(URL(string: loadGlobalUrl()))
    }

    private func loadGlobalUrl() -> String {
        return entry.data["global_url"] as? String ?? ""
    }
}

struct ${def.name}Widget: Widget {
    let kind: String = "${def.name}"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ${def.name}Provider()) { entry in
            ${def.name}View(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("${def.name}")
        .description("This is an auto-generated home widget.")
        .supportedFamilies([${config.widgets.firstWhere((w) => w.name == def.name, orElse: () => throw StateError('No widget config entry named "${def.name}". Add it to mosaic.yaml.')).ios.families.map((f) => '.$f').join(', ')}])
        .contentMarginsDisabled()
    }
}
''';
  }

  String _colorToSwift(Map<String, dynamic>? data) {
    if (data == null) return 'Color.clear';
    final hex = data['hex'] as String;
    final opacity = (data['opacity'] ?? 1.0).toDouble();

    if (hex.startsWith('#') && hex.length == 7) {
      final r = int.parse(hex.substring(1, 3), radix: 16) / 255.0;
      final g = int.parse(hex.substring(3, 5), radix: 16) / 255.0;
      final b = int.parse(hex.substring(5, 7), radix: 16) / 255.0;
      return 'Color(red: $r, green: $g, blue: $b, opacity: $opacity)';
    }
    return 'Color(hex: "$hex").opacity($opacity)';
  }

  String nodeToSwiftUI(IRNode node) {
    final handler = _handlers[node.type];
    if (handler != null) {
      return handler.handle(node, this);
    }
    throw UnsupportedError('No iOS handler for node type "${node.type}".');
  }

  /// Walks the IR tree rooted at [node] and collects every `HWBind` key that the
  /// widget actually uses. Used to populate `loadData()` with only the keys the
  /// widget reads, instead of leaking all keys via `dictionaryRepresentation()`.
  Set<String> collectBindKeys(IRNode node) {
    final keys = <String>{};
    _collectFromValue(node.toJson(), keys);
    // global_url is always read by the generated view's loadGlobalUrl().
    keys.add('global_url');
    return keys;
  }

  void _collectFromValue(Object? value, Set<String> keys) {
    if (value is Map) {
      if (value['__type'] == 'HWBind' && value['key'] is String) {
        keys.add(value['key'] as String);
      }
      for (final v in value.values) {
        _collectFromValue(v, keys);
      }
    } else if (value is List) {
      for (final v in value) {
        _collectFromValue(v, keys);
      }
    }
  }
}

class ColumnHandler extends IosNodeHandler {
  @override
  String get type => 'HWColumn';
  @override
  String handle(IRNode node, IosGenerator context) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(IRNode.fromJson(e as Map<String, dynamic>)))
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

    final alignment = _mapAlignment(node.data['crossAxisAlignment']);
    // Force spacing 0 because we handle distribution with Spacers
    return '''
VStack(alignment: $alignment, spacing: 0) {
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.leading';
      case 'end':
        return '.trailing';
      default:
        return '.center';
    }
  }
}

class RowHandler extends IosNodeHandler {
  @override
  String get type => 'HWRow';
  @override
  String handle(IRNode node, IosGenerator context) {
    var childrenNodes = ((node.data['children'] as List?) ?? const [])
        .map((e) => context.nodeToSwiftUI(IRNode.fromJson(e as Map<String, dynamic>)))
        .toList();

    final mainAxis = node.data['mainAxisAlignment'] ?? 'start';
    if (mainAxis == 'spaceBetween' && childrenNodes.length > 1) {
      final newChildren = <String>[];
      for (var i = 0; i < childrenNodes.length; i++) {
        newChildren.add(childrenNodes[i]);
        if (i < childrenNodes.length - 1) newChildren.add('Spacer()');
      }
      childrenNodes = newChildren;
    } else if (mainAxis == 'spaceEvenly' || mainAxis == 'spaceAround') {
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

    final alignment = _mapAlignment(node.data['crossAxisAlignment']);
    return '''
HStack(alignment: $alignment, spacing: 0) {
    ${childrenNodes.join('\n')}
}''';
  }

  String _mapAlignment(String? cross) {
    switch (cross) {
      case 'start':
        return '.top';
      case 'end':
        return '.bottom';
      default:
        return '.center'; // vertically centered
    }
  }
}

class TextHandler extends IosNodeHandler {
  @override
  String get type => 'HWText';
  @override
  String handle(IRNode node, IosGenerator context) {
    final text = node.data['text'];
    final isBind = text is Map && text['__type'] == 'HWBind';
    final textValue = isBind
        ? '"\\(entry.data[\"${swiftEscape(text['key'] as String)}\"] as? String ?? String(describing: entry.data[\"${swiftEscape(text['key'] as String)}\"] ?? \"--\"))"'
        : '"${swiftEscape(text as String)}"';
    final style = node.data['style'] ?? {};
    final bold = style['bold'] == true ? '.bold()' : '';
    final color = style['color'] != null
        ? '.foregroundColor(${context._colorToSwift(style['color'])})'
        : '';
    final size = style['size'] != null
        ? '.font(.system(size: ${style['size']}))'
        : '';
    // Use dynamicTypeSize to prevent text scaling with device accessibility settings
    return 'Text($textValue)$bold$color$size.dynamicTypeSize(.large)';
  }
}

class ContainerHandler extends IosNodeHandler {
  @override
  String get type => 'HWContainer';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final radius = node.data['radius'] ?? 0;
    final background = node.data['background']?['hex'];
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

    // 3. Background
    if (gradient != null && gradient['__type'] == 'HWLinearGradient') {
      final colors = (gradient['colors'] as List)
          .map((c) => 'Color(hex: "${c['hex']}")')
          .join(', ');
      modifiers.add(
        '.background(LinearGradient(gradient: Gradient(colors: [$colors]), startPoint: .top, endPoint: .bottom))',
      );
    } else if (background != null) {
      modifiers.add(
        '.background(${context._colorToSwift(node.data['background'])})',
      );
    }

    // 4. Clip shape (corner radius) or explicit clip
    if (radius > 0) {
      modifiers.add('.clipShape(RoundedRectangle(cornerRadius: $radius))');
    } else if (width != null || height != null) {
      // Ensure content doesn't overflow if explicit size is set
      modifiers.add('.clipped()');
    }

    // 5. Border using overlay (preserves rounded corners)
    if (border != null) {
      modifiers.add(
        '.overlay(RoundedRectangle(cornerRadius: $radius).stroke(Color(hex: "${border['color']['hex']}"), lineWidth: ${border['width']}))',
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
  String handle(IRNode node, IosGenerator context) {
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
  String handle(IRNode node, IosGenerator context) {
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
      case 'topCenter':
        return '.top';
      case 'topRight':
        return '.topTrailing';
      case 'centerLeft':
        return '.leading';
      case 'center':
        return '.center';
      case 'centerRight':
        return '.trailing';
      case 'bottomLeft':
        return '.bottomLeading';
      case 'bottomCenter':
        return '.bottom';
      case 'bottomRight':
        return '.bottomTrailing';
      case 'topLeft':
      default:
        return '.topLeading';
    }
  }
}

class SpacerHandler extends IosNodeHandler {
  @override
  String get type => 'HWSpacer';
  @override
  String handle(IRNode node, IosGenerator context) {
    return 'Spacer()';
  }
}

class ButtonHandler extends IosNodeHandler {
  @override
  String get type => 'HWButton';
  @override
  String handle(IRNode node, IosGenerator context) {
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
      // Build the mosaic-callback URL safely at runtime using percent-encoding.
      return '''
if let _encoded = "$callbackName".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
   let _u = URL(string: "mosaic-callback://\\(_encoded)") {
    Link(destination: _u) {
        $childSwift
    }
}''';
    } else {
      // hwrefresh — static well-formed URL, still no force-unwrap
      return '''
if let _u = URL(string: "hwrefresh://") {
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
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final replacement = node.data['replacement'] != null
        ? IRNode.fromJson(node.data['replacement'] as Map<String, dynamic>)
        : null;
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = swiftEscape(bindMap['key'] as String);
    final condition = '(entry.data["$key"] as? NSNumber)?.boolValue ?? false';
    return '''
if $condition {
    ${context.nodeToSwiftUI(child)}
} else {
    ${replacement != null ? context.nodeToSwiftUI(replacement) : 'EmptyView()'}
}''';
  }
}

class ImageHandler extends IosNodeHandler {
  @override
  String get type => 'HWImage';
  @override
  String handle(IRNode node, IosGenerator context) {
    final source = node.data['source'];
    final type = source['__type'];
    final fit = node.data['fit'];

    String imageCode;
    if (type == 'HWAssetImage') {
      imageCode = 'Image("${swiftEscape(source['path'] as String)}")';
    } else if (type == 'HWFileImage') {
      final path = source['path'];
      final isBind = path is Map && path['__type'] == 'HWBind';
      final pathValue = isBind
          ? '(entry.data["${swiftEscape(path['key'] as String)}"] as? String)'
          : '"${swiftEscape(path.toString())}"';
      // Resolve the file via the shared helper (absolute paths used as-is,
      // relative paths resolved against the App Group container). Nil-safe.
      imageCode = 'Image(uiImage: resolveFileImage($pathValue) ?? UIImage())';
    } else {
      return '// Unsupported Image Source';
    }

    String modifiers = '.resizable()';
    if (fit == 'cover' || fit == 'fill') {
      modifiers += '.aspectRatio(contentMode: .fill)';
    } else if (fit == 'contain') {
      modifiers += '.aspectRatio(contentMode: .fit)';
    } else {
      // Default to fill/stretch behavior or retain resizable
    }

    return '$imageCode$modifiers';
  }
}

class ProgressBarHandler extends IosNodeHandler {
  @override
  String get type => 'HWProgressBar';
  @override
  String handle(IRNode node, IosGenerator context) {
    final value = node.data['value'];
    final isBind = value is Map && value['__type'] == 'HWBind';
    // For binds, resolve the value from entry data at runtime. NSNumber covers
    // Int/Double/Bool stored in UserDefaults; fall back to parsing a String.
    final valStr = isBind
        ? '((entry.data["${swiftEscape(value['key'] as String)}"] as? NSNumber)?.doubleValue ?? Double("\\(entry.data["${swiftEscape(value['key'] as String)}"] ?? "0")") ?? 0)'
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
  String handle(IRNode node, IosGenerator context) {
    final bindMap = node.data['bind'] as Map<String, dynamic>?;
    if (bindMap == null) return '// missing bind';
    final key = bindMap['key'] as String;
    // VERY experimental ListView for WidgetKit (usually uses ForEach)
    return '''
ForEach(entry.data["$key"] as? [[String: Any]] ?? [], id: \\.self.description) { item in
    // Item template generation would need a way to bind to "item"
    Text("List Item")
}''';
  }
}

class TimerHandler extends IosNodeHandler {
  @override
  String get type => 'HWTimer';
  @override
  String handle(IRNode node, IosGenerator context) {
    final targetEpoch = node.data['target'];
    final isBind = targetEpoch is Map && targetEpoch['__type'] == 'HWBind';

    final String dateExpr;
    if (isBind) {
      // Read the target epoch (milliseconds) from entry data at runtime.
      final key = swiftEscape(targetEpoch['key'] as String);
      dateExpr =
          'Date(timeIntervalSince1970: ((entry.data["$key"] as? NSNumber)?.doubleValue ?? 0) / 1000.0)';
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
    final size = style['size'] != null
        ? '.font(.system(size: ${style['size']}))'
        : '';

    return 'Text($dateExpr, style: .timer)$bold$color$size.monospacedDigit()';
  }
}

class CenterHandler extends IosNodeHandler {
  @override
  String get type => 'HWCenter';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity)''';
  }
}

class PositionedHandler extends IosNodeHandler {
  @override
  String get type => 'HWPositioned';
  @override
  String handle(IRNode node, IosGenerator context) {
    final childJson = node.data['child'];
    if (childJson == null) return '// missing child';
    final child = IRNode.fromJson(childJson as Map<String, dynamic>);
    final top = node.data['top'];
    final left = node.data['left'];
    final right = node.data['right'];
    final bottom = node.data['bottom'];

    String alignment = '.topLeading';
    if (top != null && right != null)
      alignment = '.topTrailing';
    else if (bottom != null && left != null)
      alignment = '.bottomLeading';
    else if (bottom != null && right != null)
      alignment = '.bottomTrailing';
    else if (top != null)
      alignment = '.top';
    else if (bottom != null)
      alignment = '.bottom';
    else if (left != null)
      alignment = '.leading';
    else if (right != null)
      alignment = '.trailing';

    return '''
${context.nodeToSwiftUI(child)}
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: $alignment)''';
  }
}

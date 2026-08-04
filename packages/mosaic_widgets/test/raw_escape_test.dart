import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_widgets/dsl.dart';

/// The ceiling remover.
///
/// Every other node is a bounded vocabulary, which is the one real advantage a
/// thin bridge like `home_widget` has: there, you write arbitrary SwiftUI and
/// Glance yourself. `MRaw` closes that — you write the platform's own UI
/// language and still keep the generated App Group wiring, timeline, data store
/// and update path.
void main() {
  test('a snippet travels for each platform', () {
    final json = const MRaw(
      swift: 'Text("hi")',
      androidXml: '<TextView />',
    ).toJson();
    expect(json['__type'], 'HWRaw');
    expect(json['swift'], 'Text("hi")');
    expect(json['androidXml'], '<TextView />');
  });

  test('one platform only is legitimate', () {
    // Shipping a feature on a single platform is a real choice, not an error —
    // the other side renders nothing.
    final json =
        const MRaw(swift: 'Gauge(value: 0.7) { Text("CPU") }').toJson();
    expect(json['swift'], isNotNull);
    expect(json.containsKey('androidXml'), isFalse);
  });

  test('declared binds are carried', () {
    // The generator cannot parse a snippet, so it cannot discover the keys the
    // snippet reads. Declaring them is what keeps the data flowing.
    final json = const MRaw(
      swift: 'Text(entry.data["temp"] as? String ?? "--")',
      binds: ['temp'],
    ).toJson();
    expect(json['binds'], ['temp']);
  });

  test('an empty node carries no keys at all', () {
    // Nothing is inferred: an MRaw with no binds must not silently register
    // any, or the provider does work for data nobody reads.
    expect(const MRaw().toJson().containsKey('binds'), isFalse);
  });

  test('the snippet is not escaped or altered', () {
    // Quotes, interpolation and newlines have to survive verbatim, or the
    // developer's Swift stops being their Swift.
    const swift = 'Text("\\(entry.data["x"] ?? "")")\n  .bold()';
    expect(const MRaw(swift: swift).toJson()['swift'], swift);
  });
}

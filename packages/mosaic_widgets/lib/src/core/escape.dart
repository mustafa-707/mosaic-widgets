/// Escapes a string for safe interpolation into an XML attribute/text value.
String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Escapes a string for a Kotlin double-quoted string literal.
String kotlinEscape(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

/// Escapes a string for a Swift double-quoted string literal.
String swiftEscape(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t');

/// Converts an arbitrary string into a valid identifier.
String sanitizeIdentifier(String s) {
  final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  if (cleaned.isEmpty) return '_';
  return RegExp(r'^[0-9]').hasMatch(cleaned) ? '_$cleaned' : cleaned;
}

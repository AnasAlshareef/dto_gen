import 'dart:convert';
import 'dart:io';

/// Generate dart_mappable DTO classes from a JSON API sample.
///
///   dart run bin/dto_gen.dart <sample.json> <ClassName> [out.dart]
///   cat sample.json | dart run bin/dto_gen.dart - <ClassName>
///   dart run bin/dto_gen.dart --selftest
///
/// Nullability note: a single sample cannot show which fields the API may
/// omit. A null value becomes a nullable field; any present value becomes a
/// required, non-null field. Relax to nullable where the API can skip it.
void main(List<String> args) {
  if (args.contains('--selftest')) {
    _selfTest();
    return;
  }
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run bin/dto_gen.dart <sample.json|-> <ClassName> [out.dart]',
    );
    exitCode = 64;
    return;
  }

  final source =
      args[0] == '-' ? _readAllStdin() : File(args[0]).readAsStringSync();
  final className = args[1];
  final outPath = args.length > 2 ? args[2] : null;
  final partName = outPath != null
      ? outPath.split(Platform.pathSeparator).last.replaceAll('.dart', '')
      : _snake(className);

  final decoded = jsonDecode(source);
  final root = decoded is List
      ? (decoded.isEmpty
            ? <String, dynamic>{}
            : decoded.first as Map<String, dynamic>)
      : decoded as Map<String, dynamic>;

  final code = generate(root, className, partName);

  if (outPath == null) {
    stdout.write(code);
  } else {
    File(outPath).writeAsStringSync(code);
    stderr.writeln('wrote $outPath — now run build_runner for $partName.mapper.dart');
  }
}

String _readAllStdin() {
  final buf = StringBuffer();
  String? line;
  while ((line = stdin.readLineSync()) != null) {
    buf.writeln(line);
  }
  return buf.toString();
}

/// Builds the full file: imports, part directive, and every class (root plus
/// nested), deepest emitted after the ones that reference them so the file
/// reads top-down from the root.
String generate(Map<String, dynamic> root, String className, String partName) {
  final classes = <String, String>{};
  _buildClass(className, root, classes);

  final buf = StringBuffer()
    ..writeln("import 'package:dart_mappable/dart_mappable.dart';")
    ..writeln()
    ..writeln("part '$partName.mapper.dart';")
    ..writeln();
  // Root first (it was added first), then nested in insertion order.
  buf.write(classes.values.join('\n'));
  return buf.toString();
}

void _buildClass(String name, Map<String, dynamic> json, Map<String, String> out) {
  if (out.containsKey(name)) return;
  out[name] = ''; // reserve the slot so recursion into a self-referencing shape stops

  final ctor = <String>[];
  final fields = <String>[];

  json.forEach((key, value) {
    final field = _camel(key);
    final nullable = value == null;
    final base = _dartType(value, key, out);
    // `dynamic` is already nullable; `dynamic?` is a compile error.
    final type = nullable && base != 'dynamic' ? '$base?' : base;

    ctor.add(nullable ? '    this.$field,' : '    required this.$field,');

    // shortcut: a key that is a Dart keyword (default, class, new) makes an
    // invalid field name; rename by hand on the rare hit.
    if (_camel(key) != key) {
      fields.add("  @MappableField(key: '$key')");
    }
    fields.add('  final $type $field;');
  });

  final buf = StringBuffer()
    ..writeln('@MappableClass()')
    ..writeln('class $name with ${name}Mappable {')
    ..writeln('  const $name({')
    ..writeln(ctor.join('\n'))
    ..writeln('  });')
    ..writeln()
    ..writeln(fields.join('\n'))
    ..writeln('}');
  out[name] = buf.toString();
}

/// Dart type for a JSON value. Registers a nested class for objects (and for
/// the element type of a list of objects) as a side effect.
String _dartType(dynamic v, String key, Map<String, String> out) {
  if (v == null) return 'dynamic';
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'double';
  if (v is String) return 'String';
  if (v is List) {
    if (v.isEmpty) return 'List<dynamic>';
    return 'List<${_dartType(v.first, _singular(key), out)}>';
  }
  if (v is Map) {
    final name = _pascal(_singular(key));
    _buildClass(name, v.cast<String, dynamic>(), out);
    return name;
  }
  return 'dynamic';
}

String _camel(String s) {
  final parts = s.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return s;
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _pascal(String s) {
  final c = _camel(s);
  return c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);
}

String _snake(String s) => s
    .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .toLowerCase();

/// shortcut: naive de-pluralize (drop trailing s), upgrade if a real plural
/// (categories, boxes) names a nested class wrongly.
String _singular(String s) =>
    s.endsWith('s') && s.length > 1 ? s.substring(0, s.length - 1) : s;

void _selfTest() {
  // snake key -> camel field + @MappableField alias; camelCase/plain key -> none.
  final sample = {
    'id': 7,
    'is_default': true,
    'lat': 32.8872,
    'label': 'home',
    'owner': {'user_id': 3, 'name': 'A'},
    'tags': <String>['x'],
    'notes': null,
  };
  final code = generate(sample, 'SavedPlace', 'saved_place');

  void check(bool ok, String msg) {
    if (!ok) {
      stderr.writeln('FAIL: $msg');
      exitCode = 1;
    }
  }

  check(code.contains("part 'saved_place.mapper.dart';"), 'part directive');
  check(code.contains('class SavedPlace with SavedPlaceMappable'), 'root class');
  check(code.contains("@MappableField(key: 'is_default')\n  final bool isDefault;"),
      'snake key aliased to camel field');
  check(code.contains('final int id;'), 'int, no alias for plain key');
  check(code.contains('final double lat;'), 'double inferred');
  check(!code.contains("key: 'lat'"), 'plain key gets no alias');
  check(code.contains('required this.lat,'), 'present value is required');
  check(code.contains('this.notes,') && code.contains('final dynamic notes;'),
      'null value is nullable, not required');
  check(code.contains('class Owner with OwnerMappable'), 'nested object class');
  check(code.contains('final Owner owner;'), 'nested field typed');
  check(code.contains("@MappableField(key: 'user_id')\n  final int userId;"),
      'nested snake alias');
  check(code.contains('final List<String> tags;'), 'list element type');

  if (exitCode == 0) stdout.writeln('selftest OK');
}

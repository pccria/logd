import 'package:logd/logd.dart';
import 'package:meta/meta.dart';

import 'toon_schema.dart';

/// A strongly-typed, immutable representation of a parsed TOON data row.
///
/// Features typed accessors for standard logging fields ([timestamp], [logger],
/// [level], [message], [error], [stackTrace], [context]) and dynamic indexing
/// via [operator []] for custom or projected context columns.
@immutable
final class ToonRecord {
  /// Creates a [ToonRecord].
  ToonRecord({required final Map<String, Object?> fields, this.schema})
    : fields = Map.unmodifiable(fields);

  /// The raw fields mapped by column name.
  final Map<String, Object?> fields;

  /// The schema governing this record's column alignment, if available.
  final ToonSchema? schema;

  /// The timestamp string recorded at entry emission, if present.
  String? get timestamp => fields['timestamp'] as String?;

  /// The hierarchical logger identifier, if present.
  String? get logger => fields['logger'] as String?;

  /// The call-site file and line origin string, if present.
  String? get origin => fields['origin'] as String?;

  /// The raw level name string (e.g. `'INFO'`, `'ERROR'`), if present.
  String? get levelName => fields['level'] as String?;

  /// The typed [LogLevel] parsed from [levelName], or `null` if unparseable.
  LogLevel? get level {
    final name = levelName?.toLowerCase();
    if (name == null) {
      return null;
    }
    for (final l in LogLevel.values) {
      if (l.name == name) {
        return l;
      }
    }
    return null;
  }

  /// The primary log message content.
  String? get message => fields['message'] as String?;

  /// The serialized error message, if any was recorded.
  String? get error => fields['error'] as String?;

  /// The serialized stack trace string, if any was recorded.
  String? get stackTrace => fields['stackTrace'] as String?;

  /// The structured contextual metadata object, map, or string.
  Object? get context => fields['context'];

  /// Accesses a field value by [column] name.
  ///
  /// Useful for retrieving promoted context columns or arbitrary custom fields.
  Object? operator [](final String column) => fields[column];

  /// Returns a mutable shallow copy of [fields].
  Map<String, Object?> toMap() => Map<String, Object?>.from(fields);

  /// Serializes into a JSON-compatible map.
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(fields);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonRecord &&
          runtimeType == other.runtimeType &&
          _mapEquals(fields, other.fields);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(fields.entries));

  @override
  String toString() => 'ToonRecord($fields)';

  static bool _mapEquals(
    final Map<String, Object?> a,
    final Map<String, Object?> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// An immutable document encapsulating a [ToonSchema] and its parsed [records].
@immutable
final class ToonDocument {
  /// Creates a [ToonDocument].
  ToonDocument({required this.schema, required final List<ToonRecord> records})
    : records = List.unmodifiable(records);

  /// The schema governing the columns and conventions of this document.
  final ToonSchema schema;

  /// The ordered data records parsed from the document body.
  final List<ToonRecord> records;

  /// The total number of data records in this document.
  int get length => records.length;

  /// Whether this document contains zero data records.
  bool get isEmpty => records.isEmpty;

  /// Whether this document contains at least one data record.
  bool get isNotEmpty => records.isNotEmpty;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ToonDocument &&
          runtimeType == other.runtimeType &&
          schema == other.schema &&
          _listEquals(records, other.records);

  @override
  int get hashCode => Object.hash(runtimeType, schema, Object.hashAll(records));

  @override
  String toString() =>
      'ToonDocument(schema: ${schema.arrayName}, records: ${records.length})';

  static bool _listEquals(final List<ToonRecord> a, final List<ToonRecord> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

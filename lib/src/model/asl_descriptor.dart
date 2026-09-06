import 'package:pscore/pscore.dart';

/// A descriptor number paired with its optional Photoshop unit identifier.
final class AslNumber {
  /// Numeric payload.
  final double value;

  /// Four-character unit code, or `null` for an unqualified number.
  final String? unit;

  /// Creates an immutable numeric view.
  const AslNumber({
    required this.value,
    required this.unit,
  });
}

/// A Photoshop enumeration represented by its type and selected identifiers.
final class AslEnumeration {
  /// Enumeration type identifier.
  final String typeId;

  /// Selected enumeration identifier.
  final String value;

  /// Creates an immutable enumeration view.
  const AslEnumeration({
    required this.typeId,
    required this.value,
  });
}

/// Convenient, type-safe accessors for Photoshop Action Descriptor values.
extension AslDescriptorAccess on PsDescriptor {
  /// Returns the first value found under [keys], searching in argument order.
  PsDescriptorValue? aslFirstValue(Iterable<String> keys) {
    for (final String key in keys) {
      final PsDescriptorValue? candidate = value(key);
      if (candidate != null) {
        return candidate;
      }
    }
    return null;
  }

  /// Returns the string stored under [key], with terminal nulls removed.
  String? aslString(String key) {
    final PsDescriptorValue? candidate = value(key);
    if (candidate is! PsStringValue) {
      return null;
    }
    int end = candidate.value.length;
    while (end > 0 && candidate.value.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return candidate.value.substring(0, end);
  }

  /// Returns the Boolean stored under [key].
  bool? aslBoolean(String key) {
    final PsDescriptorValue? candidate = value(key);
    return candidate is PsBooleanValue ? candidate.value : null;
  }

  /// Returns the signed integer stored under [key].
  int? aslInteger(String key) => switch (value(key)) {
    PsIntegerValue(:final int value) => value,
    PsLargeIntegerValue(:final int value) => value,
    _ => null,
  };

  /// Returns a numeric value and its optional unit from [key].
  AslNumber? aslNumber(String key) => switch (value(key)) {
    PsIntegerValue(:final int value) => AslNumber(value: value.toDouble(), unit: null),
    PsLargeIntegerValue(:final int value) => AslNumber(value: value.toDouble(), unit: null),
    PsDoubleValue(:final double value) => AslNumber(value: value, unit: null),
    PsUnitFloatValue(:final String unit, :final double value) => AslNumber(value: value, unit: unit),
    _ => null,
  };

  /// Returns the enumeration stored under [key].
  AslEnumeration? aslEnumeration(String key) => switch (value(key)) {
    PsEnumeratedValue(:final String typeId, :final String value) => AslEnumeration(typeId: typeId, value: value),
    _ => null,
  };

  /// Returns the nested descriptor stored under [key].
  PsDescriptor? aslObject(String key) => switch (value(key)) {
    PsObjectValue(:final PsDescriptor value) => value,
    _ => null,
  };

  /// Returns the object-array descriptor stored under [key].
  PsObjectArrayValue? aslObjectArray(String key) => switch (value(key)) {
    final PsObjectArrayValue value => value,
    _ => null,
  };

  /// Returns the ordered descriptor list stored under [key].
  List<PsDescriptorValue>? aslList(String key) => switch (value(key)) {
    PsListValue(:final List<PsDescriptorValue> values) => values,
    _ => null,
  };
}

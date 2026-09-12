import 'package:pscore/pscore.dart';

/// Backward-compatible name for a shared descriptor number projection.
typedef AslNumber = PsDescriptorNumber;

/// Backward-compatible name for a shared descriptor enumeration projection.
typedef AslEnumeration = PsDescriptorEnumeration;

/// Preserves the ASL-prefixed descriptor access API while using PsCore.
extension AslDescriptorAccess on PsDescriptor {
  /// Returns the first value found under [keys], searching in argument order.
  PsDescriptorValue? aslFirstValue(Iterable<String> keys) => firstValue(keys);

  /// Returns the string stored under [key], with terminal nulls removed.
  String? aslString(String key) => stringValue(key);

  /// Returns the Boolean stored under [key].
  bool? aslBoolean(String key) => booleanValue(key);

  /// Returns the signed integer stored under [key].
  int? aslInteger(String key) => integerValue(key);

  /// Returns a numeric value and its optional unit from [key].
  AslNumber? aslNumber(String key) => numberValue(key);

  /// Returns the enumeration stored under [key].
  AslEnumeration? aslEnumeration(String key) => enumerationValue(key);

  /// Returns the nested descriptor stored under [key].
  PsDescriptor? aslObject(String key) => objectValue(key);

  /// Returns the object-array descriptor stored under [key].
  PsObjectArrayValue? aslObjectArray(String key) => objectArrayValue(key);

  /// Returns the ordered descriptor list stored under [key].
  List<PsDescriptorValue>? aslList(String key) => listValue(key);
}

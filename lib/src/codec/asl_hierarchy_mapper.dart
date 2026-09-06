import 'package:aslkit/src/model/asl_hierarchy.dart';
import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Receives a recoverable hierarchy compatibility issue.
typedef AslHierarchyIssueHandler = void Function(String message);

/// Converts a generic Photoshop hierarchy descriptor into typed ASL entries.
abstract final class AslHierarchyMapper {
  /// Decodes the ordered list stored under the root `hierarchy` key.
  static List<AslHierarchyEntry> decode({
    required PsDescriptor root,
    required List<AslStyle> styles,
    required int maxEntries,
    required AslHierarchyIssueHandler onIssue,
  }) {
    final PsDescriptorValue? hierarchyValue = root.value('hierarchy');
    if (hierarchyValue == null) {
      onIssue('The phry descriptor has no hierarchy item');
      return const <AslHierarchyEntry>[];
    }
    if (hierarchyValue is! PsListValue) {
      onIssue('The phry hierarchy item is ${hierarchyValue.type}, not a list');
      return const <AslHierarchyEntry>[];
    }
    if (hierarchyValue.values.length > maxEntries) {
      throw PsFormatException(message: 'ASL hierarchy entry count ${hierarchyValue.values.length} exceeds the configured $maxEntries limit');
    }

    final List<AslHierarchyEntry> entries = <AslHierarchyEntry>[];
    int depth = 0;
    int nextStyleIndex = 0;
    for (int index = 0; index < hierarchyValue.values.length; index++) {
      final PsDescriptorValue value = hierarchyValue.values[index];
      final PsDescriptor? descriptor = switch (value) {
        PsObjectValue(:final PsDescriptor value) => value,
        _ => null,
      };
      if (descriptor == null) {
        entries.add(
          AslHierarchyEntry(
            index: index,
            kind: AslHierarchyEntryKind.empty,
            depth: depth,
            classId: null,
            name: null,
            id: null,
            styleIndex: null,
            rawDescriptor: null,
          ),
        );
        if (value is! PsRawValue || value.value.isNotEmpty) {
          onIssue('Hierarchy entry ${index + 1} uses unsupported value type ${value.type}');
        }
        continue;
      }

      final String classId = descriptor.classId;
      final String? name = _firstString(descriptor, const <String>['Nm  ', 'name']);
      final String? id = _firstString(descriptor, const <String>['zuid', 'Idnt', 'identifier']);
      switch (classId) {
        case 'Grup':
        case 'group':
        case 'groupStart':
          entries.add(
            AslHierarchyEntry(
              index: index,
              kind: AslHierarchyEntryKind.groupStart,
              depth: depth,
              classId: classId,
              name: name,
              id: id,
              styleIndex: null,
              rawDescriptor: descriptor,
            ),
          );
          depth++;
        case 'groupEnd':
          if (depth == 0) {
            onIssue('Hierarchy entry ${index + 1} closes a group that was not open');
          } else {
            depth--;
          }
          entries.add(
            AslHierarchyEntry(
              index: index,
              kind: AslHierarchyEntryKind.groupEnd,
              depth: depth,
              classId: classId,
              name: name,
              id: id,
              styleIndex: null,
              rawDescriptor: descriptor,
            ),
          );
        case 'preset':
          final int? styleIndex = _styleIndex(
            styles: styles,
            id: id,
            fallback: nextStyleIndex,
          );
          if (styleIndex == null) {
            onIssue('Hierarchy preset ${index + 1} cannot be mapped to a style record');
          } else if (styleIndex >= nextStyleIndex) {
            nextStyleIndex = styleIndex + 1;
          }
          entries.add(
            AslHierarchyEntry(
              index: index,
              kind: AslHierarchyEntryKind.preset,
              depth: depth,
              classId: classId,
              name: name ?? (styleIndex == null ? null : styles[styleIndex].name),
              id: id ?? (styleIndex == null ? null : styles[styleIndex].id),
              styleIndex: styleIndex,
              rawDescriptor: descriptor,
            ),
          );
        case 'null':
        case '':
          entries.add(
            AslHierarchyEntry(
              index: index,
              kind: AslHierarchyEntryKind.empty,
              depth: depth,
              classId: classId,
              name: name,
              id: id,
              styleIndex: null,
              rawDescriptor: descriptor,
            ),
          );
        default:
          onIssue('Hierarchy entry ${index + 1} uses unknown class "$classId"');
          entries.add(
            AslHierarchyEntry(
              index: index,
              kind: AslHierarchyEntryKind.unknown,
              depth: depth,
              classId: classId,
              name: name,
              id: id,
              styleIndex: null,
              rawDescriptor: descriptor,
            ),
          );
      }
    }
    if (depth != 0) {
      onIssue('ASL hierarchy ends with $depth unclosed group${depth == 1 ? '' : 's'}');
    }
    return entries;
  }

  /// Returns the first nonempty string stored under one of [keys].
  static String? _firstString(PsDescriptor descriptor, List<String> keys) {
    for (final String key in keys) {
      final PsDescriptorValue? value = descriptor.value(key);
      if (value case PsStringValue(:final String value) when value.isNotEmpty) {
        final String trimmed = _trimTerminalNulls(value);
        return trimmed.isEmpty ? null : trimmed;
      }
    }
    return null;
  }

  /// Removes only terminal null characters from [value].
  static String _trimTerminalNulls(String value) {
    int end = value.length;
    while (end > 0 && value.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return value.substring(0, end);
  }

  /// Resolves a style by [id] before applying its sequential [fallback].
  static int? _styleIndex({
    required List<AslStyle> styles,
    required String? id,
    required int fallback,
  }) {
    if (id != null && id.isNotEmpty) {
      final int matched = styles.lastIndexWhere((style) => style.id == id);
      if (matched >= 0) {
        return matched;
      }
    }
    return fallback < styles.length ? fallback : null;
  }
}

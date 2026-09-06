import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Identifies the role of one slot in Photoshop's optional style hierarchy.
enum AslHierarchyEntryKind {
  /// Opens a named style group.
  groupStart,

  /// Closes the most recently opened style group.
  groupEnd,

  /// Refers to a style preset.
  preset,

  /// Preserves an intentionally empty hierarchy slot.
  empty,

  /// Preserves an object class not understood by this release.
  unknown,
}

/// One ordered item from a trailing Photoshop `phry` hierarchy descriptor.
final class AslHierarchyEntry {
  /// Zero-based position in the source hierarchy list.
  final int index;

  /// Semantic role inferred from the descriptor class.
  final AslHierarchyEntryKind kind;

  /// Zero-based nesting depth at which this item appears.
  final int depth;

  /// Original Photoshop descriptor class, or `null` for an empty slot.
  final String? classId;

  /// User-visible group or preset name, when stored.
  final String? name;

  /// Photoshop identifier associated with the item, when stored.
  final String? id;

  /// Index of the referred style, when this is a mapped preset.
  final int? styleIndex;

  /// Complete source descriptor, or `null` for an empty slot.
  final PsDescriptor? rawDescriptor;

  /// Creates an immutable hierarchy item.
  const AslHierarchyEntry({
    required this.index,
    required this.kind,
    required this.depth,
    required this.classId,
    required this.name,
    required this.id,
    required this.styleIndex,
    required this.rawDescriptor,
  });

  /// Returns the referred style from [styles], when the mapping is valid.
  AslStyle? resolveStyle(List<AslStyle> styles) {
    final int? index = styleIndex;
    if (index == null || index < 0 || index >= styles.length) {
      return null;
    }
    return styles[index];
  }
}

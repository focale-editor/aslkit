import 'package:aslkit/src/model/asl_hierarchy.dart';
import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Receives a recoverable hierarchy compatibility issue.
typedef AslHierarchyIssueHandler = PsPresetHierarchyIssueHandler;

/// Adapts the shared Photoshop hierarchy mapper to ASL style entries.
abstract final class AslHierarchyMapper {
  /// Decodes the ordered list stored under the root `hierarchy` key.
  static List<AslHierarchyEntry> decode({
    required PsDescriptor root,
    required List<AslStyle> styles,
    required int maxEntries,
    required AslHierarchyIssueHandler onIssue,
  }) => List<AslHierarchyEntry>.unmodifiable(<AslHierarchyEntry>[
    for (final PsPresetHierarchyEntry entry in PsPresetHierarchyMapper.decode(
      root: root,
      presets: <PsPresetIdentity>[
        for (final AslStyle style in styles)
          PsPresetIdentity(
            name: style.name,
            id: style.id,
          ),
      ],
      maxEntries: maxEntries,
      onIssue: onIssue,
      formatLabel: 'ASL',
      presetLabel: 'a style record',
    ))
      AslHierarchyEntry(
        index: entry.index,
        kind: entry.kind,
        depth: entry.depth,
        classId: entry.classId,
        name: entry.name,
        id: entry.id,
        styleIndex: entry.presetIndex,
        rawDescriptor: entry.rawDescriptor,
      ),
  ]);
}

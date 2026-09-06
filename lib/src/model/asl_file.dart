import 'dart:typed_data';

import 'package:aslkit/src/model/asl_hierarchy.dart';
import 'package:aslkit/src/model/asl_options.dart';
import 'package:aslkit/src/model/asl_pattern.dart';
import 'package:aslkit/src/model/asl_resources.dart';
import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Identifies the envelope surrounding an `8BSL` style collection.
enum AslContainerKind {
  /// A standalone `.asl` file beginning with a 16-bit version.
  styleLibrary,

  /// A Photoshop `Styles.psp` payload beginning directly with `8BSL`.
  stylesPalette,
}

/// One tagged trailer block following the declared style records.
final class AslTaggedBlock {
  /// Four-byte Photoshop signature, normally `8BIM`.
  final String signature;

  /// Four-byte block key, such as `phry`.
  final String key;

  /// Absolute offset of the block signature.
  final int offset;

  /// Payload length exactly as declared in the block header.
  final int declaredLength;

  /// Unpadded payload, or an empty list when preservation was disabled.
  final Uint8List data;

  /// Number of payload bytes physically available in the decoded input.
  final int dataByteCount;

  /// Optional alignment bytes before a following block or end-of-file.
  final Uint8List paddingData;

  /// Creates an immutable tagged trailer block.
  AslTaggedBlock({
    required this.signature,
    required this.key,
    required this.offset,
    required this.declaredLength,
    required Uint8List data,
    int? dataByteCount,
    required Uint8List paddingData,
  }) : dataByteCount = dataByteCount ?? data.length,
       data = Uint8List.fromList(data).asUnmodifiableView(),
       paddingData = Uint8List.fromList(paddingData).asUnmodifiableView();
}

/// Complete decoded contents of one Photoshop layer-style library.
final class AslFile {
  /// Envelope used by the decoded input.
  final AslContainerKind containerKind;

  /// Standalone file version, or `null` for a styles-palette payload.
  final int? version;

  /// Four-byte style signature exactly as stored.
  final String signature;

  /// Embedded-pattern section version, normally 3.
  final int patternsVersion;

  /// Byte length declared for the complete embedded-pattern section.
  final int declaredPatternSectionLength;

  /// Every bounded embedded-pattern record, including malformed records.
  final List<AslPatternRecord> patternRecords;

  /// Bytes left after the last reliably bounded pattern record.
  final Uint8List patternSectionTrailingData;

  /// Number of undecodable pattern-section suffix bytes in the source.
  final int patternSectionTrailingByteCount;

  /// Style count declared after the pattern section.
  final int declaredStyleCount;

  /// Every bounded style record, including opaque malformed records.
  final List<AslStyle> styles;

  /// Flattened group and preset hierarchy from recognized `phry` blocks.
  final List<AslHierarchyEntry> hierarchy;

  /// Complete root descriptors from every recognized `phry` block.
  final List<PsDescriptor> hierarchyDescriptors;

  /// Every trailing tagged block, including unknown forward-compatible keys.
  final List<AslTaggedBlock> taggedBlocks;

  /// Bytes following the last recognizable style or tagged block.
  final Uint8List trailingData;

  /// Number of unrecognized trailing bytes in the source.
  final int trailingByteCount;

  /// Recoverable compatibility issues encountered while decoding.
  final List<AslWarning> warnings;

  /// Aggregate uncompressed channel bytes retained by embedded patterns.
  final int decodedPixelBytes;

  /// Complete source bytes when preservation was requested.
  final Uint8List? sourceData;

  /// Last style for every non-empty identifier.
  final Map<String, AslStyle> _stylesById;

  /// Last decoded pattern for every non-empty identifier.
  final Map<String, PsPattern> _patternsById;

  /// Creates an immutable decoded ASL library.
  AslFile({
    required this.containerKind,
    required this.version,
    required this.signature,
    required this.patternsVersion,
    required this.declaredPatternSectionLength,
    required List<AslPatternRecord> patternRecords,
    required Uint8List patternSectionTrailingData,
    required this.patternSectionTrailingByteCount,
    required this.declaredStyleCount,
    required List<AslStyle> styles,
    required List<AslHierarchyEntry> hierarchy,
    required List<PsDescriptor> hierarchyDescriptors,
    required List<AslTaggedBlock> taggedBlocks,
    required Uint8List trailingData,
    required this.trailingByteCount,
    required List<AslWarning> warnings,
    required this.decodedPixelBytes,
    required Uint8List? sourceData,
  }) : patternRecords = List<AslPatternRecord>.unmodifiable(patternRecords),
       patternSectionTrailingData = Uint8List.fromList(patternSectionTrailingData).asUnmodifiableView(),
       styles = List<AslStyle>.unmodifiable(styles),
       hierarchy = List<AslHierarchyEntry>.unmodifiable(hierarchy),
       hierarchyDescriptors = List<PsDescriptor>.unmodifiable(hierarchyDescriptors),
       taggedBlocks = List<AslTaggedBlock>.unmodifiable(taggedBlocks),
       trailingData = Uint8List.fromList(trailingData).asUnmodifiableView(),
       warnings = List<AslWarning>.unmodifiable(warnings),
       sourceData = sourceData == null ? null : Uint8List.fromList(sourceData).asUnmodifiableView(),
       _stylesById = Map<String, AslStyle>.unmodifiable(<String, AslStyle>{
         for (final AslStyle style in styles)
           if (style.id case final String id when id.isNotEmpty) id: style,
       }),
       _patternsById = Map<String, PsPattern>.unmodifiable(<String, PsPattern>{
         for (final AslPatternRecord record in patternRecords)
           if (record.pattern case final PsPattern pattern when pattern.id.isNotEmpty) pattern.id: pattern,
       });

  /// Creates a new standalone version-2 style library.
  factory AslFile.editable({
    required List<AslStyle> styles,
    List<AslPatternRecord> patternRecords = const <AslPatternRecord>[],
    List<AslTaggedBlock> taggedBlocks = const <AslTaggedBlock>[],
  }) => AslFile(
    containerKind: AslContainerKind.styleLibrary,
    version: 2,
    signature: '8BSL',
    patternsVersion: 3,
    declaredPatternSectionLength: 0,
    patternRecords: patternRecords,
    patternSectionTrailingData: Uint8List(0),
    patternSectionTrailingByteCount: 0,
    declaredStyleCount: styles.length,
    styles: styles,
    hierarchy: const <AslHierarchyEntry>[],
    hierarchyDescriptors: const <PsDescriptor>[],
    taggedBlocks: taggedBlocks,
    trailingData: Uint8List(0),
    trailingByteCount: 0,
    warnings: const <AslWarning>[],
    decodedPixelBytes: 0,
    sourceData: null,
  );

  /// Successfully decoded embedded patterns in source order.
  List<PsPattern> get patterns => List<PsPattern>.unmodifiable(<PsPattern>[
    for (final AslPatternRecord record in patternRecords)
      if (record.pattern case final PsPattern pattern) pattern,
  ]);

  /// Styles whose two Action Descriptors were decoded successfully.
  List<AslStyle> get decodedStyles => List<AslStyle>.unmodifiable(styles.where((style) => style.isDecoded));

  /// Whether every declared style has a bounded record in [styles].
  bool get hasCompleteStyleRecordSet => styles.length == declaredStyleCount;

  /// Whether every bounded pattern and declared style decoded successfully.
  bool get isFullyDecoded => hasCompleteStyleRecordSet && styles.every((style) => style.isDecoded) && patternRecords.every((record) => record.isDecoded) && patternSectionTrailingData.isEmpty;

  /// Returns the last style matching [id], or `null` when absent.
  AslStyle? styleById(String id) => _stylesById[id];

  /// Returns the last embedded pattern matching [id], or `null` when absent.
  PsPattern? patternById(String id) => _patternsById[id];

  /// Resolves a pattern [reference] against the embedded pattern section.
  PsPattern? patternFor(AslPatternReference reference) {
    final String? id = reference.id;
    return id == null ? null : patternById(id);
  }

  /// Resolves the style referred to by [entry], when available.
  AslStyle? styleFor(AslHierarchyEntry entry) => entry.resolveStyle(styles);
}

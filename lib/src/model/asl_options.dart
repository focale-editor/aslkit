import 'package:pscore/pscore.dart';

/// Controls whether recoverable ASL compatibility issues stop decoding.
enum AslDecodeMode {
  /// Rejects unknown extensions and malformed optional data.
  strict,

  /// Preserves unknown data and reports recoverable defects as warnings.
  tolerant,
}

/// Controls how strongly an ASL document is validated before encoding.
enum AslEncodeMode {
  /// Produces only structurally valid Photoshop style libraries.
  strict,

  /// Writes all bounded model values, including preserved compatibility data.
  permissive,
}

/// Resource and preservation limits applied while decoding an ASL library.
final class AslDecodeOptions {
  /// Handling policy for recoverable format extensions and damaged records.
  final AslDecodeMode mode;

  /// Maximum accepted input size.
  final int maxFileBytes;

  /// Maximum accepted byte length for the embedded-pattern section.
  final int maxPatternSectionBytes;

  /// Maximum number of embedded pattern records.
  final int maxPatterns;

  /// Maximum width or height accepted for decoded pattern planes.
  final int maxPatternDimension;

  /// Maximum number of ordinary virtual-memory pattern channels.
  final int maxPatternChannelCount;

  /// Maximum byte length accepted for one pattern virtual-memory payload.
  final int maxPatternBytes;

  /// Maximum UTF-16 code-unit count accepted for one pattern name.
  final int maxPatternNameCodeUnits;

  /// Maximum aggregate number of retained uncompressed pattern bytes.
  final int maxDecodedPixelBytes;

  /// Maximum number of style records declared by one library.
  final int maxStyles;

  /// Maximum accepted byte length for one style record.
  final int maxStyleBytes;

  /// Maximum payload length accepted for one trailing tagged block.
  final int maxTaggedBlockBytes;

  /// Maximum number of trailing Photoshop tagged blocks.
  final int maxTaggedBlocks;

  /// Maximum number of hierarchy entries exposed from `phry` descriptors.
  final int maxHierarchyEntries;

  /// Resource limits applied to every Photoshop Action Descriptor.
  final PsDescriptorDecodeOptions descriptorOptions;

  /// Whether recognized pattern channel data is decompressed.
  final bool decodePatternChannelData;

  /// Whether pattern channel slots retain their encoded payload bytes.
  final bool preservePatternChannelData;

  /// Whether every embedded pattern retains its exact record payload.
  final bool preservePatternRecordData;

  /// Whether every style retains its exact record payload.
  final bool preserveStyleRecordData;

  /// Whether tagged trailer blocks retain their complete payload bytes.
  final bool preserveTaggedBlockData;

  /// Whether bytes outside recognized records are retained.
  final bool preserveTrailingData;

  /// Whether the decoded document retains a complete source copy.
  final bool preserveSourceData;

  /// Creates bounded decode options suitable for untrusted input.
  const AslDecodeOptions({
    this.mode = AslDecodeMode.tolerant,
    this.maxFileBytes = 1024 * 1024 * 1024,
    this.maxPatternSectionBytes = 512 * 1024 * 1024,
    this.maxPatterns = 100000,
    this.maxPatternDimension = 100000,
    this.maxPatternChannelCount = 1024,
    this.maxPatternBytes = 512 * 1024 * 1024,
    this.maxPatternNameCodeUnits = 1024 * 1024,
    this.maxDecodedPixelBytes = 512 * 1024 * 1024,
    this.maxStyles = 100000,
    this.maxStyleBytes = 64 * 1024 * 1024,
    this.maxTaggedBlockBytes = 64 * 1024 * 1024,
    this.maxTaggedBlocks = 100000,
    this.maxHierarchyEntries = 100000,
    this.descriptorOptions = const PsDescriptorDecodeOptions(),
    this.decodePatternChannelData = true,
    this.preservePatternChannelData = true,
    this.preservePatternRecordData = true,
    this.preserveStyleRecordData = true,
    this.preserveTaggedBlockData = true,
    this.preserveTrailingData = true,
    this.preserveSourceData = true,
  });
}

/// Preservation and validation choices applied while encoding an ASL file.
final class AslEncodeOptions {
  /// Validation policy applied before values are written.
  final AslEncodeMode mode;

  /// Whether trailing Photoshop tagged blocks are appended.
  final bool includeTaggedBlocks;

  /// Whether an undecodable suffix inside the pattern section is appended.
  final bool includePatternSectionTrailingData;

  /// Whether uninterpreted trailing bytes are appended.
  final bool includeTrailingData;

  /// Creates encoding options for a standards-compliant output by default.
  const AslEncodeOptions({
    this.mode = AslEncodeMode.strict,
    this.includeTaggedBlocks = true,
    this.includePatternSectionTrailingData = true,
    this.includeTrailingData = true,
  });
}

/// Describes a recoverable compatibility issue found while decoding.
final class AslWarning {
  /// Human-readable explanation of the compatibility issue.
  final String message;

  /// Absolute byte offset associated with the issue, when known.
  final int? offset;

  /// Zero-based pattern position associated with the issue, when known.
  final int? patternIndex;

  /// Zero-based style position associated with the issue, when known.
  final int? styleIndex;

  /// Tagged-block key associated with the issue, when known.
  final String? blockKey;

  /// Creates a warning with optional source context.
  const AslWarning({
    required this.message,
    this.offset,
    this.patternIndex,
    this.styleIndex,
    this.blockKey,
  });

  @override
  String toString() {
    final String location = offset == null ? '' : ' at byte $offset';
    final int? currentPatternIndex = patternIndex;
    final int? currentStyleIndex = styleIndex;
    final String pattern = currentPatternIndex == null ? '' : ' in pattern ${currentPatternIndex + 1}';
    final String style = currentStyleIndex == null ? '' : ' in style ${currentStyleIndex + 1}';
    final String block = blockKey == null ? '' : ' in $blockKey';
    return 'AslWarning$location$pattern$style$block: $message';
  }
}

/// Reports malformed, truncated, unsupported, or unsafe ASL input.
final class AslFormatException implements FormatException {
  /// Human-readable explanation of the malformed data.
  @override
  final String message;

  /// Input associated with the failure, when useful.
  @override
  final Object? source;

  /// Absolute byte offset associated with the failure, when known.
  @override
  final int? offset;

  /// Creates an ASL format error at an optional absolute byte [offset].
  const AslFormatException({
    required this.message,
    this.source,
    this.offset,
  });

  @override
  String toString() {
    final String location = offset == null ? '' : ' at byte $offset';
    return 'AslFormatException$location: $message';
  }
}

/// Reports model data that cannot be represented by the requested ASL output.
final class AslWriteException implements Exception {
  /// Explains why encoding failed.
  final String message;

  /// Creates an encoding error with a user-facing [message].
  const AslWriteException({
    required this.message,
  });

  @override
  String toString() => 'AslWriteException: $message';
}

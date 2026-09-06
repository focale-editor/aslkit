import 'dart:typed_data';

import 'package:pscore/pscore.dart';

/// One length-prefixed pattern record embedded before ASL styles.
final class AslPatternRecord {
  /// Zero-based position in the embedded-pattern section.
  final int index;

  /// Absolute offset of the record-length field.
  final int sourceOffset;

  /// Payload length declared by the record header.
  final int declaredLength;

  /// Parsed pattern data, or `null` when this record is malformed or skipped.
  final PsPattern? pattern;

  /// Exact unpadded record payload, or an empty list when not preserved.
  final Uint8List data;

  /// Number of payload bytes physically available in the decoded input.
  final int dataByteCount;

  /// Bytes used to align the next pattern record to four bytes.
  final Uint8List paddingData;

  /// Explanation retained for a record that could not be decoded.
  final String? decodeError;

  /// Creates an immutable embedded-pattern record.
  AslPatternRecord({
    required this.index,
    required this.sourceOffset,
    required this.declaredLength,
    required this.pattern,
    required Uint8List data,
    int? dataByteCount,
    required Uint8List paddingData,
    required this.decodeError,
  }) : dataByteCount = dataByteCount ?? data.length,
       data = Uint8List.fromList(data).asUnmodifiableView(),
       paddingData = Uint8List.fromList(paddingData).asUnmodifiableView();

  /// Whether [pattern] was decoded successfully.
  bool get isDecoded => pattern != null;
}

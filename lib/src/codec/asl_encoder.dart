import 'dart:typed_data';

import 'package:aslkit/src/model/asl_file.dart';
import 'package:aslkit/src/model/asl_options.dart';
import 'package:aslkit/src/model/asl_pattern.dart';
import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Encodes immutable ASL models into Photoshop style-library bytes.
abstract final class AslEncoder {
  /// Four-byte signature used by every Photoshop style collection.
  static const String _fileSignature = '8BSL';

  /// Standalone ASL version currently written by Photoshop.
  static const int _fileVersion = 2;

  /// Embedded-pattern section version currently written by Photoshop.
  static const int _patternsVersion = 3;

  /// Action Descriptor version currently written by Photoshop.
  static const int _descriptorVersion = 16;

  /// Encodes [file] into a new big-endian ASL byte buffer.
  static Uint8List encode(
    AslFile file, {
    AslEncodeOptions options = const AslEncodeOptions(),
  }) {
    try {
      _validateRepresentable(file, options);
      if (options.mode == AslEncodeMode.strict) {
        _validateStrict(file, options);
      }
      final PsBinaryWriter patterns = PsBinaryWriter();
      for (final AslPatternRecord record in file.patternRecords) {
        _writePattern(patterns, record, options);
      }
      if (options.includePatternSectionTrailingData) {
        patterns.writeBytes(file.patternSectionTrailingData);
      }
      final Uint8List patternBytes = patterns.takeBytes();

      final PsBinaryWriter writer = PsBinaryWriter();
      if (file.containerKind == AslContainerKind.styleLibrary) {
        writer.writeUint16(file.version ?? _fileVersion);
      }
      writer
        ..writeString(file.signature)
        ..writeUint16(file.patternsVersion)
        ..writeUint32(patternBytes.length)
        ..writeBytes(patternBytes)
        ..writeUint32(options.mode == AslEncodeMode.permissive ? file.declaredStyleCount : file.styles.length);
      for (final AslStyle style in file.styles) {
        _writeStyle(writer, style, options);
      }
      if (options.includeTaggedBlocks) {
        for (final AslTaggedBlock block in file.taggedBlocks) {
          _writeTaggedBlock(writer, block, options);
        }
      }
      if (options.includeTrailingData) {
        writer.writeBytes(file.trailingData);
      }
      return writer.takeBytes();
    } on AslWriteException {
      rethrow;
    } on PsWriteException catch (error) {
      throw AslWriteException(message: error.message);
    } on RangeError catch (error) {
      throw AslWriteException(message: 'An ASL numeric value cannot be encoded: $error');
    }
  }

  /// Writes one embedded pattern and its four-byte alignment.
  static void _writePattern(
    PsBinaryWriter writer,
    AslPatternRecord record,
    AslEncodeOptions options,
  ) {
    final Uint8List? decodedData = record.pattern?.recordData;
    final Uint8List data = record.data.isNotEmpty ? record.data : decodedData ?? Uint8List(0);
    final int declaredLength = options.mode == AslEncodeMode.permissive ? record.declaredLength : data.length;
    writer
      ..writeUint32(declaredLength)
      ..writeBytes(data);
    final int expectedPaddingLength = (4 - data.length % 4) % 4;
    if (options.mode == AslEncodeMode.permissive && record.paddingData.isNotEmpty) {
      writer.writeBytes(record.paddingData);
    } else {
      writer.writeZeros(expectedPaddingLength);
    }
  }

  /// Writes one decoded descriptor pair or one preserved opaque style.
  static void _writeStyle(
    PsBinaryWriter writer,
    AslStyle style,
    AslEncodeOptions options,
  ) {
    final PsDescriptor? identification = style.identificationDescriptor;
    final PsDescriptor? information = style.styleDescriptor;
    if (identification == null || information == null) {
      final Uint8List? data = style.recordData;
      if (data == null) {
        throw AslWriteException(message: 'Opaque style ${style.index + 1} has no preserved record data');
      }
      writer
        ..writeUint32(options.mode == AslEncodeMode.permissive ? style.declaredLength : data.length)
        ..writeBytes(data)
        ..writeBytes(style.paddingData);
      return;
    }

    final PsBinaryWriter record = PsBinaryWriter()
      ..writeUint32(style.identificationDescriptorVersion ?? _descriptorVersion)
      ..writeBytes(PsDescriptorCodec.encode(identification))
      ..writeUint32(style.styleDescriptorVersion ?? _descriptorVersion)
      ..writeBytes(PsDescriptorCodec.encode(information))
      ..writeBytes(style.recordTrailingData);
    if (options.mode == AslEncodeMode.strict) {
      record.writeZeros((4 - record.length % 4) % 4);
    }
    final Uint8List data = record.takeBytes();
    writer
      ..writeUint32(data.length)
      ..writeBytes(data);
    if (options.mode == AslEncodeMode.permissive && style.paddingData.isNotEmpty) {
      writer.writeBytes(style.paddingData);
    } else if (options.mode == AslEncodeMode.permissive) {
      writer.writeZeros((4 - data.length % 4) % 4);
    }
  }

  /// Writes one preserved ordinary or wide Photoshop tagged block.
  static void _writeTaggedBlock(
    PsBinaryWriter writer,
    AslTaggedBlock block,
    AslEncodeOptions options,
  ) {
    final bool wide = block.signature == '8B64';
    final int length = options.mode == AslEncodeMode.permissive ? block.declaredLength : block.data.length;
    writer
      ..writeString(block.signature)
      ..writeString(block.key)
      ..writeLength(length, wide: wide)
      ..writeBytes(block.data)
      ..writeBytes(block.paddingData);
  }

  /// Checks that every emitted field and required payload is representable.
  static void _validateRepresentable(AslFile file, AslEncodeOptions options) {
    if (file.containerKind == AslContainerKind.styleLibrary) {
      _requireUnsigned(file.version ?? _fileVersion, 16, 'ASL version');
    }
    _requireLatin1(file.signature, 4, 'ASL signature');
    _requireUnsigned(file.patternsVersion, 16, 'ASL pattern-section version');
    if (options.includePatternSectionTrailingData && file.patternSectionTrailingData.length != file.patternSectionTrailingByteCount) {
      throw AslWriteException(
        message: 'Only ${file.patternSectionTrailingData.length} of ${file.patternSectionTrailingByteCount} pattern-section trailing bytes were preserved',
      );
    }
    if (file.patternRecords.length > 0xffffffff || file.styles.length > 0xffffffff) {
      throw const AslWriteException(message: 'ASL record count exceeds the 32-bit container capacity');
    }
    _requireUnsigned(file.declaredStyleCount, 32, 'ASL declared style count');
    for (final AslPatternRecord record in file.patternRecords) {
      final Uint8List? decodedData = record.pattern?.recordData;
      final int availableLength = record.data.isNotEmpty ? record.data.length : decodedData?.length ?? 0;
      if (availableLength != record.dataByteCount) {
        throw AslWriteException(message: 'Pattern ${record.index + 1} has no preserved record payload');
      }
      _requireUnsigned(availableLength, 32, 'Pattern ${record.index + 1} payload length');
      _requireUnsigned(record.declaredLength, 32, 'Pattern ${record.index + 1} declared length');
    }
    for (final AslStyle style in file.styles) {
      _requireUnsigned(style.declaredLength, 32, 'Style ${style.index + 1} declared length');
      _requireUnsigned(style.identificationDescriptorVersion ?? _descriptorVersion, 32, 'Style ${style.index + 1} identification descriptor version');
      _requireUnsigned(style.styleDescriptorVersion ?? _descriptorVersion, 32, 'Style ${style.index + 1} information descriptor version');
    }
    if (options.includeTaggedBlocks) {
      for (final AslTaggedBlock block in file.taggedBlocks) {
        _requireLatin1(block.signature, 4, 'Tagged-block signature');
        _requireLatin1(block.key, 4, 'Tagged-block key');
        _requireUnsigned(block.declaredLength, block.signature == '8B64' ? 64 : 32, 'Tagged-block ${block.key} declared length');
        _requireUnsigned(block.data.length, block.signature == '8B64' ? 64 : 32, 'Tagged-block ${block.key} payload length');
        if (block.data.length != block.dataByteCount) {
          throw AslWriteException(message: 'Tagged block ${block.key} has no complete preserved payload');
        }
      }
    }
    if (options.includeTrailingData && file.trailingData.length != file.trailingByteCount) {
      throw AslWriteException(
        message: 'Only ${file.trailingData.length} of ${file.trailingByteCount} trailing bytes were preserved; disable trailing-data output or decode with preservation enabled',
      );
    }
  }

  /// Applies the canonical constraints used by Photoshop ASL files.
  static void _validateStrict(AslFile file, AslEncodeOptions options) {
    if (file.signature != _fileSignature) {
      throw const AslWriteException(message: 'Strict ASL output requires the "$_fileSignature" signature');
    }
    if (file.containerKind == AslContainerKind.styleLibrary && file.version != _fileVersion) {
      throw const AslWriteException(message: 'Strict standalone ASL output requires version $_fileVersion');
    }
    if (file.patternsVersion != _patternsVersion) {
      throw const AslWriteException(message: 'Strict ASL output requires pattern-section version $_patternsVersion');
    }
    if (options.includePatternSectionTrailingData && file.patternSectionTrailingData.isNotEmpty) {
      throw const AslWriteException(message: 'Strict ASL output cannot contain an undecodable pattern-section suffix');
    }
    if (file.declaredStyleCount != file.styles.length) {
      throw const AslWriteException(message: 'Strict ASL output requires the declared style count to match the style list');
    }
    for (final AslPatternRecord record in file.patternRecords) {
      if (!record.isDecoded) {
        throw AslWriteException(message: 'Strict ASL output cannot contain opaque pattern ${record.index + 1}');
      }
      final Uint8List? decodedData = record.pattern?.recordData;
      final int length = record.data.isNotEmpty ? record.data.length : decodedData?.length ?? 0;
      if (length == 0) {
        throw AslWriteException(message: 'Pattern ${record.index + 1} has an empty payload');
      }
    }
    file.styles.forEach(_validateStrictStyle);
    if (options.includeTaggedBlocks) {
      for (final AslTaggedBlock block in file.taggedBlocks) {
        if (block.signature != '8BIM' && block.signature != '8B64') {
          throw AslWriteException(message: 'Tagged block ${block.key} uses unsupported signature "${block.signature}"');
        }
        if (block.declaredLength != block.data.length) {
          throw AslWriteException(message: 'Tagged block ${block.key} declared length does not match its preserved payload');
        }
        if (block.paddingData.length > 3 || _containsNonzero(block.paddingData)) {
          throw AslWriteException(message: 'Tagged block ${block.key} has invalid alignment data');
        }
      }
    }
    if (options.includeTrailingData && file.trailingData.isNotEmpty) {
      throw const AslWriteException(message: 'Strict ASL output cannot contain unrecognized trailing bytes');
    }
  }

  /// Validates one canonical pair of version-16 style descriptors.
  static void _validateStrictStyle(AslStyle style) {
    final PsDescriptor? identification = style.identificationDescriptor;
    final PsDescriptor? information = style.styleDescriptor;
    if (identification == null || information == null) {
      throw AslWriteException(message: 'Strict ASL output cannot contain opaque style ${style.index + 1}');
    }
    if ((style.identificationDescriptorVersion ?? _descriptorVersion) != _descriptorVersion || (style.styleDescriptorVersion ?? _descriptorVersion) != _descriptorVersion) {
      throw AslWriteException(message: 'Style ${style.index + 1} must use version-$_descriptorVersion descriptors');
    }
    if (identification.classId != 'null' || information.classId != 'Styl') {
      throw AslWriteException(message: 'Style ${style.index + 1} uses noncanonical descriptor classes');
    }
    final PsDescriptorValue? name = identification.value('Nm  ');
    final PsDescriptorValue? id = identification.value('Idnt');
    if (name is! PsStringValue || name.value.isEmpty || id is! PsStringValue || id.value.isEmpty) {
      throw AslWriteException(message: 'Style ${style.index + 1} requires nonempty `Nm  ` and `Idnt` strings');
    }
    if (information.value('documentMode') is! PsObjectValue) {
      throw AslWriteException(message: 'Style ${style.index + 1} requires an object-shaped `documentMode` item');
    }
    if (information.value('Lefx') is! PsObjectValue && information.value('blendOptions') is! PsObjectValue) {
      throw AslWriteException(message: 'Style ${style.index + 1} requires layer effects or blending options');
    }
    if (style.recordTrailingData.length > 3 || _containsNonzero(style.recordTrailingData)) {
      throw AslWriteException(message: 'Style ${style.index + 1} has invalid descriptor extension bytes');
    }
    if (style.paddingData.length > 3 || _containsNonzero(style.paddingData)) {
      throw AslWriteException(message: 'Style ${style.index + 1} has invalid outer alignment bytes');
    }
  }

  /// Tests whether [bytes] contains at least one nonzero value.
  static bool _containsNonzero(Uint8List bytes) {
    for (final int value in bytes) {
      if (value != 0) {
        return true;
      }
    }
    return false;
  }

  /// Requires [value] to contain exactly [length] one-byte characters.
  static void _requireLatin1(String value, int length, String label) {
    if (value.length != length || value.codeUnits.any((unit) => unit > 0xff)) {
      throw AslWriteException(message: '$label must contain exactly $length Latin-1 characters');
    }
  }

  /// Requires [value] to fit an unsigned integer of [bits] bits.
  static void _requireUnsigned(int value, int bits, String label) {
    final int maximum = bits == 64 ? 0x7fffffffffffffff : (1 << bits) - 1;
    if (value < 0 || value > maximum) {
      throw AslWriteException(message: '$label value $value does not fit an unsigned $bits-bit field');
    }
  }
}

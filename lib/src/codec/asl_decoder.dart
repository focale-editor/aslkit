import 'dart:convert';
import 'dart:typed_data';

import 'package:aslkit/src/codec/asl_hierarchy_mapper.dart';
import 'package:aslkit/src/model/asl_descriptor.dart';
import 'package:aslkit/src/model/asl_effect.dart';
import 'package:aslkit/src/model/asl_file.dart';
import 'package:aslkit/src/model/asl_hierarchy.dart';
import 'package:aslkit/src/model/asl_options.dart';
import 'package:aslkit/src/model/asl_pattern.dart';
import 'package:aslkit/src/model/asl_resources.dart';
import 'package:aslkit/src/model/asl_style.dart';
import 'package:pscore/pscore.dart';

/// Decodes standalone ASL libraries and Photoshop styles-palette payloads.
///
/// The configured instance is a one-shot [Converter] for complete in-memory
/// files. Use [decode] when conversion options are supplied per call.
final class AslDecoder extends Converter<List<int>, AslFile> {
  /// Options applied by [convert].
  final AslDecodeOptions options;

  /// Creates a reusable decoder with fixed [options].
  const AslDecoder({
    this.options = const AslDecodeOptions(),
  });

  @override
  AslFile convert(List<int> input) => decode(
    input is Uint8List ? input : Uint8List.fromList(input),
    options: options,
  );

  /// Four-byte signature used by every Photoshop style collection.
  static const String _fileSignature = '8BSL';

  /// Four-byte signature used by ordinary Photoshop tagged blocks.
  static const String _taggedBlockSignature = '8BIM';

  /// Alternate signature whose tagged-block length occupies eight bytes.
  static const String _largeTaggedBlockSignature = '8B64';

  /// Standalone ASL version currently written by Photoshop.
  static const int _fileVersion = 2;

  /// Embedded-pattern section version currently written by Photoshop.
  static const int _patternsVersion = 3;

  /// Version stored before a Photoshop Action Descriptor.
  static const int _descriptorVersion = 16;

  /// Decodes one complete in-memory ASL [bytes] buffer.
  static AslFile decode(
    Uint8List bytes, {
    AslDecodeOptions options = const AslDecodeOptions(),
  }) {
    _validateOptions(options);
    if (bytes.length > options.maxFileBytes) {
      throw AslFormatException(
        message: 'ASL file size ${bytes.length} exceeds the configured ${options.maxFileBytes} byte limit',
        source: bytes,
        offset: 0,
      );
    }
    try {
      return _decode(bytes, options);
    } on AslFormatException {
      rethrow;
    } on PsFormatException catch (error) {
      throw AslFormatException(
        message: error.message,
        source: bytes,
        offset: error.offset,
      );
    } on RangeError catch (error) {
      throw AslFormatException(
        message: 'Invalid ASL numeric range: $error',
        source: bytes,
      );
    }
  }

  /// Decodes the envelope, patterns, styles, and optional trailer blocks.
  static AslFile _decode(Uint8List bytes, AslDecodeOptions options) {
    final PsBinaryReader reader = PsBinaryReader(bytes: bytes);
    final AslContainerKind containerKind;
    final int? version;
    if (_hasString(bytes, 0, _fileSignature)) {
      containerKind = AslContainerKind.stylesPalette;
      version = null;
    } else {
      containerKind = AslContainerKind.styleLibrary;
      version = reader.readUint16();
    }
    final int signatureOffset = reader.offset;
    final String signature = reader.readString(4);
    if (signature != _fileSignature) {
      throw AslFormatException(
        message: 'Expected ASL signature "$_fileSignature", found "$signature"',
        source: bytes,
        offset: signatureOffset,
      );
    }
    final int patternsVersionOffset = reader.offset;
    final int patternsVersion = reader.readUint16();
    final int patternsLengthOffset = reader.offset;
    final int declaredPatternSectionLength = reader.readUint32();
    if (declaredPatternSectionLength > options.maxPatternSectionBytes) {
      throw AslFormatException(
        message: 'ASL pattern section length $declaredPatternSectionLength exceeds the configured ${options.maxPatternSectionBytes} byte limit',
        source: bytes,
        offset: patternsLengthOffset,
      );
    }
    if (declaredPatternSectionLength > reader.remaining) {
      throw AslFormatException(
        message: 'ASL pattern section length $declaredPatternSectionLength exceeds the ${reader.remaining} remaining bytes',
        source: bytes,
        offset: patternsLengthOffset,
      );
    }

    final _AslDecodeContext context = _AslDecodeContext(
      source: bytes,
      options: options,
      containerKind: containerKind,
      version: version,
      signature: signature,
      patternsVersion: patternsVersion,
      declaredPatternSectionLength: declaredPatternSectionLength,
    );
    if (version != null && version != _fileVersion) {
      context.issue('ASL container version $version is not currently defined', 0);
    }
    if (patternsVersion != _patternsVersion) {
      context.issue('ASL pattern section version $patternsVersion is not currently defined', patternsVersionOffset);
    }

    final PsBinaryReader patterns = reader.readReader(declaredPatternSectionLength);
    _decodePatterns(patterns, context);
    final int styleCountOffset = reader.offset;
    context.declaredStyleCount = reader.readUint32();
    if (context.declaredStyleCount > options.maxStyles) {
      throw AslFormatException(
        message: 'ASL style count ${context.declaredStyleCount} exceeds the configured ${options.maxStyles} limit',
        source: bytes,
        offset: styleCountOffset,
      );
    }
    final bool complete = _decodeStyles(reader, context);
    if (complete) {
      _decodeTaggedBlocks(reader, context);
    }
    return context.build();
  }

  /// Decodes every length-prefixed record in the bounded pattern section.
  static void _decodePatterns(PsBinaryReader reader, _AslDecodeContext context) {
    int index = 0;
    while (!reader.isAtEnd) {
      context.patternIndex = index;
      final int recordStart = reader.offset;
      final int recordOffset = reader.baseOffset + recordStart;
      if (index >= context.options.maxPatterns) {
        throw AslFormatException(
          message: 'ASL pattern count exceeds the configured ${context.options.maxPatterns} limit',
          source: context.source,
          offset: recordOffset,
        );
      }
      if (reader.remaining < 4) {
        context.setPatternTrailing(Uint8List.sublistView(reader.bytes, recordStart));
        context.issue('Truncated embedded-pattern length field', recordOffset);
        break;
      }
      final int declaredLength = reader.readUint32();
      if (declaredLength == 0 || declaredLength > reader.remaining) {
        context.setPatternTrailing(Uint8List.sublistView(reader.bytes, recordStart));
        context.issue('Embedded pattern length $declaredLength exceeds the pattern-section bounds', recordOffset);
        break;
      }
      if (declaredLength > context.options.maxPatternBytes) {
        throw AslFormatException(
          message: 'ASL pattern record length $declaredLength exceeds the configured ${context.options.maxPatternBytes} byte limit',
          source: context.source,
          offset: recordOffset,
        );
      }

      final Uint8List payload = reader.readView(declaredLength);
      final int expectedPaddingLength = (4 - declaredLength % 4) % 4;
      final int paddingLength = expectedPaddingLength.clamp(0, reader.remaining);
      final Uint8List paddingData = reader.readBytes(paddingLength);
      if (paddingLength != expectedPaddingLength) {
        context.issue('Truncated four-byte padding after embedded pattern', reader.baseOffset + reader.offset);
      } else if (_containsNonzero(paddingData)) {
        context.issue('Embedded-pattern alignment padding contains nonzero bytes', reader.baseOffset + reader.offset - paddingData.length);
      }

      PsPattern? pattern;
      String? decodeError;
      try {
        final PsPatternDecodeResult decoded = PsPatternRecordDecoder.decode(
          reader: PsBinaryReader(
            bytes: payload,
            baseOffset: recordOffset + 4,
          ),
          kind: PsPatternRecordKind.embedded,
          options: PsPatternDecodeOptions(
            maxDimension: context.options.maxPatternDimension,
            maxChannelCount: context.options.maxPatternChannelCount,
            maxVirtualMemoryBytes: context.options.maxPatternBytes,
            maxNameCodeUnits: context.options.maxPatternNameCodeUnits,
            maxDecodedBytes: context.options.maxDecodedPixelBytes - context.decodedPixelBytes,
            decodeChannelData: context.options.decodePatternChannelData,
            preserveChannelData: context.options.preservePatternChannelData,
            preserveRecordData: context.options.preservePatternRecordData,
          ),
          onIssue: (message, offset) => context.issue(message, offset),
          onDecodedBytesRequired: (bytes, offset) => context.ensureDecodedBytes(bytes, offset),
        );
        pattern = decoded.pattern;
        context.decodedPixelBytes += decoded.decodedBytes;
      } on AslFormatException {
        rethrow;
      } on PsFormatException catch (error) {
        if (_isResourceLimitError(error)) {
          throw AslFormatException(
            message: error.message,
            source: context.source,
            offset: error.offset ?? recordOffset,
          );
        }
        if (context.options.mode == AslDecodeMode.strict) {
          rethrow;
        }
        decodeError = error.message;
        context.warning('Embedded pattern ${index + 1} could not be decoded: ${error.message}', error.offset ?? recordOffset);
      }
      context.addPattern(
        AslPatternRecord(
          index: index,
          sourceOffset: recordOffset,
          declaredLength: declaredLength,
          pattern: pattern,
          data: context.options.preservePatternRecordData ? payload : Uint8List(0),
          dataByteCount: payload.length,
          paddingData: context.options.preservePatternRecordData ? paddingData : Uint8List(0),
          decodeError: decodeError,
        ),
      );
      index++;
    }
    context.patternIndex = null;
  }

  /// Decodes every style record declared after the pattern section.
  static bool _decodeStyles(PsBinaryReader reader, _AslDecodeContext context) {
    for (int index = 0; index < context.declaredStyleCount; index++) {
      context.styleIndex = index;
      final int recordStart = reader.offset;
      final int recordOffset = reader.baseOffset + recordStart;
      if (reader.remaining < 4) {
        context.setTrailing(Uint8List.sublistView(reader.bytes, recordStart));
        context.issue('File ends before style ${index + 1} length field', recordOffset);
        context.styleIndex = null;
        return false;
      }
      final int declaredLength = reader.readUint32();
      if (declaredLength > context.options.maxStyleBytes) {
        throw AslFormatException(
          message: 'ASL style record length $declaredLength exceeds the configured ${context.options.maxStyleBytes} byte limit',
          source: context.source,
          offset: recordOffset,
        );
      }
      if (declaredLength > reader.remaining) {
        final Uint8List available = reader.readBytes(reader.remaining);
        context.addStyle(
          _opaqueStyle(
            index: index,
            sourceOffset: recordOffset,
            declaredLength: declaredLength,
            data: context.options.preserveStyleRecordData ? available : null,
            error: 'record length exceeds the available bytes',
          ),
        );
        context.issue('Style record length $declaredLength exceeds the ${available.length} available bytes', recordOffset);
        context.styleIndex = null;
        return false;
      }

      final Uint8List payload = reader.readView(declaredLength);
      final int expectedPaddingLength = (4 - declaredLength % 4) % 4;
      final int paddingLength = expectedPaddingLength.clamp(0, reader.remaining);
      Uint8List paddingData = Uint8List(0);
      if (paddingLength > 0) {
        paddingData = reader.readBytes(paddingLength);
        if (paddingLength != expectedPaddingLength) {
          context.issue('Truncated four-byte padding after style record', reader.baseOffset + reader.offset);
        } else if (_containsNonzero(paddingData)) {
          context.issue('Style-record alignment padding contains nonzero bytes', reader.baseOffset + reader.offset - paddingData.length);
        }
      }

      try {
        context.addStyle(
          _decodeStyleRecord(
            payload: payload,
            index: index,
            recordOffset: recordOffset,
            paddingData: paddingData,
            context: context,
          ),
        );
      } on AslFormatException {
        rethrow;
      } on PsFormatException catch (error) {
        if (_isResourceLimitError(error)) {
          throw AslFormatException(
            message: error.message,
            source: context.source,
            offset: error.offset ?? recordOffset,
          );
        }
        if (context.options.mode == AslDecodeMode.strict) {
          rethrow;
        }
        context.addStyle(
          _opaqueStyle(
            index: index,
            sourceOffset: recordOffset,
            declaredLength: declaredLength,
            data: context.options.preserveStyleRecordData ? payload : null,
            paddingData: context.options.preserveStyleRecordData ? paddingData : Uint8List(0),
            error: error.message,
          ),
        );
        context.warning('Style ${index + 1} could not be decoded: ${error.message}', error.offset ?? recordOffset);
      }
    }
    context.styleIndex = null;
    return true;
  }

  /// Decodes the two versioned Action Descriptors in one style [payload].
  static AslStyle _decodeStyleRecord({
    required Uint8List payload,
    required int index,
    required int recordOffset,
    required Uint8List paddingData,
    required _AslDecodeContext context,
  }) {
    final PsBinaryReader reader = PsBinaryReader(
      bytes: payload,
      baseOffset: recordOffset + 4,
    );
    final int identificationVersionOffset = reader.baseOffset + reader.offset;
    final int identificationVersion = reader.readUint32();
    if (identificationVersion != _descriptorVersion) {
      context.issue('Style identification descriptor version $identificationVersion is not currently defined', identificationVersionOffset);
    }
    final PsDescriptor identification = PsDescriptorCodec.decodeReader(
      reader,
      options: context.options.descriptorOptions,
    );
    if (identification.classId != 'null') {
      context.issue('Style identification descriptor uses unexpected class "${identification.classId}"', identificationVersionOffset + 4);
    }

    final int styleVersionOffset = reader.baseOffset + reader.offset;
    final int styleVersion = reader.readUint32();
    if (styleVersion != _descriptorVersion) {
      context.issue('Style information descriptor version $styleVersion is not currently defined', styleVersionOffset);
    }
    final PsDescriptor styleDescriptor = PsDescriptorCodec.decodeReader(
      reader,
      options: context.options.descriptorOptions,
    );
    if (styleDescriptor.classId != 'Styl') {
      context.issue('Style information descriptor uses unexpected class "${styleDescriptor.classId}"', styleVersionOffset + 4);
    }

    final Uint8List recordTrailingData = reader.readBytes(reader.remaining);
    if (recordTrailingData.length > 3 || _containsNonzero(recordTrailingData)) {
      context.issue('${recordTrailingData.length} extension bytes remain after the style descriptors', reader.baseOffset + reader.offset - recordTrailingData.length);
    }
    final String? serializedName = switch (identification.value('Nm  ')) {
      PsStringValue(:final String value) => value,
      _ => null,
    };
    final String? normalizedName = serializedName == null ? null : _trimTerminalNulls(serializedName);
    final String? id = identification.aslString('Idnt');
    if (normalizedName == null || normalizedName.isEmpty) {
      context.issue('Style identification has no nonempty `Nm  ` string', identificationVersionOffset);
    }
    if (id == null || id.isEmpty) {
      context.issue('Style identification has no nonempty `Idnt` string', identificationVersionOffset);
    }

    final PsDescriptor? documentModeDescriptor = styleDescriptor.aslObject('documentMode');
    final PsDescriptor? layerEffectsDescriptor = styleDescriptor.aslObject('Lefx');
    final PsDescriptor? blendOptionsDescriptor = styleDescriptor.aslObject('blendOptions');
    _validateObjectValue(styleDescriptor, 'documentMode', documentModeDescriptor, context, styleVersionOffset);
    _validateObjectValue(styleDescriptor, 'Lefx', layerEffectsDescriptor, context, styleVersionOffset);
    _validateObjectValue(styleDescriptor, 'blendOptions', blendOptionsDescriptor, context, styleVersionOffset, required: false);
    if (layerEffectsDescriptor == null && blendOptionsDescriptor == null) {
      context.issue('Style contains neither layer effects nor blending options', styleVersionOffset);
    }

    return AslStyle(
      index: index,
      sourceOffset: recordOffset,
      declaredLength: payload.length,
      identificationDescriptorVersion: identificationVersion,
      identificationDescriptor: identification,
      styleDescriptorVersion: styleVersion,
      styleDescriptor: styleDescriptor,
      serializedName: serializedName,
      name: normalizedName == null ? null : _resolveZString(normalizedName),
      id: id,
      documentMode: documentModeDescriptor == null ? null : AslDocumentMode.fromDescriptor(documentModeDescriptor),
      layerEffects: layerEffectsDescriptor == null ? null : AslLayerEffects.fromDescriptor(layerEffectsDescriptor),
      blendOptions: blendOptionsDescriptor == null ? null : AslBlendOptions.fromDescriptor(blendOptionsDescriptor),
      recordTrailingData: recordTrailingData,
      paddingData: context.options.preserveStyleRecordData ? paddingData : Uint8List(0),
      recordData: context.options.preserveStyleRecordData ? payload : null,
      decodeError: null,
    );
  }

  /// Warns when [key] exists in [descriptor] but is not object-shaped.
  static void _validateObjectValue(
    PsDescriptor descriptor,
    String key,
    PsDescriptor? decoded,
    _AslDecodeContext context,
    int offset, {
    bool required = true,
  }) {
    final PsDescriptorValue? value = descriptor.value(key);
    if (value == null) {
      if (required) {
        context.issue('Style information has no `$key` item', offset);
      }
    } else if (decoded == null) {
      context.issue('Style information `$key` item is ${value.type}, not an object', offset);
    }
  }

  /// Creates a source-preserving style for a bounded undecodable record.
  static AslStyle _opaqueStyle({
    required int index,
    required int sourceOffset,
    required int declaredLength,
    required Uint8List? data,
    Uint8List? paddingData,
    required String error,
  }) => AslStyle(
    index: index,
    sourceOffset: sourceOffset,
    declaredLength: declaredLength,
    identificationDescriptorVersion: null,
    identificationDescriptor: null,
    styleDescriptorVersion: null,
    styleDescriptor: null,
    serializedName: null,
    name: null,
    id: null,
    documentMode: null,
    layerEffects: null,
    blendOptions: null,
    recordTrailingData: Uint8List(0),
    paddingData: paddingData ?? Uint8List(0),
    recordData: data,
    decodeError: error,
  );

  /// Decodes recognizable length-prefixed blocks after the declared styles.
  static void _decodeTaggedBlocks(PsBinaryReader reader, _AslDecodeContext context) {
    while (!reader.isAtEnd) {
      final int blockOffset = reader.baseOffset + reader.offset;
      if (reader.remaining < 12 || !_hasTaggedSignature(reader, 0)) {
        final Uint8List trailing = reader.readBytes(reader.remaining);
        context.setTrailing(trailing);
        context.issue('${trailing.length} unrecognized trailing bytes remain after the ASL payload', blockOffset);
        return;
      }
      if (context.taggedBlocks.length >= context.options.maxTaggedBlocks) {
        throw AslFormatException(
          message: 'ASL tagged-block count exceeds the configured ${context.options.maxTaggedBlocks} limit',
          source: context.source,
          offset: blockOffset,
        );
      }

      final bool usesWideLength = _hasLargeTaggedSignature(reader);
      if (usesWideLength && reader.remaining < 16) {
        final Uint8List trailing = reader.readBytes(reader.remaining);
        context.setTrailing(trailing);
        context.issue('Truncated ASL 8B64 tagged-block header', blockOffset);
        return;
      }

      final String signature = reader.readString(4);
      final String key = reader.readString(4);
      final int declaredLength = usesWideLength ? reader.readUint64() : reader.readUint32();
      final int payloadOffset = blockOffset + (usesWideLength ? 16 : 12);
      context.blockKey = key;
      if (declaredLength > context.options.maxTaggedBlockBytes) {
        throw AslFormatException(
          message: 'ASL tagged block $key length $declaredLength exceeds the configured ${context.options.maxTaggedBlockBytes} byte limit',
          source: context.source,
          offset: blockOffset + 8,
        );
      }
      if (declaredLength > reader.remaining) {
        final Uint8List available = reader.readView(reader.remaining);
        context.addTaggedBlock(
          AslTaggedBlock(
            signature: signature,
            key: key,
            offset: blockOffset,
            declaredLength: declaredLength,
            data: context.options.preserveTaggedBlockData ? available : Uint8List(0),
            dataByteCount: available.length,
            paddingData: Uint8List(0),
          ),
        );
        context.issue('ASL tagged block $key length $declaredLength exceeds the ${available.length} available bytes', blockOffset + 8);
        context.blockKey = null;
        return;
      }

      final Uint8List payload = reader.readView(declaredLength);
      final int paddingLength = _taggedPaddingLength(reader, declaredLength);
      final Uint8List paddingData = reader.readBytes(paddingLength);
      context.addTaggedBlock(
        AslTaggedBlock(
          signature: signature,
          key: key,
          offset: blockOffset,
          declaredLength: declaredLength,
          data: context.options.preserveTaggedBlockData ? payload : Uint8List(0),
          dataByteCount: payload.length,
          paddingData: context.options.preserveTaggedBlockData ? paddingData : Uint8List(0),
        ),
      );
      if (key == 'phry') {
        _decodeHierarchyBlock(
          payload: payload,
          payloadOffset: payloadOffset,
          context: context,
        );
      } else {
        context.issue('Unknown ASL tagged block $key was preserved', blockOffset + 4);
      }
      context.blockKey = null;
    }
  }

  /// Decodes the versioned Action Descriptor inside a `phry` payload.
  static void _decodeHierarchyBlock({
    required Uint8List payload,
    required int payloadOffset,
    required _AslDecodeContext context,
  }) {
    try {
      final PsBinaryReader reader = PsBinaryReader(
        bytes: payload,
        baseOffset: payloadOffset,
      );
      final int version = reader.readUint32();
      if (version != _descriptorVersion) {
        context.issue('ASL hierarchy descriptor version $version is not currently defined', payloadOffset);
      }
      final PsDescriptor descriptor = PsDescriptorCodec.decodeReader(
        reader,
        options: context.options.descriptorOptions,
      );
      if (!reader.isAtEnd) {
        context.issue('${reader.remaining} extension bytes remain after the ASL hierarchy descriptor', reader.baseOffset + reader.offset);
      }
      context.addHierarchyDescriptor(descriptor);
      context.addHierarchyEntries(
        AslHierarchyMapper.decode(
          root: descriptor,
          styles: context.styles,
          maxEntries: context.options.maxHierarchyEntries - context.hierarchy.length,
          onIssue: (message) => context.issue(message, payloadOffset),
        ),
      );
    } on AslFormatException {
      rethrow;
    } on PsFormatException catch (error) {
      if (_isResourceLimitError(error)) {
        throw AslFormatException(
          message: error.message,
          source: context.source,
          offset: error.offset ?? payloadOffset,
        );
      }
      if (context.options.mode == AslDecodeMode.strict) {
        rethrow;
      }
      context.warning('ASL hierarchy could not be decoded: ${error.message}', error.offset ?? payloadOffset);
    }
  }

  /// Returns optional zero padding before the next recognizable tagged block.
  static int _taggedPaddingLength(PsBinaryReader reader, int payloadLength) {
    if (_hasTaggedSignature(reader, 0)) {
      return 0;
    }
    final int expectedLength = (4 - payloadLength % 4) % 4;
    if (expectedLength == 0 || reader.remaining < expectedLength || !_allZero(reader, expectedLength)) {
      return 0;
    }
    if (reader.remaining == expectedLength || _hasTaggedSignature(reader, expectedLength)) {
      return expectedLength;
    }
    return 0;
  }

  /// Tests whether the first [length] remaining bytes are all zero.
  static bool _allZero(PsBinaryReader reader, int length) {
    for (int index = 0; index < length; index++) {
      if (reader.bytes[reader.offset + index] != 0) {
        return false;
      }
    }
    return true;
  }

  /// Tests whether a supported tagged signature starts at [relativeOffset].
  static bool _hasTaggedSignature(PsBinaryReader reader, int relativeOffset) {
    if (relativeOffset < 0 || reader.remaining < relativeOffset + 4) {
      return false;
    }
    final int offset = reader.offset + relativeOffset;
    return _hasString(reader.bytes, offset, _taggedBlockSignature) || _hasString(reader.bytes, offset, _largeTaggedBlockSignature);
  }

  /// Tests whether the current tagged block uses a 64-bit payload length.
  static bool _hasLargeTaggedSignature(PsBinaryReader reader) => _hasString(reader.bytes, reader.offset, _largeTaggedBlockSignature);

  /// Tests whether [bytes] contains [value] at [offset].
  static bool _hasString(Uint8List bytes, int offset, String value) {
    if (offset < 0 || offset + value.length > bytes.length) {
      return false;
    }
    for (int index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
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

  /// Whether [error] represents a configured safety limit rather than damage.
  static bool _isResourceLimitError(PsFormatException error) => error.message.contains('configured');

  /// Resolves Photoshop's `$$$/key=Display Name` localization form.
  static String _resolveZString(String value) {
    if (!value.startsWith(r'$$$/')) {
      return value;
    }
    final int equals = value.indexOf('=');
    if (equals >= 0 && equals + 1 < value.length) {
      return value.substring(equals + 1);
    }
    final int slash = value.lastIndexOf('/');
    return slash < 0 || slash + 1 >= value.length ? value : value.substring(slash + 1);
  }

  /// Removes only terminal null characters from [value].
  static String _trimTerminalNulls(String value) {
    int end = value.length;
    while (end > 0 && value.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return value.substring(0, end);
  }

  /// Rejects negative resource limits before any input is processed.
  static void _validateOptions(AslDecodeOptions options) {
    final List<({String name, int value})> limits = <({String name, int value})>[
      (name: 'maxFileBytes', value: options.maxFileBytes),
      (name: 'maxPatternSectionBytes', value: options.maxPatternSectionBytes),
      (name: 'maxPatterns', value: options.maxPatterns),
      (name: 'maxPatternDimension', value: options.maxPatternDimension),
      (name: 'maxPatternChannelCount', value: options.maxPatternChannelCount),
      (name: 'maxPatternBytes', value: options.maxPatternBytes),
      (name: 'maxPatternNameCodeUnits', value: options.maxPatternNameCodeUnits),
      (name: 'maxDecodedPixelBytes', value: options.maxDecodedPixelBytes),
      (name: 'maxStyles', value: options.maxStyles),
      (name: 'maxStyleBytes', value: options.maxStyleBytes),
      (name: 'maxTaggedBlockBytes', value: options.maxTaggedBlockBytes),
      (name: 'maxTaggedBlocks', value: options.maxTaggedBlocks),
      (name: 'maxHierarchyEntries', value: options.maxHierarchyEntries),
      (name: 'descriptorOptions.maxDepth', value: options.descriptorOptions.maxDepth),
      (name: 'descriptorOptions.maxValues', value: options.descriptorOptions.maxValues),
    ];
    for (final ({String name, int value}) limit in limits) {
      if (limit.value < 0) {
        throw ArgumentError.value(limit.value, limit.name, 'must not be negative');
      }
    }
  }
}

/// Accumulates decoded values and source context for one ASL operation.
final class _AslDecodeContext {
  /// Complete input bytes.
  final Uint8List source;

  /// Caller-selected limits and compatibility policy.
  final AslDecodeOptions options;

  /// Envelope detected at the start of the input.
  final AslContainerKind containerKind;

  /// Standalone file version, when present.
  final int? version;

  /// Four-byte style signature.
  final String signature;

  /// Embedded-pattern section version.
  final int patternsVersion;

  /// Declared byte length of the embedded-pattern section.
  final int declaredPatternSectionLength;

  /// Every bounded pattern record decoded or preserved so far.
  final List<AslPatternRecord> patternRecords = <AslPatternRecord>[];

  /// Every bounded style record decoded or preserved so far.
  final List<AslStyle> styles = <AslStyle>[];

  /// Flattened hierarchy entries decoded so far.
  final List<AslHierarchyEntry> hierarchy = <AslHierarchyEntry>[];

  /// Hierarchy root descriptors decoded so far.
  final List<PsDescriptor> hierarchyDescriptors = <PsDescriptor>[];

  /// Tagged trailer blocks decoded so far.
  final List<AslTaggedBlock> taggedBlocks = <AslTaggedBlock>[];

  /// Recoverable issues collected in tolerant mode.
  final List<AslWarning> warnings = <AslWarning>[];

  /// First source position observed for every nonempty pattern identifier.
  final Map<String, int> _patternIndicesById = <String, int>{};

  /// First source position observed for every nonempty style identifier.
  final Map<String, int> _styleIndicesById = <String, int>{};

  /// Pattern section suffix with no reliable record boundary.
  Uint8List patternSectionTrailingData = Uint8List(0);

  /// Physical byte count of the undecodable pattern-section suffix.
  int patternSectionTrailingByteCount = 0;

  /// File suffix with no recognizable tagged-block boundary.
  Uint8List trailingData = Uint8List(0);

  /// Physical byte count of the unrecognized file suffix.
  int trailingByteCount = 0;

  /// Style count read after the pattern section.
  int declaredStyleCount = 0;

  /// Aggregate uncompressed pattern bytes retained so far.
  int decodedPixelBytes = 0;

  /// Current pattern position used to enrich warnings.
  int? patternIndex;

  /// Current style position used to enrich warnings.
  int? styleIndex;

  /// Current tagged-block key used to enrich warnings.
  String? blockKey;

  /// Creates an empty decode context for one source buffer.
  _AslDecodeContext({
    required this.source,
    required this.options,
    required this.containerKind,
    required this.version,
    required this.signature,
    required this.patternsVersion,
    required this.declaredPatternSectionLength,
  });

  /// Adds one decoded or opaque embedded pattern record and validates its identifier.
  void addPattern(AslPatternRecord record) {
    patternRecords.add(record);
    final PsPattern? pattern = record.pattern;
    if (pattern == null) {
      return;
    }
    if (pattern.id.isEmpty) {
      issue('Pattern ${record.index + 1} has an empty identifier', record.sourceOffset);
      return;
    }
    final int? previous = _patternIndicesById[pattern.id];
    if (previous != null) {
      issue('Pattern ${record.index + 1} duplicates identifier "${pattern.id}" from pattern ${previous + 1}', record.sourceOffset);
    }
    _patternIndicesById[pattern.id] = record.index;
  }

  /// Adds one decoded or opaque style record and validates its identifier.
  void addStyle(AslStyle style) {
    styles.add(style);
    final String? id = style.id;
    if (id == null || id.isEmpty) {
      return;
    }
    final int? previous = _styleIndicesById[id];
    if (previous != null) {
      issue('Style ${style.index + 1} duplicates identifier "$id" from style ${previous + 1}', style.sourceOffset);
    }
    _styleIndicesById[id] = style.index;
  }

  /// Adds one preserved tagged trailer block.
  void addTaggedBlock(AslTaggedBlock block) => taggedBlocks.add(block);

  /// Adds one complete hierarchy descriptor.
  void addHierarchyDescriptor(PsDescriptor descriptor) => hierarchyDescriptors.add(descriptor);

  /// Adds typed hierarchy [entries] in source order with globally unique indices.
  void addHierarchyEntries(List<AslHierarchyEntry> entries) {
    final int indexOffset = hierarchy.length;
    hierarchy.addAll(<AslHierarchyEntry>[
      for (final AslHierarchyEntry entry in entries)
        AslHierarchyEntry(
          index: entry.index + indexOffset,
          kind: entry.kind,
          depth: entry.depth,
          classId: entry.classId,
          name: entry.name,
          id: entry.id,
          styleIndex: entry.styleIndex,
          rawDescriptor: entry.rawDescriptor,
        ),
    ]);
  }

  /// Retains the undecodable suffix of the pattern section when requested.
  void setPatternTrailing(Uint8List data) {
    patternSectionTrailingByteCount = data.length;
    patternSectionTrailingData = options.preserveTrailingData ? Uint8List.fromList(data) : Uint8List(0);
  }

  /// Retains the undecodable file suffix when requested.
  void setTrailing(Uint8List data) {
    trailingByteCount = data.length;
    trailingData = options.preserveTrailingData ? Uint8List.fromList(data) : Uint8List(0);
  }

  /// Ensures a pattern decode remains inside the aggregate pixel budget.
  void ensureDecodedBytes(int recordBytes, int offset) {
    if (recordBytes > options.maxDecodedPixelBytes - decodedPixelBytes) {
      throw PsFormatException(
        message: 'ASL decoded pattern data exceeds the configured ${options.maxDecodedPixelBytes} byte limit',
        source: source,
        offset: offset,
      );
    }
  }

  /// Reports a compatibility issue according to [options].
  void issue(String message, int? offset) {
    if (options.mode == AslDecodeMode.strict) {
      throw AslFormatException(
        message: message,
        source: source,
        offset: offset,
      );
    }
    warning(message, offset);
  }

  /// Records a recoverable issue without applying strict-mode policy.
  void warning(String message, int? offset) {
    warnings.add(
      AslWarning(
        message: message,
        offset: offset,
        patternIndex: patternIndex,
        styleIndex: styleIndex,
        blockKey: blockKey,
      ),
    );
  }

  /// Builds the final immutable ASL model.
  AslFile build() => AslFile(
    containerKind: containerKind,
    version: version,
    signature: signature,
    patternsVersion: patternsVersion,
    declaredPatternSectionLength: declaredPatternSectionLength,
    patternRecords: patternRecords,
    patternSectionTrailingData: patternSectionTrailingData,
    patternSectionTrailingByteCount: patternSectionTrailingByteCount,
    declaredStyleCount: declaredStyleCount,
    styles: styles,
    hierarchy: hierarchy,
    hierarchyDescriptors: hierarchyDescriptors,
    taggedBlocks: taggedBlocks,
    trailingData: trailingData,
    trailingByteCount: trailingByteCount,
    warnings: warnings,
    decodedPixelBytes: decodedPixelBytes,
    sourceData: options.preserveSourceData ? source : null,
  );
}

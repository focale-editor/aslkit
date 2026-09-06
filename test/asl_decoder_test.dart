import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/asl_fixture_builder.dart';

/// Exercises ASL descriptors, patterns, hierarchies, recovery, and limits.
void main() {
  group('AslDecoder', () {
    test('decodes a complete style, embedded pattern, and hierarchy', () {
      final Uint8List bytes = _completeFile();

      final AslFile file = AslDecoder.decode(
        bytes,
        options: const AslDecodeOptions(mode: AslDecodeMode.strict),
      );
      final AslStyle style = file.styles.single;
      final AslLayerEffects effects = style.layerEffects!;
      final PsPattern pattern = file.patterns.single;

      check(file.containerKind).equals(AslContainerKind.styleLibrary);
      check(file.version).equals(2);
      check(file.signature).equals('8BSL');
      check(file.patternsVersion).equals(3);
      check(file.declaredStyleCount).equals(1);
      check(file.isFullyDecoded).isTrue();
      check(file.warnings).isEmpty();
      check(file.sourceData).isNotNull().deepEquals(bytes);
      check(style.name).equals('Test style');
      check(style.id).equals('style-id');
      check(style.documentMode?.colorSpace?.value).equals('RGBC');
      check(style.documentMode?.depth).equals(16);
      check(effects.scale?.value).equals(100);
      check(effects.masterEnabled).isNotNull().isTrue();
      check(effects.effects).length.equals(4);
      check(effects.effectsOf(AslEffectKind.dropShadow)).length.equals(3);
      check(effects.firstEffectOf(AslEffectKind.dropShadow)?.color?.components['Rd  ']?.value).equals(12);
      check(effects.effectsOf(AslEffectKind.dropShadow).last.enabled).isNotNull().isFalse();
      check(style.patternReferences.single.id).equals('pattern-id');
      check(file.patternFor(style.patternReferences.single)).identicalTo(pattern);
      check(pattern.renderRgba8().rgba).deepEquals(<int>[127, 127, 127, 255]);
      check(style.blendOptions?.opacity?.value).equals(88);
      check(style.blendOptions?.blendMode?.value).equals('Scrn');
      check(style.blendOptions?.fillOpacity?.value).equals(64);
      check(style.blendOptions?.blendRanges.single.channel).equals('Gry ');
      check(style.blendOptions?.blendRanges.single.destinationWhiteHigh).equals(220);
      check(file.hierarchy).length.equals(3);
      check(file.hierarchy.first.kind).equals(AslHierarchyEntryKind.groupStart);
      check(file.styleFor(file.hierarchy[1])).identicalTo(style);
      check(file.hierarchy.last.kind).equals(AslHierarchyEntryKind.groupEnd);
      check(AslEncoder.encode(file)).deepEquals(bytes);
    });

    test('detects and reconstructs a Styles.psp payload without a version prefix', () {
      final Uint8List style = _style();
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[style],
        palette: true,
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.containerKind).equals(AslContainerKind.stylesPalette);
      check(file.version).isNull();
      check(file.styles.single.name).equals('Test style');
      check(AslEncoder.encode(file)).deepEquals(bytes);
    });

    test('accepts a wide hierarchy block in strict mode', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[_style()],
        blocks: <AslTestTaggedBlock>[
          AslFixtureBuilder.hierarchyBlock(signature: '8B64'),
        ],
      );

      final AslFile file = AslDecoder.decode(
        bytes,
        options: const AslDecodeOptions(mode: AslDecodeMode.strict),
      );

      check(file.taggedBlocks.single.signature).equals('8B64');
      check(file.hierarchy).length.equals(3);
      check(AslEncoder.encode(file)).deepEquals(bytes);
    });

    test('resolves localized ZString names while preserving serialized text', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          AslFixtureBuilder.style(
            name: r'$$$/Styles/Probe=Display name',
            id: 'style-id',
            layerEffects: AslFixtureBuilder.layerEffects(),
          ),
        ],
      );

      final AslStyle style = AslDecoder.decode(bytes).styles.single;

      check(style.serializedName).equals(r'$$$/Styles/Probe=Display name');
      check(style.name).equals('Display name');
      check(AslEncoder.encode(AslDecoder.decode(bytes))).deepEquals(bytes);
    });

    test('preserves a malformed bounded style and continues with the next one', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          Uint8List.fromList(<int>[0, 0, 0, 16, 1, 2, 3]),
          _style(),
        ],
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.styles).length.equals(2);
      check(file.styles.first.isDecoded).isFalse();
      check(file.styles.first.recordData).isNotNull().deepEquals(<int>[0, 0, 0, 16, 1, 2, 3]);
      check(file.styles.last.name).equals('Test style');
      check(file.warnings).length.equals(1);
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(mode: AslDecodeMode.strict))).throws<AslFormatException>();
    });

    test('preserves a malformed bounded pattern and decodes the following pattern', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[_style()],
        patterns: <Uint8List>[
          Uint8List.fromList(<int>[1, 2]),
          AslFixtureBuilder.grayscalePattern(),
        ],
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.patternRecords).length.equals(2);
      check(file.patternRecords.first.isDecoded).isFalse();
      check(file.patternRecords.last.isDecoded).isTrue();
      check(file.patterns.single.name).equals('Gray tile');
      check(file.warnings).length.equals(1);
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);
    });

    test('tracks omitted preservation data and prevents lossy output', () {
      final Uint8List bytes = _completeFile();

      final AslFile file = AslDecoder.decode(
        bytes,
        options: const AslDecodeOptions(
          decodePatternChannelData: false,
          preservePatternChannelData: false,
          preservePatternRecordData: false,
          preserveStyleRecordData: false,
          preserveTaggedBlockData: false,
          preserveTrailingData: false,
          preserveSourceData: false,
        ),
      );

      check(file.sourceData).isNull();
      check(file.patternRecords.single.data).isEmpty();
      check(file.patternRecords.single.dataByteCount).isGreaterThan(0);
      check(file.styles.single.recordData).isNull();
      check(file.taggedBlocks.single.data).isEmpty();
      check(file.taggedBlocks.single.dataByteCount).isGreaterThan(0);
      check(() => AslEncoder.encode(file)).throws<AslWriteException>();
    });

    test('retains an undecodable pattern-section suffix without losing styles', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[_style()],
        patternTrailingData: const <int>[0, 0, 0, 20, 1],
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.patternRecords).isEmpty();
      check(file.patternSectionTrailingData).deepEquals(<int>[0, 0, 0, 20, 1]);
      check(file.styles.single.isDecoded).isTrue();
      check(file.warnings).length.equals(1);
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);

      final Uint8List sanitized = AslEncoder.encode(
        file,
        options: const AslEncodeOptions(
          includePatternSectionTrailingData: false,
        ),
      );
      final AslFile reopened = AslDecoder.decode(
        sanitized,
        options: const AslDecodeOptions(mode: AslDecodeMode.strict),
      );
      check(reopened.patternSectionTrailingData).isEmpty();
      check(reopened.styles.single.name).equals('Test style');
    });

    test('reports unknown versions and tagged blocks only in tolerant mode', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          AslFixtureBuilder.style(
            name: 'Test style',
            id: 'style-id',
            layerEffects: AslFixtureBuilder.layerEffects(),
            identificationVersion: 17,
          ),
        ],
        version: 4,
        patternsVersion: 5,
        blocks: <AslTestTaggedBlock>[
          AslTestTaggedBlock(
            signature: '8B64',
            key: 'futr',
            data: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.styles.single.identificationDescriptorVersion).equals(17);
      check(file.taggedBlocks.single.signature).equals('8B64');
      check(file.warnings).length.equals(4);
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(mode: AslDecodeMode.strict))).throws<AslFormatException>();
    });

    test('detects duplicate style and pattern identifiers', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[_style(), _style()],
        patterns: <Uint8List>[
          AslFixtureBuilder.grayscalePattern(),
          AslFixtureBuilder.grayscalePattern(value: 200),
        ],
      );

      final AslFile file = AslDecoder.decode(bytes);

      check(file.warnings).length.equals(2);
      check(file.styleById('style-id')).identicalTo(file.styles.last);
      check(file.patternById('pattern-id')).identicalTo(file.patterns.last);
    });

    test('enforces file, pattern, style, descriptor, and decoded-byte limits', () {
      final Uint8List bytes = _completeFile();

      check(() => AslDecoder.decode(bytes, options: AslDecodeOptions(maxFileBytes: bytes.length - 1))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxPatternSectionBytes: 1))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxPatterns: 0))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxPatternBytes: 1))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxDecodedPixelBytes: 0))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxStyles: 0))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxStyleBytes: 1))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxTaggedBlockBytes: 1))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxTaggedBlocks: 0))).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxHierarchyEntries: 2))).throws<AslFormatException>();
      check(
        () => AslDecoder.decode(
          bytes,
          options: const AslDecodeOptions(descriptorOptions: PsDescriptorDecodeOptions(maxValues: 1)),
        ),
      ).throws<AslFormatException>();
    });

    test('rejects invalid envelopes and negative safety limits', () {
      final Uint8List bytes = _completeFile();
      final Uint8List wrongSignature = Uint8List.fromList(bytes)..setRange(2, 6, 'NOPE'.codeUnits);

      check(() => AslDecoder.decode(Uint8List(0))).throws<AslFormatException>();
      check(() => AslDecoder.decode(wrongSignature)).throws<AslFormatException>();
      check(() => AslDecoder.decode(bytes, options: const AslDecodeOptions(maxStyles: -1))).throws<ArgumentError>();
    });
  });
}

/// Builds the representative canonical style record used by most tests.
Uint8List _style() => AslFixtureBuilder.style(
  name: 'Test style',
  id: 'style-id',
  layerEffects: AslFixtureBuilder.layerEffects(),
  blendOptions: AslFixtureBuilder.blendOptions(),
  documentMode: const PsDescriptor(
    name: '',
    classId: 'documentMode',
    items: <PsDescriptorItem>[
      PsDescriptorItem(
        key: 'ClrS',
        value: PsEnumeratedValue(typeId: 'ClrS', value: 'RGBC'),
      ),
      PsDescriptorItem(key: 'Dpth', value: PsIntegerValue(value: 16)),
    ],
  ),
);

/// Builds a complete representative ASL file with all major container sections.
Uint8List _completeFile() => AslFixtureBuilder.file(
  styles: <Uint8List>[_style()],
  patterns: <Uint8List>[AslFixtureBuilder.grayscalePattern()],
  blocks: <AslTestTaggedBlock>[AslFixtureBuilder.hierarchyBlock()],
);

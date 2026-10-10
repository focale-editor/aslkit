import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/asl_fixture_builder.dart';

/// Exercises editable ASL models and strict encoder validation.
void main() {
  test('reads and rewrites the version 1 layout of Photoshop CS2', () {
    PsDescriptor style(String name) => PsDescriptor(
      name: '',
      classId: 'null',
      items: [
        const PsDescriptorItem(
          key: 'Lefx',
          value: PsObjectValue(
            value: PsDescriptor(
              name: '',
              classId: 'null',
              items: [PsDescriptorItem(key: 'masterFXSwitch', value: PsBooleanValue(value: true))],
            ),
          ),
        ),
        PsDescriptorItem(
          key: 'Nm  ',
          value: PsStringValue(value: '$name\u0000'),
        ),
      ],
    );
    final PsBinaryWriter writer = PsBinaryWriter()
      ..writeUint16(1)
      ..writeString('8BSL')
      ..writeUint16(2)
      ..writeUint32(0);
    PsVersionedDescriptorCodec.write(
      writer,
      PsVersionedDescriptor(
        descriptor: PsDescriptor(
          name: '',
          classId: 'null',
          items: [
            PsDescriptorItem(
              key: 'StyD',
              value: PsListValue(
                values: [
                  PsObjectValue(value: style('Neon')),
                  PsObjectValue(value: style('Glass')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final Uint8List bytes = writer.takeBytes();

    final AslFile file = AslDecoder.decode(bytes, options: const AslDecodeOptions(mode: AslDecodeMode.strict));

    check(file.version).equals(1);
    check(file.styles.map((style) => style.name).toList()).deepEquals(['Neon', 'Glass']);
    check(file.styles.first.layerEffects).isNotNull();
    check(AslEncoder.encode(file)).deepEquals(bytes);
  });

  test('writes new and edited patterns from their pixels', () {
    final Uint8List rgba = Uint8List.fromList([255, 0, 0, 255, 0, 0, 255, 128, 0, 255, 0, 255, 10, 20, 30, 0]);
    final AslFile source = AslFile.editable(
      styles: [],
      patternRecords: [AslPatternRecord.create(PsPattern.fromRgba8(id: 'tile-id', name: 'Tile', width: 2, height: 2, rgba: rgba))],
    );

    final Uint8List bytes = AslEncoder.encode(source);
    final AslFile decoded = AslDecoder.decode(bytes, options: const AslDecodeOptions(mode: AslDecodeMode.strict));
    final PsPattern pattern = decoded.patternRecords.single.pattern!;

    check(pattern.id).equals('tile-id');
    check(pattern.name).equals('Tile');
    check(pattern.renderRgba8().rgba).deepEquals(rgba);
    // A decoded record keeps its exact bytes; replacing it re-encodes the new pixels.
    check(AslEncoder.encode(decoded)).deepEquals(bytes);
    final AslFile edited = AslFile.editable(
      styles: [],
      patternRecords: [
        AslPatternRecord.create(PsPattern.fromRgba8(id: 'tile-id', name: 'Edited', width: 1, height: 1, rgba: Uint8List.fromList([1, 2, 3, 255]))),
      ],
    );
    check(AslDecoder.decode(AslEncoder.encode(edited)).patternRecords.single.pattern!.name).equals('Edited');
  });

  test('rejects records with neither preserved bytes nor pixels', () {
    final AslFile source = AslFile.editable(
      styles: [],
      patternRecords: [
        AslPatternRecord(index: 0, sourceOffset: -1, declaredLength: 0, pattern: null, data: Uint8List(0), paddingData: Uint8List(0), decodeError: 'broken'),
      ],
    );

    check(() => AslEncoder.encode(source, options: const AslEncodeOptions(mode: AslEncodeMode.permissive))).throws<AslWriteException>();
  });

  test('authored wide tagged blocks encode and decode on every runtime', () {
    final AslFile source = AslFile.editable(
      styles: [],
      taggedBlocks: [
        AslTaggedBlock(signature: '8B64', key: 'test', offset: -1, declaredLength: 3, data: Uint8List.fromList([17, 34, 51]), dataByteCount: 3, paddingData: Uint8List(1)),
      ],
    );
    final Uint8List bytes = AslEncoder.encode(source);
    final AslFile restored = AslDecoder.decode(bytes);
    check(restored.taggedBlocks.single.signature).equals('8B64');
    check(restored.taggedBlocks.single.data).deepEquals([17, 34, 51]);
  });

  group('AslEncoder', () {
    test('creates a Photoshop-shaped file from an editable style', () {
      final AslStyle style = AslStyle.editable(
        name: 'Authored style',
        id: 'authored-id',
        layerEffects: AslFixtureBuilder.layerEffects(),
        blendOptions: AslFixtureBuilder.blendOptions(),
      );
      final AslFile file = AslFile.editable(styles: <AslStyle>[style]);

      final Uint8List bytes = AslEncoder.encode(file);
      final AslFile decoded = AslDecoder.decode(
        bytes,
        options: const AslDecodeOptions(mode: AslDecodeMode.strict),
      );

      check(decoded.styles.single.name).equals('Authored style');
      check(decoded.styles.single.id).equals('authored-id');
      check(decoded.styles.single.layerEffects?.effects).isNotNull().length.equals(4);
      check(decoded.styles.single.blendOptions?.blendRanges).isNotNull().length.equals(1);
      check(AslEncoder.encode(decoded)).deepEquals(bytes);
    });

    test('updates identity and style descriptors without reusing stale raw data', () {
      final Uint8List original = AslFixtureBuilder.file(
        styles: <Uint8List>[
          AslFixtureBuilder.style(
            name: 'Before',
            id: 'before-id',
            layerEffects: AslFixtureBuilder.layerEffects(),
          ),
        ],
      );
      final AslStyle decoded = AslDecoder.decode(original).styles.single;
      final PsDescriptor replacementEffects = AslFixtureBuilder.layerEffects().withValue('masterFXSwitch', const PsBooleanValue(value: false));
      final PsDescriptor replacementStyle = decoded.styleDescriptor!.withValue('Lefx', PsObjectValue(value: replacementEffects));
      final AslStyle edited = decoded.withIdentity(name: 'After', id: 'after-id').withStyleDescriptor(replacementStyle);

      final Uint8List encoded = AslEncoder.encode(AslFile.editable(styles: <AslStyle>[edited]));
      final AslStyle reopened = AslDecoder.decode(encoded).styles.single;

      check(reopened.name).equals('After');
      check(reopened.id).equals('after-id');
      check(reopened.layerEffects?.masterEnabled).isNotNull().isFalse();
      check(encoded).not((subject) => subject.deepEquals(original));
    });

    test('requires permissive mode for opaque compatibility records', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          Uint8List.fromList(<int>[0, 0, 0, 16, 1]),
        ],
      );
      final AslFile file = AslDecoder.decode(bytes);

      check(() => AslEncoder.encode(file)).throws<AslWriteException>();
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);
    });

    test('rejects noncanonical versions and trailing data in strict mode', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          AslFixtureBuilder.style(
            name: 'Test',
            id: 'id',
            layerEffects: AslFixtureBuilder.layerEffects(),
          ),
        ],
        version: 7,
        trailingData: const <int>[1, 2],
      );
      final AslFile file = AslDecoder.decode(bytes);

      check(() => AslEncoder.encode(file)).throws<AslWriteException>();
      check(
        AslEncoder.encode(
          file,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        ),
      ).deepEquals(bytes);
    });

    test('cannot edit identity data in an opaque style', () {
      final Uint8List bytes = AslFixtureBuilder.file(
        styles: <Uint8List>[
          Uint8List.fromList(<int>[0, 0, 0, 16, 1]),
        ],
      );
      final AslStyle style = AslDecoder.decode(bytes).styles.single;

      check(() => style.withIdentity(name: 'Unavailable')).throws<StateError>();
    });
  });
}

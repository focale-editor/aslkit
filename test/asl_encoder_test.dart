import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/asl_fixture_builder.dart';

/// Exercises editable ASL models and strict encoder validation.
void main() {
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

import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/asl_fixture_builder.dart';

/// Exercises truncation boundaries and deterministic malformed-input handling.
void main() {
  test('every truncation fails with a typed error or returns a bounded prefix', () {
    final Uint8List complete = AslFixtureBuilder.file(
      styles: <Uint8List>[
        AslFixtureBuilder.style(
          name: 'Robustness',
          id: 'robust-id',
          layerEffects: AslFixtureBuilder.layerEffects(),
          blendOptions: AslFixtureBuilder.blendOptions(),
        ),
      ],
      patterns: <Uint8List>[AslFixtureBuilder.grayscalePattern()],
      blocks: <AslTestTaggedBlock>[AslFixtureBuilder.hierarchyBlock(styleId: 'robust-id')],
    );

    for (int length = 0; length <= complete.length; length++) {
      final Uint8List prefix = Uint8List.sublistView(complete, 0, length);
      try {
        final AslFile file = AslDecoder.decode(prefix);
        check(file.sourceData?.length).equals(length);
      } on AslFormatException {
        continue;
      }
    }
  });

  test('decoding the same malformed input is deterministic', () {
    final Uint8List malformed = AslFixtureBuilder.file(
      styles: <Uint8List>[
        Uint8List.fromList(<int>[0, 0, 0, 16, 0xff, 0xff]),
      ],
      patternTrailingData: const <int>[0, 0, 0, 99, 4, 5],
    );

    final AslFile first = AslDecoder.decode(malformed);
    final AslFile second = AslDecoder.decode(malformed);

    check(first.warnings.map((warning) => warning.toString())).deepEquals(second.warnings.map((warning) => warning.toString()));
    check(
      AslEncoder.encode(
        first,
        options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
      ),
    ).deepEquals(malformed);
  });
}

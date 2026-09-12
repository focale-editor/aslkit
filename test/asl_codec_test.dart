import 'dart:convert';
import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Exercises the reusable `dart:convert` ASL interface.
void main() {
  group('AslCodec', () {
    test('converts complete files and composes with base64', () {
      const AslCodec codec = AslCodec(
        decodeOptions: AslDecodeOptions(mode: AslDecodeMode.strict),
        encodeOptions: AslEncodeOptions(mode: AslEncodeMode.strict),
      );
      final AslFile file = AslFile.editable(styles: <AslStyle>[]);

      final Uint8List encoded = codec.encode(file);
      final AslFile decoded = codec.decode(encoded.toList(growable: false));
      final Codec<AslFile, String> base64Codec = codec.fuse(base64);
      final AslFile decodedBase64 = base64Codec.decode(base64Codec.encode(file));

      check(decoded.styles).isEmpty();
      check(decodedBase64.containerKind).equals(file.containerKind);
      check(codec.decoder.options.mode).equals(AslDecodeMode.strict);
      check(codec.encoder.options.mode).equals(AslEncodeMode.strict);
    });
  });
}

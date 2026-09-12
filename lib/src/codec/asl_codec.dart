import 'dart:convert';
import 'dart:typed_data';

import 'package:aslkit/src/codec/asl_decoder.dart';
import 'package:aslkit/src/codec/asl_encoder.dart';
import 'package:aslkit/src/model/asl_file.dart';
import 'package:aslkit/src/model/asl_options.dart';

/// Converts ASL models to and from their binary representation.
///
/// Each conversion handles one complete in-memory file. The encoded type is
/// [List<int>] so this codec can be composed with standard `dart:convert`
/// codecs, while [encode] keeps the more precise [Uint8List] return type.
final class AslCodec extends Codec<AslFile, List<int>> {
  /// Options applied while decoding.
  final AslDecodeOptions decodeOptions;

  /// Options applied while encoding.
  final AslEncodeOptions encodeOptions;

  /// Creates a reusable codec with fixed decoding and encoding options.
  const AslCodec({
    this.decodeOptions = const AslDecodeOptions(),
    this.encodeOptions = const AslEncodeOptions(),
  });

  @override
  AslDecoder get decoder => AslDecoder(options: decodeOptions);

  @override
  AslEncoder get encoder => AslEncoder(options: encodeOptions);

  @override
  Uint8List encode(AslFile input) => encoder.convert(input);
}

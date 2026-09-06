import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';

/// One synthetic ASL tagged block used by decoder tests.
final class AslTestTaggedBlock {
  /// Four-byte ordinary or wide Photoshop signature.
  final String signature;

  /// Four-byte tagged-block key.
  final String key;

  /// Unpadded block payload.
  final Uint8List data;

  /// Optional bytes following the payload.
  final Uint8List paddingData;

  /// Creates one test tagged block.
  AslTestTaggedBlock({
    required this.signature,
    required this.key,
    required Uint8List data,
    Uint8List? paddingData,
  }) : data = Uint8List.fromList(data),
       paddingData = Uint8List.fromList(paddingData ?? const <int>[]);
}

/// Builds small byte-exact ASL fixtures independently of the production encoder.
abstract final class AslFixtureBuilder {
  /// Builds an ASL or styles-palette container from complete record payloads.
  static Uint8List file({
    required List<Uint8List> styles,
    List<Uint8List> patterns = const <Uint8List>[],
    List<AslTestTaggedBlock> blocks = const <AslTestTaggedBlock>[],
    bool palette = false,
    int version = 2,
    String signature = '8BSL',
    int patternsVersion = 3,
    int? declaredStyleCount,
    List<int> patternTrailingData = const <int>[],
    List<int> trailingData = const <int>[],
  }) {
    final PsBinaryWriter patternSection = PsBinaryWriter();
    for (final Uint8List pattern in patterns) {
      patternSection
        ..writeUint32(pattern.length)
        ..writeBytes(pattern)
        ..writeZeros((4 - pattern.length % 4) % 4);
    }
    patternSection.writeBytes(patternTrailingData);
    final Uint8List patternBytes = patternSection.takeBytes();

    final PsBinaryWriter writer = PsBinaryWriter();
    if (!palette) {
      writer.writeUint16(version);
    }
    writer
      ..writeString(signature)
      ..writeUint16(patternsVersion)
      ..writeUint32(patternBytes.length)
      ..writeBytes(patternBytes)
      ..writeUint32(declaredStyleCount ?? styles.length);
    for (final Uint8List style in styles) {
      writer
        ..writeUint32(style.length)
        ..writeBytes(style)
        ..writeZeros((4 - style.length % 4) % 4);
    }
    for (final AslTestTaggedBlock block in blocks) {
      writer
        ..writeString(block.signature)
        ..writeString(block.key)
        ..writeLength(block.data.length, wide: block.signature == '8B64')
        ..writeBytes(block.data)
        ..writeBytes(block.paddingData);
    }
    writer.writeBytes(trailingData);
    return writer.takeBytes();
  }

  /// Builds one canonical pair of version-16 style descriptors.
  static Uint8List style({
    required String name,
    required String id,
    required PsDescriptor layerEffects,
    PsDescriptor? blendOptions,
    PsDescriptor? documentMode,
    int identificationVersion = 16,
    int styleVersion = 16,
    List<int> trailingData = const <int>[],
  }) {
    final PsDescriptor identity = PsDescriptor(
      name: '',
      classId: 'null',
      items: <PsDescriptorItem>[
        PsDescriptorItem(
          key: 'Nm  ',
          value: PsStringValue(value: name),
        ),
        PsDescriptorItem(
          key: 'Idnt',
          value: PsStringValue(value: id),
        ),
      ],
    );
    final PsDescriptor mode = documentMode ?? const PsDescriptor(name: '', classId: 'documentMode');
    final PsDescriptor information = PsDescriptor(
      name: '',
      classId: 'Styl',
      items: <PsDescriptorItem>[
        PsDescriptorItem(
          key: 'documentMode',
          value: PsObjectValue(value: mode),
        ),
        PsDescriptorItem(
          key: 'Lefx',
          value: PsObjectValue(value: layerEffects),
        ),
        if (blendOptions != null)
          PsDescriptorItem(
            key: 'blendOptions',
            value: PsObjectValue(value: blendOptions),
          ),
      ],
    );
    final PsBinaryWriter writer = PsBinaryWriter()
      ..writeUint32(identificationVersion)
      ..writeBytes(PsDescriptorCodec.encode(identity))
      ..writeUint32(styleVersion)
      ..writeBytes(PsDescriptorCodec.encode(information))
      ..writeBytes(trailingData);
    writer.writeZeros((4 - writer.length % 4) % 4);
    return writer.takeBytes();
  }

  /// Builds a representative `Lefx` descriptor with single and multiple effects.
  static PsDescriptor layerEffects({
    String patternId = 'pattern-id',
  }) {
    const PsDescriptor rgb = PsDescriptor(
      name: '',
      classId: 'RGBC',
      items: <PsDescriptorItem>[
        PsDescriptorItem(key: 'Rd  ', value: PsDoubleValue(value: 12)),
        PsDescriptorItem(key: 'Grn ', value: PsDoubleValue(value: 34)),
        PsDescriptorItem(key: 'Bl  ', value: PsDoubleValue(value: 56)),
      ],
    );
    const PsDescriptor shadow = PsDescriptor(
      name: '',
      classId: 'DrSh',
      items: <PsDescriptorItem>[
        PsDescriptorItem(key: 'enab', value: PsBooleanValue(value: true)),
        PsDescriptorItem(
          key: 'Md  ',
          value: PsEnumeratedValue(typeId: 'BlnM', value: 'Mltp'),
        ),
        PsDescriptorItem(
          key: 'Opct',
          value: PsUnitFloatValue(unit: '#Prc', value: 72),
        ),
        PsDescriptorItem(
          key: 'Clr ',
          value: PsObjectValue(value: rgb),
        ),
      ],
    );
    final PsDescriptor pattern = PsDescriptor(
      name: '',
      classId: 'patternFill',
      items: <PsDescriptorItem>[
        const PsDescriptorItem(key: 'enab', value: PsBooleanValue(value: true)),
        PsDescriptorItem(
          key: 'Ptrn',
          value: PsObjectValue(
            value: PsDescriptor(
              name: '',
              classId: 'Ptrn',
              items: <PsDescriptorItem>[
                const PsDescriptorItem(
                  key: 'Nm  ',
                  value: PsStringValue(value: 'Gray tile'),
                ),
                PsDescriptorItem(
                  key: 'Idnt',
                  value: PsStringValue(value: patternId),
                ),
              ],
            ),
          ),
        ),
        const PsDescriptorItem(
          key: 'Scl ',
          value: PsUnitFloatValue(unit: '#Prc', value: 125),
        ),
      ],
    );
    return PsDescriptor(
      name: '',
      classId: 'Lefx',
      items: <PsDescriptorItem>[
        const PsDescriptorItem(
          key: 'Scl ',
          value: PsUnitFloatValue(unit: '#Prc', value: 100),
        ),
        const PsDescriptorItem(key: 'masterFXSwitch', value: PsBooleanValue(value: true)),
        const PsDescriptorItem(
          key: 'DrSh',
          value: PsObjectValue(value: shadow),
        ),
        PsDescriptorItem(
          key: 'dropShadowMulti',
          value: PsListValue(
            values: <PsDescriptorValue>[
              const PsObjectValue(value: shadow),
              PsObjectValue(value: shadow.withValue('enab', const PsBooleanValue(value: false))),
            ],
          ),
        ),
        PsDescriptorItem(
          key: 'patternFill',
          value: PsObjectValue(value: pattern),
        ),
      ],
    );
  }

  /// Builds blending options containing opacity, mode, and one Blend If range.
  static PsDescriptor blendOptions() {
    final PsDescriptor range = PsDescriptor(
      name: '',
      classId: 'Blnd',
      items: <PsDescriptorItem>[
        PsDescriptorItem(
          key: 'Chnl',
          value: PsReferenceValue(
            values: <PsDescriptorValue>[
              PsEnumeratedReferenceValue(
                name: '',
                classId: 'Chnl',
                typeId: 'Chnl',
                value: 'Gry ',
              ),
            ],
          ),
        ),
        const PsDescriptorItem(key: 'SrcB', value: PsIntegerValue(value: 10)),
        const PsDescriptorItem(key: 'Srcl', value: PsIntegerValue(value: 20)),
        const PsDescriptorItem(key: 'SrcW', value: PsIntegerValue(value: 230)),
        const PsDescriptorItem(key: 'Srcm', value: PsIntegerValue(value: 240)),
        const PsDescriptorItem(key: 'DstB', value: PsIntegerValue(value: 30)),
        const PsDescriptorItem(key: 'Dstl', value: PsIntegerValue(value: 40)),
        const PsDescriptorItem(key: 'DstW', value: PsIntegerValue(value: 210)),
        const PsDescriptorItem(key: 'Dstt', value: PsIntegerValue(value: 220)),
      ],
    );
    return PsDescriptor(
      name: '',
      classId: 'blendOptions',
      items: <PsDescriptorItem>[
        const PsDescriptorItem(
          key: 'Opct',
          value: PsUnitFloatValue(unit: '#Prc', value: 88),
        ),
        const PsDescriptorItem(
          key: 'Md  ',
          value: PsEnumeratedValue(typeId: 'BlnM', value: 'Scrn'),
        ),
        const PsDescriptorItem(
          key: 'fillOpacity',
          value: PsUnitFloatValue(unit: '#Prc', value: 64),
        ),
        PsDescriptorItem(
          key: 'Blnd',
          value: PsListValue(values: <PsDescriptorValue>[PsObjectValue(value: range)]),
        ),
      ],
    );
  }

  /// Builds a one-pixel, eight-bit grayscale embedded pattern payload.
  static Uint8List grayscalePattern({
    String name = 'Gray tile',
    String id = 'pattern-id',
    int value = 127,
  }) {
    final PsBinaryWriter channel = PsBinaryWriter()
      ..writeUint32(8)
      ..writeInt32(0)
      ..writeInt32(0)
      ..writeInt32(1)
      ..writeInt32(1)
      ..writeUint16(8)
      ..writeUint8(0)
      ..writeUint8(value);
    final Uint8List channelBytes = channel.takeBytes();
    final PsBinaryWriter virtualMemory = PsBinaryWriter()
      ..writeInt32(0)
      ..writeInt32(0)
      ..writeInt32(1)
      ..writeInt32(1)
      ..writeUint32(1)
      ..writeUint32(1)
      ..writeUint32(channelBytes.length)
      ..writeBytes(channelBytes)
      ..writeUint32(0)
      ..writeUint32(0);
    final Uint8List virtualMemoryBytes = virtualMemory.takeBytes();
    final PsBinaryWriter writer = PsBinaryWriter()
      ..writeUint32(1)
      ..writeUint32(PsPatternColorMode.grayscale.code)
      ..writeInt16(1)
      ..writeInt16(1);
    _writeUnicodeString(writer, name);
    writer
      ..writeUint8(id.length)
      ..writeString(id)
      ..writeUint32(3)
      ..writeUint32(virtualMemoryBytes.length)
      ..writeBytes(virtualMemoryBytes);
    return writer.takeBytes();
  }

  /// Builds a `phry` block mapping a group and preset to [styleId].
  static AslTestTaggedBlock hierarchyBlock({
    String styleId = 'style-id',
    String signature = '8BIM',
  }) {
    const PsDescriptor group = PsDescriptor(
      name: '',
      classId: 'Grup',
      items: <PsDescriptorItem>[
        PsDescriptorItem(
          key: 'Nm  ',
          value: PsStringValue(value: 'Favorites'),
        ),
      ],
    );
    final PsDescriptor preset = PsDescriptor(
      name: '',
      classId: 'preset',
      items: <PsDescriptorItem>[
        const PsDescriptorItem(
          key: 'Nm  ',
          value: PsStringValue(value: 'Test style'),
        ),
        PsDescriptorItem(
          key: 'Idnt',
          value: PsStringValue(value: styleId),
        ),
      ],
    );
    const PsDescriptor end = PsDescriptor(name: '', classId: 'groupEnd');
    final PsDescriptor root = PsDescriptor(
      name: '',
      classId: 'null',
      items: <PsDescriptorItem>[
        PsDescriptorItem(
          key: 'hierarchy',
          value: PsListValue(
            values: <PsDescriptorValue>[
              const PsObjectValue(value: group),
              PsObjectValue(value: preset),
              const PsObjectValue(value: end),
            ],
          ),
        ),
      ],
    );
    final PsBinaryWriter payload = PsBinaryWriter()
      ..writeUint32(16)
      ..writeBytes(PsDescriptorCodec.encode(root));
    return AslTestTaggedBlock(
      signature: signature,
      key: 'phry',
      data: payload.takeBytes(),
    );
  }

  /// Writes a descriptor-style UTF-16 string without a terminal null.
  static void _writeUnicodeString(PsBinaryWriter writer, String value) {
    writer.writeUint32(value.codeUnits.length);
    value.codeUnits.forEach(writer.writeUint16);
  }
}

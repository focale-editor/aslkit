<p align="center">
  <img src="screenshots/overview.png" alt="AslKit package illustration" width="180">
</p>

# AslKit

AslKit is a pure Dart codec for Adobe Photoshop Layer Style (`.asl`) libraries. It decodes and writes standalone libraries, recognizes `Styles.psp` payloads, exposes complete Photoshop Action Descriptors, renders embedded pattern tiles through PsCore, and preserves bounded data that a newer Photoshop release may add.

The package is designed for editors such as Focale. Focale integration is intentionally outside this initial package change.

## Supported data

- Standalone version 2 files and unversioned `8BSL` style-palette payloads.
- Version 3 embedded-pattern sections with grayscale, indexed, RGB, CMYK, multichannel, duotone, Lab, and bitmap records.
- Raw and PackBits pattern channels at 1, 8, 16, or 32 bits where PsCore can decode them.
- Both version 16 descriptors in every style: identification (`Nm  ` and `Idnt`) and style information (`documentMode`, `Lefx`, and `blendOptions`).
- Single and multi-instance shadows, glows, bevel and emboss, Satin, color/gradient/pattern overlays, and strokes.
- Typed views for colors, gradients, contours, pattern references, offsets, effect geometry and lighting, bevel/glow/stroke settings, Blend If ranges, channel restrictions, and captured document mode.
- Optional `8BIM`/`8B64` tagged trailers and `phry` preset hierarchies.
- Strict and tolerant decoding with configurable file, record, descriptor, hierarchy, dimension, channel, and decoded-pixel limits.
- Strict canonical writing and permissive reconstruction of opaque records, extensions, and damaged-but-bounded input.

The complete `PsDescriptor` remains the source of truth. Typed views do not discard unfamiliar keys, nested objects, list values, raw data, or exact identifier encodings.

## Reading a file

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';

final Uint8List bytes = await File('cinematic.asl').readAsBytes();
final AslFile file = AslDecoder.decode(bytes);

for (final AslStyle style in file.decodedStyles) {
  print('${style.name}: ${style.layerEffects?.effects.length ?? 0} effects');
  for (final AslEffect effect in style.layerEffects?.effects ?? const []) {
    print('  ${effect.kind.name}: enabled=${effect.enabled}');
  }
}
```

`AslStyle.layerEffects`, `blendOptions`, and `documentMode` are convenient projections. Use `style.styleDescriptor` or `effect.descriptor` whenever an application needs fields that have no first-class convenience property.

Pattern-backed effects can be resolved without manually joining identifiers:

```dart
for (final AslPatternReference reference in style.patternReferences) {
  final PsPattern? pattern = file.patternFor(reference);
  final PsPatternImage? image = pattern?.canRenderRgba8 == true
      ? pattern!.renderRgba8()
      : null;
  print('${reference.name}: ${image?.width} x ${image?.height}');
}
```

CMYK pattern previews accept a caller-provided `PsCmykToRgbConverter`; without one, PsCore uses a deterministic profile-free conversion.

## Editing and writing

Decoded descriptor pairs are written semantically, so replacing a descriptor or identity never reuses stale source bytes:

```dart
final AslStyle original = file.decodedStyles.first;
final AslStyle renamed = original.withIdentity(name: 'Soft cinematic');
final AslFile edited = AslFile.editable(styles: [renamed]);

final Uint8List output = AslEncoder.encode(edited);
await File('edited.asl').writeAsBytes(output);
```

New styles can be authored from descriptors with `AslStyle.editable`. `PsDescriptor.withValue` provides an immutable way to replace or append one descriptor field.

Strict encoding requires canonical versions, descriptor classes, identification strings, valid style structure, and no opaque damage. Permissive encoding is intended for lossless reconstruction after tolerant decoding:

```dart
final Uint8List reconstructed = AslEncoder.encode(
  file,
  options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
);
```

Embedded pattern pixels are decoded semantically but currently written from their preserved binary record. Keep `preservePatternRecordData` enabled when an ASL file containing patterns must be saved again. Creating new pattern pixel records from raw images belongs in a future shared PsCore encoder.

## Reusable `dart:convert` API

`AslCodec` implements `Codec<AslFile, List<int>>` and keeps decoding and encoding policies together in one immutable value:

```dart
const AslCodec codec = AslCodec(
  decodeOptions: AslDecodeOptions(mode: AslDecodeMode.strict),
  encodeOptions: AslEncodeOptions(mode: AslEncodeMode.strict),
);

final AslFile file = codec.decode(bytes);
final Uint8List output = codec.encode(file);
```

The `List<int>` binary type allows composition with standard codecs such as `base64`; direct `encode` calls still return `Uint8List`. `AslEncoder` and `AslDecoder` are also configurable `Converter` implementations. Every conversion consumes or produces one complete in-memory ASL file rather than an incremental byte stream.

## Strict, tolerant, and bounded decoding

Tolerant decoding is the default. Because styles and patterns are length-bounded, a malformed record is retained as an opaque `AslStyle` or `AslPatternRecord` and decoding continues at the next reliable boundary. If an unknown Action Descriptor value type cannot be sized safely, only that style record becomes opaque.

Strict mode promotes the first compatibility issue to `AslFormatException`:

```dart
final AslFile file = AslDecoder.decode(
  bytes,
  options: const AslDecodeOptions(mode: AslDecodeMode.strict),
);
```

Preservation switches independently control record copies, channel payloads, tagged blocks, trailing data, and the complete source copy. Disable them for a memory-minimal preset browser; retain pattern records and tagged blocks when output reconstruction matters.

The bundled inspector accepts individual `.asl`/`Styles.psp` files or directories:

```console
dart run tool/inspect_asl.dart --strict --round-trip ASL_EXAMPLES
```

See [docs/ASL.md](docs/ASL.md) for the binary layout, descriptor mapping, recovery rules, encoding guarantees, and integration guidance.

## References

- [Adobe Photoshop File Formats Specification](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/)
- [Photoshop Styles File Format research](https://tonton-pixel.codeberg.page/photoshop-file-formats/styles-file-format.html)
- [Patchy Photoshop compatibility notes](https://github.com/SethRobinson/Patchy/blob/main/docs/ps-compat.md)

AslKit is an independent implementation and is not affiliated with or endorsed by Adobe.

---

Built for **[Focale](https://focale-editor.app)**, an advanced local image editor. Discover what these packages make possible in a real creative workflow.

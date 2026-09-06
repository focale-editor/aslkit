# Adobe Photoshop ASL support

This document records the container rules implemented by AslKit, the semantic views available to callers, and the boundaries of lossless reconstruction.

## Container layout

All multibyte numeric values are big-endian. A standalone `.asl` file has this envelope:

| Size | Meaning |
| ---: | --- |
| 2 | File version, normally `2` |
| 4 | Signature `8BSL` |
| 2 | Embedded-pattern section version, normally `3` |
| 4 | Byte length of the complete pattern section |
| variable | Zero or more length-prefixed, four-byte-aligned pattern records |
| 4 | Number of style records |
| variable | Length-prefixed, four-byte-aligned style records |
| variable | Optional Photoshop tagged blocks, commonly `8BIM` + `phry` |

A `Styles.psp` payload starts directly with `8BSL`; it has no leading file-version field. `AslContainerKind` records which envelope was detected, and the encoder preserves that choice.

An empty pattern section has length zero and contains no count field. A nonempty section is scanned until its declared byte boundary. Each record contains a 32-bit payload length, the shared Photoshop pattern body, and zero to three alignment bytes. `PsPatternRecordDecoder` in PsCore handles virtual-memory channel slots, indexed palettes, raw samples, and PackBits rows.

## Style records

Each style has a 32-bit byte length followed by two serialized Photoshop Action Descriptors:

1. A 32-bit descriptor version, normally `16`, and an identification descriptor of class `null`.
2. A second 32-bit descriptor version and a style-information descriptor of class `Styl`.

The identification descriptor normally stores:

| Key | Type | Meaning |
| --- | --- | --- |
| `Nm  ` | `TEXT` | Preset name |
| `Idnt` | `TEXT` | Stable identifier, conventionally a UUID |

Photoshop may serialize localized names as `$$$/resource/key=Display Name`. `serializedName` retains that exact value while `name` exposes the display suffix.

The style-information descriptor normally stores:

| Key | Type | Meaning |
| --- | --- | --- |
| `documentMode` | `Objc` | Captured color space and depth |
| `Lefx` | `Objc` | Scale, master switch, and layer effects |
| `blendOptions` | `Objc` | Optional layer opacity, mode, Fill, masks, restrictions, and Blend If |

AslKit never flattens these descriptors into a closed schema. `identificationDescriptor` and `styleDescriptor` retain item order, nested values, reference forms, compact or long identifiers, and supported opaque descriptor payloads. Convenience models point back to their complete source descriptors.

## Layer effects

`AslLayerEffects.effects` recognizes both the historical four-character keys and modern string identifiers. Object lists such as `dropShadowMulti`, `solidFillMulti`, `gradientFillMulti`, and `frameFXMulti` become multiple `AslEffect` instances without losing list order.

Recognized families are:

| Legacy key | Common string key | `AslEffectKind` |
| --- | --- | --- |
| `DrSh` | `dropShadow` | `dropShadow` |
| `IrSh` | `innerShadow` | `innerShadow` |
| `OrGl` | `outerGlow` | `outerGlow` |
| `IrGl` | `innerGlow` | `innerGlow` |
| `ebbl` | `bevelEmboss` | `bevelAndEmboss` |
| `ChFX` | `chromeFX` | `satin` |
| `SoFi` | `solidFill` | `colorOverlay` |
| `GrFl` | `gradientFill` | `gradientOverlay` |
| `patternFill` | `patternFill` | `patternOverlay` |
| `FrFX` | `frameFX` | `stroke` |

Every effect exposes typed access to its common geometry, opacity, lighting, contour, color, gradient, pattern, bevel, glow, and stroke settings. Effect-specific or future fields remain available through `number`, `boolean`, `enumeration`, `object`, or the underlying descriptor. This covers Photoshop additions without forcing them through a lossy enum.

### Colors and gradients

`AslColor` recognizes RGB, CMYK, grayscale, HSB, Lab, and color-book objects. Numeric components keep their original unit when present. The model deliberately does not color-manage descriptor colors; Focale can apply its document/profile pipeline rather than accepting an implicit conversion.

`AslGradient` retains both custom-stop and color-noise forms. Custom gradients expose color and transparency stops with their 0–4096 locations and midpoints. Noise gradients expose their seed, smoothness, color-space enumeration, switches, and minimum/maximum channel lists.

### Patterns

Pattern references contain a display name and identifier. `AslFile.patternFor` resolves the identifier against successfully decoded records in the embedded-pattern section. Duplicate identifiers are reported and the last source record wins, matching the package's direct lookup behavior.

### Blending options

`AslBlendOptions` exposes master opacity, blend mode, Fill opacity, grouped-clipping/interior switches, knockout, mask behavior, Blend If records, and channel restrictions. Each `AslBlendRange` retains the complete descriptor and the four split thresholds for both the source and underlying layers.

## Tagged blocks and hierarchy

After the declared styles, AslKit accepts ordinary `8BIM` blocks and forward-compatible `8B64` blocks with a 64-bit payload length. Unknown keys and optional alignment bytes are retained.

A `phry` payload begins with descriptor version `16`. When its root contains a `hierarchy` list, AslKit recognizes group starts, group ends, presets, empty slots, and unknown classes. Presets are matched to styles by identifier first and by source order as a fallback. The root descriptor remains available even when a caller ignores the typed hierarchy.

## Recovery and security

The decoder validates all reads against their bounded region before allocating or iterating. Configurable limits cover:

- total file, pattern section, individual pattern, style, and tagged-block sizes;
- counts of patterns, styles, tagged blocks, hierarchy entries, descriptor values, and descriptor nesting depth;
- pattern dimensions, virtual-memory channels, name length, and aggregate decoded pixel bytes.

Safety-limit violations always fail. In tolerant mode, format deviations become `AslWarning` values carrying byte, pattern, style, and tagged-block context.

Pattern and style outer lengths provide recovery boundaries. A damaged record can therefore remain opaque while later records are decoded. If the pattern section itself loses synchronization, its remaining bytes are preserved and style decoding resumes at the section boundary. A truncated core header or a pattern-section length extending beyond the file has no safe recovery boundary and throws `AslFormatException` in every mode.

Photoshop Action Descriptor values have no universal unknown-type length. When PsCore encounters an unsupported value type, AslKit preserves the complete bounded style record rather than guessing a length and corrupting subsequent parsing.

## Encoding guarantees

Strict encoding produces the canonical version-2/version-3 envelope, version-16 descriptor pairs, aligned style records, and matching style counts. It rejects opaque records, unknown versions, invalid descriptor classes, missing identification strings, unrecognized trailing bytes, and inconsistent tagged-block lengths.

Permissive encoding reconstructs preserved record payloads, declared counts and lengths, padding, tagged blocks, and trailing bytes. Decoded styles are always re-encoded from their descriptors; raw style bytes never override an intentional descriptor edit. Valid decoded files are expected to reconstruct byte for byte because PsCore retains descriptor identifier encodings and item order.

Pattern records do not yet have a semantic pixel writer. They are written from `AslPatternRecord.data` or `PsPattern.recordData`, so `preservePatternRecordData` must remain enabled for round trips involving patterns. This restriction does not affect decoding, preview rendering, descriptor editing, or pattern-reference resolution.

## Focale integration notes

No Focale files are modified by this package. A future integration can:

1. decode in tolerant mode with application-appropriate resource limits;
2. show `decodedStyles` and warnings while keeping opaque entries available for export;
3. render each resolvable `PsPattern` once and cache it by identifier;
4. translate `AslEffect.descriptor` into Focale's effect engine, using typed views for common fields and retaining the descriptor for unsupported settings;
5. apply document color management to CMYK, Lab, and color-book colors;
6. save edited descriptors with strict encoding, or use permissive mode only for forensic reconstruction.

## References

- [Adobe Photoshop File Formats Specification](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/), especially Action Descriptors, object-based layer effects, and pattern data.
- [Photoshop Styles File Format research](https://tonton-pixel.codeberg.page/photoshop-file-formats/styles-file-format.html), including the standalone envelope and effect descriptor keys.
- [Patchy Photoshop compatibility notes](https://github.com/SethRobinson/Patchy/blob/main/docs/ps-compat.md), including modern ASL captures, multi-instance effects, and Blend If behavior.

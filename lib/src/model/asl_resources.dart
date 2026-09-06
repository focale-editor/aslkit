import 'dart:typed_data';

import 'package:aslkit/src/model/asl_descriptor.dart';
import 'package:pscore/pscore.dart';

/// Identifies the color representation used by a layer-style descriptor.
enum AslColorSpace {
  /// Red, green, and blue components in the Photoshop 0–255 range.
  rgb,

  /// Cyan, magenta, yellow, and black components in percent.
  cmyk,

  /// A single grayscale component in percent.
  grayscale,

  /// Hue, saturation, and brightness components.
  hsb,

  /// CIE L*a*b* components.
  lab,

  /// A named color from a Photoshop color book.
  book,

  /// A descriptor class not recognized by this release.
  unknown,
}

/// Identifies a Photoshop gradient-generation strategy.
enum AslGradientForm {
  /// Explicit color and transparency stops.
  customStops,

  /// Deterministic color-noise parameters.
  colorNoise,

  /// A form identifier not recognized by this release.
  unknown,
}

/// An exact color descriptor with convenient named components.
final class AslColor {
  /// Known interpretation of the Photoshop descriptor class.
  final AslColorSpace colorSpace;

  /// Photoshop descriptor class exactly as stored.
  final String classId;

  /// Numeric components keyed by their Photoshop identifiers.
  final Map<String, AslNumber> components;

  /// Color-book name, when [colorSpace] is [AslColorSpace.book].
  final String? bookName;

  /// Named color within a color book, when available.
  final String? colorName;

  /// Numeric Photoshop color-book identifier, when available.
  final int? bookId;

  /// Opaque color-book lookup key, when available.
  final Uint8List? bookKey;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable color view.
  AslColor({
    required this.colorSpace,
    required this.classId,
    required Map<String, AslNumber> components,
    required this.bookName,
    required this.colorName,
    required this.bookId,
    required Uint8List? bookKey,
    required this.descriptor,
  }) : components = Map<String, AslNumber>.unmodifiable(components),
       bookKey = bookKey == null ? null : Uint8List.fromList(bookKey).asUnmodifiableView();

  /// Creates a typed view over a Photoshop color [descriptor].
  factory AslColor.fromDescriptor(PsDescriptor descriptor) {
    final List<String> componentKeys = switch (descriptor.classId) {
      'RGBC' || 'RGBColor' => const <String>['Rd  ', 'Grn ', 'Bl  ', 'red', 'green', 'blue'],
      'CMYC' || 'CMYKColor' => const <String>['Cyn ', 'Mgnt', 'Ylw ', 'Blck', 'cyan', 'magenta', 'yellowColor', 'black'],
      'Grsc' || 'grayscale' => const <String>['Gry ', 'gray'],
      'HSBC' || 'HSBColor' => const <String>['H   ', 'Strt', 'Brgh', 'hue', 'saturation', 'brightness'],
      'LbCl' || 'labColor' => const <String>['Lmnc', 'A   ', 'B   ', 'luminance', 'a', 'b'],
      _ => const <String>[],
    };
    final Map<String, AslNumber> components = <String, AslNumber>{};
    for (final String key in componentKeys) {
      final AslNumber? number = descriptor.aslNumber(key);
      if (number != null) {
        components[key] = number;
      }
    }
    final PsDescriptorValue? rawBookKey = descriptor.value('bookKey');
    final Uint8List? bookKey = switch (rawBookKey) {
      PsRawValue(:final Uint8List value) => value,
      _ => null,
    };
    return AslColor(
      colorSpace: _colorSpaceFor(descriptor.classId),
      classId: descriptor.classId,
      components: components,
      bookName: descriptor.aslString('Bk  '),
      colorName: descriptor.aslString('Nm  '),
      bookId: descriptor.aslInteger('bookID'),
      bookKey: bookKey,
      descriptor: descriptor,
    );
  }

  /// Returns the numeric component stored under [key].
  AslNumber? component(String key) => components[key];

  /// Maps a Photoshop color descriptor [classId] to a known color space.
  static AslColorSpace _colorSpaceFor(String classId) => switch (classId) {
    'RGBC' || 'RGBColor' => AslColorSpace.rgb,
    'CMYC' || 'CMYKColor' => AslColorSpace.cmyk,
    'Grsc' || 'grayscale' => AslColorSpace.grayscale,
    'HSBC' || 'HSBColor' => AslColorSpace.hsb,
    'LbCl' || 'labColor' => AslColorSpace.lab,
    'BkCl' || 'bookColor' => AslColorSpace.book,
    _ => AslColorSpace.unknown,
  };
}

/// One color stop in a custom Photoshop gradient.
final class AslGradientColorStop {
  /// Stop position in Photoshop's 0–4096 gradient coordinate range.
  final int? location;

  /// Transition midpoint in percent.
  final int? midpoint;

  /// Photoshop stop-kind enumeration, such as `UsrS` or `FrgC`.
  final AslEnumeration? kind;

  /// Explicit stop color, when the stop is not dynamically sourced.
  final AslColor? color;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable gradient color stop.
  const AslGradientColorStop({
    required this.location,
    required this.midpoint,
    required this.kind,
    required this.color,
    required this.descriptor,
  });

  /// Creates a typed view over a Photoshop color-stop [descriptor].
  factory AslGradientColorStop.fromDescriptor(PsDescriptor descriptor) {
    final PsDescriptor? color = descriptor.aslObject('Clr ');
    return AslGradientColorStop(
      location: descriptor.aslInteger('Lctn'),
      midpoint: descriptor.aslInteger('Mdpn'),
      kind: descriptor.aslEnumeration('Type'),
      color: color == null ? null : AslColor.fromDescriptor(color),
      descriptor: descriptor,
    );
  }
}

/// One opacity stop in a custom Photoshop gradient.
final class AslGradientTransparencyStop {
  /// Stop position in Photoshop's 0–4096 gradient coordinate range.
  final int? location;

  /// Transition midpoint in percent.
  final int? midpoint;

  /// Stop opacity, normally expressed with the `#Prc` unit.
  final AslNumber? opacity;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable gradient transparency stop.
  const AslGradientTransparencyStop({
    required this.location,
    required this.midpoint,
    required this.opacity,
    required this.descriptor,
  });

  /// Creates a typed view over a Photoshop transparency-stop [descriptor].
  factory AslGradientTransparencyStop.fromDescriptor(PsDescriptor descriptor) => AslGradientTransparencyStop(
    location: descriptor.aslInteger('Lctn'),
    midpoint: descriptor.aslInteger('Mdpn'),
    opacity: descriptor.aslNumber('Opct'),
    descriptor: descriptor,
  );
}

/// A Photoshop gradient descriptor preserving both stop and noise forms.
final class AslGradient {
  /// Preset name stored by Photoshop, when present.
  final String? name;

  /// Known interpretation of [formIdentifier].
  final AslGradientForm form;

  /// Exact gradient-form enumeration identifier.
  final String? formIdentifier;

  /// Interpolation smoothness in Photoshop's 0–4096 range.
  final double? smoothness;

  /// Explicit color stops in source order.
  final List<AslGradientColorStop> colorStops;

  /// Explicit transparency stops in source order.
  final List<AslGradientTransparencyStop> transparencyStops;

  /// Noise-gradient random seed, when present.
  final int? randomSeed;

  /// Whether a noise gradient generates transparency.
  final bool? showsTransparency;

  /// Whether a noise gradient restricts generated colors.
  final bool? restrictsColors;

  /// Noise-gradient color-space enumeration, when present.
  final AslEnumeration? colorSpace;

  /// Four noise-gradient minimum channel values, when present.
  final List<int> minimumValues;

  /// Four noise-gradient maximum channel values, when present.
  final List<int> maximumValues;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable gradient view.
  AslGradient({
    required this.name,
    required this.form,
    required this.formIdentifier,
    required this.smoothness,
    required List<AslGradientColorStop> colorStops,
    required List<AslGradientTransparencyStop> transparencyStops,
    required this.randomSeed,
    required this.showsTransparency,
    required this.restrictsColors,
    required this.colorSpace,
    required List<int> minimumValues,
    required List<int> maximumValues,
    required this.descriptor,
  }) : colorStops = List<AslGradientColorStop>.unmodifiable(colorStops),
       transparencyStops = List<AslGradientTransparencyStop>.unmodifiable(transparencyStops),
       minimumValues = List<int>.unmodifiable(minimumValues),
       maximumValues = List<int>.unmodifiable(maximumValues);

  /// Creates a typed view over a Photoshop gradient [descriptor].
  factory AslGradient.fromDescriptor(PsDescriptor descriptor) {
    final AslEnumeration? form = descriptor.aslEnumeration('GrdF');
    return AslGradient(
      name: descriptor.aslString('Nm  '),
      form: switch (form?.value) {
        'CstS' || 'customStops' => AslGradientForm.customStops,
        'ClNs' || 'colorNoise' => AslGradientForm.colorNoise,
        _ => AslGradientForm.unknown,
      },
      formIdentifier: form?.value,
      smoothness: descriptor.aslNumber('Intr')?.value ?? descriptor.aslNumber('Smth')?.value,
      colorStops: _colorStops(descriptor.aslList('Clrs')),
      transparencyStops: _transparencyStops(descriptor.aslList('Trns')),
      randomSeed: descriptor.aslInteger('RndS'),
      showsTransparency: descriptor.aslBoolean('ShTr'),
      restrictsColors: descriptor.aslBoolean('VctC'),
      colorSpace: descriptor.aslEnumeration('ClrS'),
      minimumValues: _integers(descriptor.aslList('Mnm ')),
      maximumValues: _integers(descriptor.aslList('Mxm ')),
      descriptor: descriptor,
    );
  }

  /// Converts object values in [values] into color stops.
  static List<AslGradientColorStop> _colorStops(List<PsDescriptorValue>? values) => <AslGradientColorStop>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsObjectValue(:final PsDescriptor value)) AslGradientColorStop.fromDescriptor(value),
  ];

  /// Converts object values in [values] into transparency stops.
  static List<AslGradientTransparencyStop> _transparencyStops(List<PsDescriptorValue>? values) => <AslGradientTransparencyStop>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsObjectValue(:final PsDescriptor value)) AslGradientTransparencyStop.fromDescriptor(value),
  ];

  /// Extracts every integer value from an optional descriptor list.
  static List<int> _integers(List<PsDescriptorValue>? values) => <int>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsIntegerValue(:final int value)) value else if (value case PsLargeIntegerValue(:final int value)) value,
  ];
}

/// One point in a Photoshop shaping or gloss contour.
final class AslCurvePoint {
  /// Horizontal contour coordinate.
  final AslNumber? horizontal;

  /// Vertical contour coordinate.
  final AslNumber? vertical;

  /// Whether Photoshop joins this point continuously to its neighbors.
  final bool? continuous;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable contour-point view.
  const AslCurvePoint({
    required this.horizontal,
    required this.vertical,
    required this.continuous,
    required this.descriptor,
  });

  /// Creates a typed view over one contour-point [descriptor].
  factory AslCurvePoint.fromDescriptor(PsDescriptor descriptor) => AslCurvePoint(
    horizontal: descriptor.aslNumber('Hrzn'),
    vertical: descriptor.aslNumber('Vrtc'),
    continuous: descriptor.aslBoolean('Cnty'),
    descriptor: descriptor,
  );
}

/// A Photoshop shaping curve used by contours and Satin mappings.
final class AslContour {
  /// Human-readable contour name, when stored.
  final String? name;

  /// Curve points in source order.
  final List<AslCurvePoint> points;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable contour view.
  AslContour({
    required this.name,
    required List<AslCurvePoint> points,
    required this.descriptor,
  }) : points = List<AslCurvePoint>.unmodifiable(points);

  /// Creates a typed view over a Photoshop contour [descriptor].
  factory AslContour.fromDescriptor(PsDescriptor descriptor) => AslContour(
    name: descriptor.aslString('Nm  '),
    points: _points(descriptor.aslList('Crv ')),
    descriptor: descriptor,
  );

  /// Converts object values in [values] into contour points.
  static List<AslCurvePoint> _points(List<PsDescriptorValue>? values) => <AslCurvePoint>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsObjectValue(:final PsDescriptor value)) AslCurvePoint.fromDescriptor(value),
  ];
}

/// A name and stable identifier referring to an embedded Photoshop pattern.
final class AslPatternReference {
  /// User-visible pattern name, when stored.
  final String? name;

  /// Pattern identifier used to resolve embedded pixel data.
  final String? id;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable pattern reference.
  const AslPatternReference({
    required this.name,
    required this.id,
    required this.descriptor,
  });

  /// Creates a typed view over a Photoshop pattern [descriptor].
  factory AslPatternReference.fromDescriptor(PsDescriptor descriptor) => AslPatternReference(
    name: descriptor.aslString('Nm  '),
    id: descriptor.aslString('Idnt') ?? descriptor.aslString('identifier'),
    descriptor: descriptor,
  );
}

/// A two-dimensional descriptor point used by layer-style offsets and phases.
final class AslPoint {
  /// Horizontal coordinate with its optional Photoshop unit.
  final AslNumber? horizontal;

  /// Vertical coordinate with its optional Photoshop unit.
  final AslNumber? vertical;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable point view.
  const AslPoint({
    required this.horizontal,
    required this.vertical,
    required this.descriptor,
  });

  /// Creates a typed view over a Photoshop point [descriptor].
  factory AslPoint.fromDescriptor(PsDescriptor descriptor) => AslPoint(
    horizontal: descriptor.aslNumber('Hrzn'),
    vertical: descriptor.aslNumber('Vrtc'),
    descriptor: descriptor,
  );
}

/// The document color space and bit depth captured with a layer-style preset.
final class AslDocumentMode {
  /// Color-space enumeration stored under `ClrS`, when present.
  final AslEnumeration? colorSpace;

  /// Captured bits per channel, when present.
  final int? depth;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable document-mode view.
  const AslDocumentMode({
    required this.colorSpace,
    required this.depth,
    required this.descriptor,
  });

  /// Creates a typed view over a Photoshop document-mode [descriptor].
  factory AslDocumentMode.fromDescriptor(PsDescriptor descriptor) => AslDocumentMode(
    colorSpace: descriptor.aslEnumeration('ClrS'),
    depth: descriptor.aslInteger('Dpth'),
    descriptor: descriptor,
  );
}

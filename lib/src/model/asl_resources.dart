import 'package:aslkit/src/model/asl_descriptor.dart';
import 'package:pscore/pscore.dart';

/// Backward-compatible name for the shared color-space enumeration.
typedef AslColorSpace = PsColorSpace;

/// Backward-compatible name for the shared gradient-form enumeration.
typedef AslGradientForm = PsGradientForm;

/// Backward-compatible name for a shared color descriptor view.
typedef AslColor = PsColor;

/// Backward-compatible name for a shared gradient color stop.
typedef AslGradientColorStop = PsGradientColorStop;

/// Backward-compatible name for a shared gradient transparency stop.
typedef AslGradientTransparencyStop = PsGradientTransparencyStop;

/// Backward-compatible name for a shared gradient descriptor view.
typedef AslGradient = PsGradient;

/// Backward-compatible name for a shared contour point.
typedef AslCurvePoint = PsContourPoint;

/// Backward-compatible name for a shared contour descriptor view.
typedef AslContour = PsContour;

/// Backward-compatible name for a shared pattern reference.
typedef AslPatternReference = PsPatternReference;

/// Backward-compatible name for a shared two-dimensional point.
typedef AslPoint = PsPoint;

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

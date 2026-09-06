import 'dart:typed_data';

import 'package:aslkit/src/model/asl_descriptor.dart';
import 'package:aslkit/src/model/asl_effect.dart';
import 'package:aslkit/src/model/asl_resources.dart';
import 'package:pscore/pscore.dart';

/// One length-bounded Photoshop layer-style preset.
final class AslStyle {
  /// Zero-based source position among declared style records.
  final int index;

  /// Absolute offset of the record-length field.
  final int sourceOffset;

  /// Payload length declared before this record.
  final int declaredLength;

  /// Version preceding the identification descriptor, normally 16.
  final int? identificationDescriptorVersion;

  /// Descriptor containing the preset name and stable identifier.
  final PsDescriptor? identificationDescriptor;

  /// Version preceding the style-information descriptor, normally 16.
  final int? styleDescriptorVersion;

  /// Descriptor containing document mode, layer effects, and blending options.
  final PsDescriptor? styleDescriptor;

  /// Name exactly as stored in `TEXT`, including a ZString prefix or terminal null.
  final String? serializedName;

  /// User-visible name with a Photoshop ZString resolved when possible.
  final String? name;

  /// Stable style identifier, conventionally a UUID string.
  final String? id;

  /// Captured document-mode settings, when present and object-shaped.
  final AslDocumentMode? documentMode;

  /// Layer effects stored under `Lefx`, when present and object-shaped.
  final AslLayerEffects? layerEffects;

  /// Optional layer blending settings stored with the preset.
  final AslBlendOptions? blendOptions;

  /// Bytes remaining after both decoded descriptors inside the record.
  final Uint8List recordTrailingData;

  /// Bytes outside the declared payload used to align the next style record.
  final Uint8List paddingData;

  /// Exact record payload, or `null` when preservation was disabled.
  final Uint8List? recordData;

  /// Explanation retained for an opaque record that could not be decoded.
  final String? decodeError;

  /// Creates an immutable style record.
  AslStyle({
    required this.index,
    required this.sourceOffset,
    required this.declaredLength,
    required this.identificationDescriptorVersion,
    required this.identificationDescriptor,
    required this.styleDescriptorVersion,
    required this.styleDescriptor,
    required this.serializedName,
    required this.name,
    required this.id,
    required this.documentMode,
    required this.layerEffects,
    required this.blendOptions,
    required Uint8List recordTrailingData,
    required Uint8List paddingData,
    required Uint8List? recordData,
    required this.decodeError,
  }) : recordTrailingData = Uint8List.fromList(recordTrailingData).asUnmodifiableView(),
       paddingData = Uint8List.fromList(paddingData).asUnmodifiableView(),
       recordData = recordData == null ? null : Uint8List.fromList(recordData).asUnmodifiableView();

  /// Creates a new editable style from complete descriptor objects.
  factory AslStyle.editable({
    required String name,
    required String id,
    required PsDescriptor layerEffects,
    PsDescriptor? documentMode,
    PsDescriptor? blendOptions,
    int index = 0,
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
    final List<PsDescriptorItem> items = <PsDescriptorItem>[
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
    ];
    return AslStyle(
      index: index,
      sourceOffset: 0,
      declaredLength: 0,
      identificationDescriptorVersion: 16,
      identificationDescriptor: identity,
      styleDescriptorVersion: 16,
      styleDescriptor: PsDescriptor(name: '', classId: 'Styl', items: items),
      serializedName: name,
      name: name,
      id: id,
      documentMode: AslDocumentMode.fromDescriptor(mode),
      layerEffects: AslLayerEffects.fromDescriptor(layerEffects),
      blendOptions: blendOptions == null ? null : AslBlendOptions.fromDescriptor(blendOptions),
      recordTrailingData: Uint8List(0),
      paddingData: Uint8List(0),
      recordData: null,
      decodeError: null,
    );
  }

  /// Whether both versioned Action Descriptors were decoded.
  bool get isDecoded => identificationDescriptor != null && styleDescriptor != null;

  /// Whether the style contains either layer effects or blending options.
  bool get hasUsableStyleData => layerEffects != null || blendOptions != null;

  /// Every pattern reference used by layer-effect instances.
  List<AslPatternReference> get patternReferences => List<AslPatternReference>.unmodifiable(<AslPatternReference>[
    for (final AslEffect effect in layerEffects?.effects ?? const <AslEffect>[])
      if (effect.pattern case final AslPatternReference pattern) pattern,
  ]);

  /// Returns a copy with an updated name and identifier descriptor.
  AslStyle withIdentity({
    String? name,
    String? id,
  }) {
    final PsDescriptor? sourceIdentity = identificationDescriptor;
    if (sourceIdentity == null) {
      throw StateError('An opaque ASL style has no identification descriptor to edit');
    }
    final String nextName = name ?? serializedName ?? this.name ?? '';
    final String nextId = id ?? this.id ?? '';
    final PsDescriptor identity = sourceIdentity.withValue('Nm  ', PsStringValue(value: nextName)).withValue('Idnt', PsStringValue(value: nextId));
    return AslStyle(
      index: index,
      sourceOffset: sourceOffset,
      declaredLength: declaredLength,
      identificationDescriptorVersion: identificationDescriptorVersion,
      identificationDescriptor: identity,
      styleDescriptorVersion: styleDescriptorVersion,
      styleDescriptor: styleDescriptor,
      serializedName: nextName,
      name: _resolveZString(_trimTerminalNulls(nextName)),
      id: nextId,
      documentMode: documentMode,
      layerEffects: layerEffects,
      blendOptions: blendOptions,
      recordTrailingData: recordTrailingData,
      paddingData: paddingData,
      recordData: null,
      decodeError: null,
    );
  }

  /// Returns a copy backed by a replacement style-information [descriptor].
  AslStyle withStyleDescriptor(PsDescriptor descriptor) {
    final PsDescriptor? mode = descriptor.aslObject('documentMode');
    final PsDescriptor? effects = descriptor.aslObject('Lefx');
    final PsDescriptor? blending = descriptor.aslObject('blendOptions');
    return AslStyle(
      index: index,
      sourceOffset: sourceOffset,
      declaredLength: declaredLength,
      identificationDescriptorVersion: identificationDescriptorVersion,
      identificationDescriptor: identificationDescriptor,
      styleDescriptorVersion: styleDescriptorVersion,
      styleDescriptor: descriptor,
      serializedName: serializedName,
      name: name,
      id: id,
      documentMode: mode == null ? null : AslDocumentMode.fromDescriptor(mode),
      layerEffects: effects == null ? null : AslLayerEffects.fromDescriptor(effects),
      blendOptions: blending == null ? null : AslBlendOptions.fromDescriptor(blending),
      recordTrailingData: recordTrailingData,
      paddingData: paddingData,
      recordData: null,
      decodeError: null,
    );
  }

  /// Resolves Photoshop's `$$$/key=Display Name` localization form.
  static String _resolveZString(String value) {
    if (!value.startsWith(r'$$$/')) {
      return value;
    }
    final int equals = value.indexOf('=');
    if (equals >= 0 && equals + 1 < value.length) {
      return value.substring(equals + 1);
    }
    final int slash = value.lastIndexOf('/');
    return slash < 0 || slash + 1 >= value.length ? value : value.substring(slash + 1);
  }

  /// Removes only terminal null characters from [value].
  static String _trimTerminalNulls(String value) {
    int end = value.length;
    while (end > 0 && value.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return value.substring(0, end);
  }
}

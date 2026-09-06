import 'package:aslkit/src/model/asl_descriptor.dart';
import 'package:aslkit/src/model/asl_resources.dart';
import 'package:pscore/pscore.dart';

/// Identifies a recognized Photoshop layer-effect family.
enum AslEffectKind {
  /// A shadow cast outside the layer silhouette.
  dropShadow,

  /// A shadow composited inside the layer silhouette.
  innerShadow,

  /// A glow composited outside the layer silhouette.
  outerGlow,

  /// A glow composited inside the layer silhouette.
  innerGlow,

  /// Bevel, emboss, contour, and texture settings.
  bevelAndEmboss,

  /// Photoshop's Satin effect, historically named Chrome FX.
  satin,

  /// A solid-color overlay.
  colorOverlay,

  /// A gradient overlay.
  gradientOverlay,

  /// A pattern overlay.
  patternOverlay,

  /// A stroke whose paint may be solid, gradient, or patterned.
  stroke,

  /// A forward-compatible effect key not recognized by this release.
  unknown,
}

/// One layer-effect instance extracted without discarding descriptor fields.
final class AslEffect {
  /// Key used by the parent `Lefx` descriptor.
  final String key;

  /// Zero-based instance position for an effect family.
  final int instanceIndex;

  /// Known semantic effect family.
  final AslEffectKind kind;

  /// Complete effect descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable effect view.
  const AslEffect({
    required this.key,
    required this.instanceIndex,
    required this.kind,
    required this.descriptor,
  });

  /// Whether Photoshop marks this effect as enabled.
  bool? get enabled => descriptor.aslBoolean('enab');

  /// Whether Photoshop records this effect as present in the dialog.
  bool? get present => descriptor.aslBoolean('present');

  /// Whether Photoshop records this effect as visible in the style dialog.
  bool? get shownInDialog => descriptor.aslBoolean('showInDialog');

  /// Effect blend mode stored under `Md  `, when applicable.
  AslEnumeration? get blendMode => descriptor.aslEnumeration('Md  ');

  /// Effect opacity stored under `Opct`, when applicable.
  AslNumber? get opacity => descriptor.aslNumber('Opct');

  /// Effect scale stored under `Scl `, when applicable.
  AslNumber? get scale => descriptor.aslNumber('Scl ');

  /// Primary angle stored under `Angl` or legacy local-light key `lagl`.
  AslNumber? get angle => descriptor.aslNumber('Angl') ?? descriptor.aslNumber('lagl');

  /// Whether the effect uses the document's global lighting angle.
  bool? get usesGlobalAngle => descriptor.aslBoolean('uglg');

  /// Lighting altitude stored under `Lald`, when applicable.
  AslNumber? get altitude => descriptor.aslNumber('Lald');

  /// Effect distance stored under `Dstn`, when applicable.
  AslNumber? get distance => descriptor.aslNumber('Dstn');

  /// Visual size stored as `blur` or stroke-specific `Sz  `.
  AslNumber? get size => descriptor.aslNumber('blur') ?? descriptor.aslNumber('Sz  ');

  /// Shadow or glow choke/spread stored under `Ckmt`.
  AslNumber? get chokeOrSpread => descriptor.aslNumber('Ckmt');

  /// Effect noise stored under `Nose`, when applicable.
  AslNumber? get noise => descriptor.aslNumber('Nose');

  /// Glow jitter stored under `ShdN`, when applicable.
  AslNumber? get jitter => descriptor.aslNumber('ShdN');

  /// Contour input range stored under `Inpr`, when applicable.
  AslNumber? get inputRange => descriptor.aslNumber('Inpr');

  /// Bevel depth stored under `srgR`, when applicable.
  AslNumber? get depth => descriptor.aslNumber('srgR');

  /// Bevel softness stored under `Sftn`, when applicable.
  AslNumber? get softness => descriptor.aslNumber('Sftn');

  /// Bevel texture depth stored under `textureDepth`, when applicable.
  AslNumber? get textureDepth => descriptor.aslNumber('textureDepth');

  /// Whether the primary contour is anti-aliased.
  bool? get antiAliased => descriptor.aslBoolean('AntA');

  /// Whether the bevel gloss contour is anti-aliased.
  bool? get glossAntiAliased => descriptor.aslBoolean('antialiasGloss');

  /// Whether the source layer knocks out an outer shadow.
  bool? get layerConceals => descriptor.aslBoolean('layerConceals');

  /// Whether Satin reverses its tonal mapping.
  bool? get inverted => descriptor.aslBoolean('Invr');

  /// Whether a gradient direction is reversed.
  bool? get reversed => descriptor.aslBoolean('Rvrs');

  /// Whether a gradient or pattern is aligned with the layer.
  bool? get aligned => descriptor.aslBoolean('Algn');

  /// Whether a stroke pattern is linked with the layer.
  bool? get linked => descriptor.aslBoolean('Lnkd');

  /// Whether gradient dithering is enabled.
  bool? get dithered => descriptor.aslBoolean('Dthr');

  /// Whether Bevel and Emboss applies its contour sub-effect.
  bool? get usesShape => descriptor.aslBoolean('useShape');

  /// Whether Bevel and Emboss applies its texture sub-effect.
  bool? get usesTexture => descriptor.aslBoolean('useTexture');

  /// Whether a bevel texture is inverted.
  bool? get textureInverted => descriptor.aslBoolean('InvT');

  /// Glow technique stored under `GlwT`, when applicable.
  AslEnumeration? get glowTechnique => descriptor.aslEnumeration('GlwT');

  /// Inner-glow source stored under `glwS`, when applicable.
  AslEnumeration? get innerGlowSource => descriptor.aslEnumeration('glwS');

  /// Bevel technique stored under `bvlT`, when applicable.
  AslEnumeration? get bevelTechnique => descriptor.aslEnumeration('bvlT');

  /// Bevel style stored under `bvlS`, when applicable.
  AslEnumeration? get bevelStyle => descriptor.aslEnumeration('bvlS');

  /// Bevel direction stored under `bvlD`, when applicable.
  AslEnumeration? get bevelDirection => descriptor.aslEnumeration('bvlD');

  /// Gradient geometry stored under `Type`, when applicable.
  AslEnumeration? get gradientType => descriptor.aslEnumeration('Type');

  /// Stroke position stored under `Styl`, when applicable.
  AslEnumeration? get strokePosition => descriptor.aslEnumeration('Styl');

  /// Stroke paint source stored under `PntT`, when applicable.
  AslEnumeration? get strokePaintType => descriptor.aslEnumeration('PntT');

  /// Bevel highlight blend mode stored under `hglM`.
  AslEnumeration? get highlightBlendMode => descriptor.aslEnumeration('hglM');

  /// Bevel highlight opacity stored under `hglO`.
  AslNumber? get highlightOpacity => descriptor.aslNumber('hglO');

  /// Bevel shadow blend mode stored under `sdwM`.
  AslEnumeration? get shadowBlendMode => descriptor.aslEnumeration('sdwM');

  /// Bevel shadow opacity stored under `sdwO`.
  AslNumber? get shadowOpacity => descriptor.aslNumber('sdwO');

  /// Primary color stored under `Clr `, when applicable.
  AslColor? get color => colorAt('Clr ');

  /// Bevel highlight color stored under `hglC`, when applicable.
  AslColor? get highlightColor => colorAt('hglC');

  /// Bevel shadow color stored under `sdwC`, when applicable.
  AslColor? get shadowColor => colorAt('sdwC');

  /// Gradient definition stored under `Grad`, when applicable.
  AslGradient? get gradient {
    final PsDescriptor? value = descriptor.aslObject('Grad');
    return value == null ? null : AslGradient.fromDescriptor(value);
  }

  /// Pattern reference stored under `Ptrn`, when applicable.
  AslPatternReference? get pattern {
    final PsDescriptor? value = descriptor.aslObject('Ptrn');
    return value == null ? null : AslPatternReference.fromDescriptor(value);
  }

  /// Pattern or gradient phase stored under `phase`, when applicable.
  AslPoint? get phase {
    final PsDescriptor? value = descriptor.aslObject('phase');
    return value == null ? null : AslPoint.fromDescriptor(value);
  }

  /// Gradient offset stored under `Ofst`, when applicable.
  AslPoint? get offset {
    final PsDescriptor? value = descriptor.aslObject('Ofst');
    return value == null ? null : AslPoint.fromDescriptor(value);
  }

  /// Transparency or gloss contour stored under `TrnS`, when applicable.
  AslContour? get transparencyContour => contourAt('TrnS');

  /// Mapping contour stored under `MpgS`, when applicable.
  AslContour? get mappingContour => contourAt('MpgS');

  /// Returns any numeric parameter stored under [key].
  AslNumber? number(String key) => descriptor.aslNumber(key);

  /// Returns any Boolean parameter stored under [key].
  bool? boolean(String key) => descriptor.aslBoolean(key);

  /// Returns any enumeration parameter stored under [key].
  AslEnumeration? enumeration(String key) => descriptor.aslEnumeration(key);

  /// Returns any nested descriptor stored under [key].
  PsDescriptor? object(String key) => descriptor.aslObject(key);

  /// Returns a color object stored under [key].
  AslColor? colorAt(String key) {
    final PsDescriptor? value = descriptor.aslObject(key);
    return value == null ? null : AslColor.fromDescriptor(value);
  }

  /// Returns a contour object stored under [key].
  AslContour? contourAt(String key) {
    final PsDescriptor? value = descriptor.aslObject(key);
    return value == null ? null : AslContour.fromDescriptor(value);
  }
}

/// The complete `Lefx` object and source-ordered typed effect views.
final class AslLayerEffects {
  /// Complete `Lefx` descriptor.
  final PsDescriptor descriptor;

  /// Global layer-effect scale, normally expressed in percent.
  final AslNumber? scale;

  /// Master switch controlling all effects, when stored.
  final bool? masterEnabled;

  /// Every recognized or forward-compatible effect object in source order.
  final List<AslEffect> effects;

  /// Descriptor items not interpreted as global settings or effect objects.
  final List<PsDescriptorItem> unmodeledItems;

  /// Creates an immutable layer-effects view.
  AslLayerEffects({
    required this.descriptor,
    required this.scale,
    required this.masterEnabled,
    required List<AslEffect> effects,
    required List<PsDescriptorItem> unmodeledItems,
  }) : effects = List<AslEffect>.unmodifiable(effects),
       unmodeledItems = List<PsDescriptorItem>.unmodifiable(unmodeledItems);

  /// Creates typed views over every effect object in [descriptor].
  factory AslLayerEffects.fromDescriptor(PsDescriptor descriptor) {
    final List<AslEffect> effects = <AslEffect>[];
    final List<PsDescriptorItem> unmodeledItems = <PsDescriptorItem>[];
    final Map<AslEffectKind, int> instanceCounts = <AslEffectKind, int>{};
    for (final PsDescriptorItem item in descriptor.items) {
      if (item.key == 'Scl ' || item.key == 'masterFXSwitch') {
        continue;
      }
      final AslEffectKind kind = _kindForKey(item.key);
      final List<PsDescriptor> instances = _effectDescriptors(item.value);
      final bool resemblesEffect = kind != AslEffectKind.unknown || item.key.endsWith('Multi');
      if (instances.isEmpty) {
        unmodeledItems.add(item);
        continue;
      }
      if (!resemblesEffect && item.value is! PsObjectValue) {
        unmodeledItems.add(item);
        continue;
      }
      int nextIndex = instanceCounts[kind] ?? 0;
      for (final PsDescriptor instance in instances) {
        effects.add(
          AslEffect(
            key: item.key,
            instanceIndex: nextIndex,
            kind: kind,
            descriptor: instance,
          ),
        );
        nextIndex++;
      }
      instanceCounts[kind] = nextIndex;
    }
    return AslLayerEffects(
      descriptor: descriptor,
      scale: descriptor.aslNumber('Scl '),
      masterEnabled: descriptor.aslBoolean('masterFXSwitch'),
      effects: effects,
      unmodeledItems: unmodeledItems,
    );
  }

  /// Returns every effect belonging to [kind].
  List<AslEffect> effectsOf(AslEffectKind kind) => List<AslEffect>.unmodifiable(effects.where((effect) => effect.kind == kind));

  /// Returns the first effect belonging to [kind], when present.
  AslEffect? firstEffectOf(AslEffectKind kind) {
    for (final AslEffect effect in effects) {
      if (effect.kind == kind) {
        return effect;
      }
    }
    return null;
  }

  /// Maps both legacy four-character and modern multi-instance keys.
  static AslEffectKind _kindForKey(String key) => switch (key) {
    'DrSh' || 'dropShadow' || 'dropShadowMulti' => AslEffectKind.dropShadow,
    'IrSh' || 'innerShadow' || 'innerShadowMulti' => AslEffectKind.innerShadow,
    'OrGl' || 'outerGlow' || 'outerGlowMulti' => AslEffectKind.outerGlow,
    'IrGl' || 'innerGlow' || 'innerGlowMulti' => AslEffectKind.innerGlow,
    'ebbl' || 'bevelEmboss' || 'bevelEmbossMulti' => AslEffectKind.bevelAndEmboss,
    'ChFX' || 'chromeFX' || 'satin' || 'satinMulti' => AslEffectKind.satin,
    'SoFi' || 'solidFill' || 'solidFillMulti' => AslEffectKind.colorOverlay,
    'GrFl' || 'gradientFill' || 'gradientFillMulti' => AslEffectKind.gradientOverlay,
    'patternFill' || 'patternFillMulti' => AslEffectKind.patternOverlay,
    'FrFX' || 'frameFX' || 'frameFXMulti' => AslEffectKind.stroke,
    _ => AslEffectKind.unknown,
  };

  /// Extracts one object or every object in a Photoshop list value.
  static List<PsDescriptor> _effectDescriptors(PsDescriptorValue value) => switch (value) {
    PsObjectValue(:final PsDescriptor value) => <PsDescriptor>[value],
    PsListValue(:final List<PsDescriptorValue> values) => <PsDescriptor>[
      for (final PsDescriptorValue item in values)
        if (item case PsObjectValue(:final PsDescriptor value)) value,
    ],
    _ => const <PsDescriptor>[],
  };
}

/// One Photoshop Blend If channel range.
final class AslBlendRange {
  /// Referenced Photoshop channel identifier, when decoded.
  final String? channel;

  /// Lower black split point for the source layer.
  final int? sourceBlackLow;

  /// Upper black split point for the source layer.
  final int? sourceBlackHigh;

  /// Lower white split point for the source layer.
  final int? sourceWhiteLow;

  /// Upper white split point for the source layer.
  final int? sourceWhiteHigh;

  /// Lower black split point for underlying layers.
  final int? destinationBlackLow;

  /// Upper black split point for underlying layers.
  final int? destinationBlackHigh;

  /// Lower white split point for underlying layers.
  final int? destinationWhiteLow;

  /// Upper white split point for underlying layers.
  final int? destinationWhiteHigh;

  /// Complete source descriptor.
  final PsDescriptor descriptor;

  /// Creates an immutable Blend If range.
  const AslBlendRange({
    required this.channel,
    required this.sourceBlackLow,
    required this.sourceBlackHigh,
    required this.sourceWhiteLow,
    required this.sourceWhiteHigh,
    required this.destinationBlackLow,
    required this.destinationBlackHigh,
    required this.destinationWhiteLow,
    required this.destinationWhiteHigh,
    required this.descriptor,
  });

  /// Creates a typed view over one Photoshop Blend If [descriptor].
  factory AslBlendRange.fromDescriptor(PsDescriptor descriptor) => AslBlendRange(
    channel: _channelFromReference(descriptor.value('Chnl')),
    sourceBlackLow: descriptor.aslInteger('SrcB'),
    sourceBlackHigh: descriptor.aslInteger('Srcl'),
    sourceWhiteLow: descriptor.aslInteger('SrcW'),
    sourceWhiteHigh: descriptor.aslInteger('Srcm'),
    destinationBlackLow: descriptor.aslInteger('DstB'),
    destinationBlackHigh: descriptor.aslInteger('Dstl'),
    destinationWhiteLow: descriptor.aslInteger('DstW'),
    destinationWhiteHigh: descriptor.aslInteger('Dstt'),
    descriptor: descriptor,
  );

  /// Extracts an enumerated channel from a descriptor reference [value].
  static String? _channelFromReference(PsDescriptorValue? value) {
    if (value is! PsReferenceValue) {
      return null;
    }
    for (final PsDescriptorValue item in value.values) {
      if (item case PsEnumeratedReferenceValue(:final String value)) {
        return value;
      }
    }
    return null;
  }
}

/// Layer blending options optionally captured with an ASL preset.
final class AslBlendOptions {
  /// Keys represented by first-class blending-option fields.
  static const Set<String> _modeledKeys = <String>{
    'Opct',
    'Md  ',
    'fillOpacity',
    'blendClipped',
    'blendInterior',
    'knockout',
    'transparencyShapesLayer',
    'layerMaskAsGlobalMask',
    'vectorMaskAsGlobalMask',
    'Blnd',
    'channelRestrictions',
  };

  /// Complete `blendOptions` descriptor.
  final PsDescriptor descriptor;

  /// Master layer opacity, normally expressed in percent.
  final AslNumber? opacity;

  /// Layer blend mode.
  final AslEnumeration? blendMode;

  /// Layer fill opacity, normally expressed in percent.
  final AslNumber? fillOpacity;

  /// Whether clipped layers are blended as a group.
  final bool? blendsClippedLayers;

  /// Whether interior effects are blended as a group.
  final bool? blendsInteriorEffects;

  /// Layer knockout mode.
  final AslEnumeration? knockout;

  /// Whether layer transparency shapes the layer.
  final bool? transparencyShapesLayer;

  /// Whether the layer mask hides effects.
  final bool? layerMaskHidesEffects;

  /// Whether the vector mask hides effects.
  final bool? vectorMaskHidesEffects;

  /// Blend If ranges in source order.
  final List<AslBlendRange> blendRanges;

  /// Channel restriction enumerations in source order.
  final List<AslEnumeration> channelRestrictions;

  /// Descriptor items not represented by a typed field.
  final List<PsDescriptorItem> unmodeledItems;

  /// Creates an immutable blending-options view.
  AslBlendOptions({
    required this.descriptor,
    required this.opacity,
    required this.blendMode,
    required this.fillOpacity,
    required this.blendsClippedLayers,
    required this.blendsInteriorEffects,
    required this.knockout,
    required this.transparencyShapesLayer,
    required this.layerMaskHidesEffects,
    required this.vectorMaskHidesEffects,
    required List<AslBlendRange> blendRanges,
    required List<AslEnumeration> channelRestrictions,
    required List<PsDescriptorItem> unmodeledItems,
  }) : blendRanges = List<AslBlendRange>.unmodifiable(blendRanges),
       channelRestrictions = List<AslEnumeration>.unmodifiable(channelRestrictions),
       unmodeledItems = List<PsDescriptorItem>.unmodifiable(unmodeledItems);

  /// Creates typed views over a Photoshop blending-options [descriptor].
  factory AslBlendOptions.fromDescriptor(PsDescriptor descriptor) => AslBlendOptions(
    descriptor: descriptor,
    opacity: descriptor.aslNumber('Opct'),
    blendMode: descriptor.aslEnumeration('Md  '),
    fillOpacity: descriptor.aslNumber('fillOpacity'),
    blendsClippedLayers: descriptor.aslBoolean('blendClipped'),
    blendsInteriorEffects: descriptor.aslBoolean('blendInterior'),
    knockout: descriptor.aslEnumeration('knockout'),
    transparencyShapesLayer: descriptor.aslBoolean('transparencyShapesLayer'),
    layerMaskHidesEffects: descriptor.aslBoolean('layerMaskAsGlobalMask'),
    vectorMaskHidesEffects: descriptor.aslBoolean('vectorMaskAsGlobalMask'),
    blendRanges: _blendRanges(descriptor.aslList('Blnd')),
    channelRestrictions: _enumerations(descriptor.aslList('channelRestrictions')),
    unmodeledItems: descriptor.items.where((item) => !_modeledKeys.contains(item.key)).toList(growable: false),
  );

  /// Converts object values in [values] into Blend If ranges.
  static List<AslBlendRange> _blendRanges(List<PsDescriptorValue>? values) => <AslBlendRange>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsObjectValue(:final PsDescriptor value)) AslBlendRange.fromDescriptor(value),
  ];

  /// Converts descriptor enumeration values into immutable typed views.
  static List<AslEnumeration> _enumerations(List<PsDescriptorValue>? values) => <AslEnumeration>[
    for (final PsDescriptorValue value in values ?? const <PsDescriptorValue>[])
      if (value case PsEnumeratedValue(:final String typeId, :final String value)) AslEnumeration(typeId: typeId, value: value),
  ];
}

import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Exercises typed projections without weakening access to raw descriptors.
void main() {
  group('ASL descriptor views', () {
    test('reads scalar, object, list, and object-array values safely', () {
      const PsDescriptor nested = PsDescriptor(name: '', classId: 'nested');
      const PsDescriptor descriptor = PsDescriptor(
        name: '',
        classId: 'root',
        items: <PsDescriptorItem>[
          PsDescriptorItem(
            key: 'text',
            value: PsStringValue(value: 'value\u0000'),
          ),
          PsDescriptorItem(key: 'flag', value: PsBooleanValue(value: true)),
          PsDescriptorItem(key: 'small', value: PsIntegerValue(value: 4)),
          PsDescriptorItem(
            key: 'large',
            value: PsLargeIntegerValue(value: 1 << 40),
          ),
          PsDescriptorItem(key: 'double', value: PsDoubleValue(value: 2.5)),
          PsDescriptorItem(
            key: 'unit',
            value: PsUnitFloatValue(unit: '#Pxl', value: 3.5),
          ),
          PsDescriptorItem(
            key: 'enum',
            value: PsEnumeratedValue(typeId: 'BlnM', value: 'Nrml'),
          ),
          PsDescriptorItem(
            key: 'object',
            value: PsObjectValue(value: nested),
          ),
          PsDescriptorItem(
            key: 'list',
            value: PsListValue(values: <PsDescriptorValue>[PsBooleanValue(value: false)]),
          ),
          PsDescriptorItem(
            key: 'array',
            value: PsObjectArrayValue(itemsCount: 2, value: nested),
          ),
        ],
      );

      check(descriptor.aslString('text')).equals('value');
      check(descriptor.aslBoolean('flag')).isNotNull().isTrue();
      check(descriptor.aslInteger('small')).equals(4);
      check(descriptor.aslInteger('large')).equals(1 << 40);
      check(descriptor.aslNumber('double')?.value).equals(2.5);
      check(descriptor.aslNumber('unit')?.unit).equals('#Pxl');
      check(descriptor.aslEnumeration('enum')?.value).equals('Nrml');
      check(descriptor.aslObject('object')).identicalTo(nested);
      check(descriptor.aslList('list')).isNotNull().length.equals(1);
      check(descriptor.aslObjectArray('array')?.itemsCount).equals(2);
      check(descriptor.aslFirstValue(const <String>['missing', 'flag'])).isA<PsBooleanValue>();
      check(descriptor.aslString('flag')).isNull();
    });

    test('projects modern color aliases and color-book metadata', () {
      const PsDescriptor rgb = PsDescriptor(
        name: '',
        classId: 'RGBColor',
        items: <PsDescriptorItem>[
          PsDescriptorItem(key: 'red', value: PsDoubleValue(value: 10)),
          PsDescriptorItem(key: 'green', value: PsDoubleValue(value: 20)),
          PsDescriptorItem(key: 'blue', value: PsDoubleValue(value: 30)),
        ],
      );
      final PsDescriptor book = PsDescriptor(
        name: '',
        classId: 'BkCl',
        items: <PsDescriptorItem>[
          const PsDescriptorItem(
            key: 'Bk  ',
            value: PsStringValue(value: 'PANTONE'),
          ),
          const PsDescriptorItem(
            key: 'Nm  ',
            value: PsStringValue(value: 'Blue'),
          ),
          const PsDescriptorItem(key: 'bookID', value: PsIntegerValue(value: 12)),
          PsDescriptorItem(
            key: 'bookKey',
            value: PsRawValue(value: Uint8List.fromList(<int>[1, 2])),
          ),
        ],
      );

      final AslColor rgbView = AslColor.fromDescriptor(rgb);
      final AslColor bookView = AslColor.fromDescriptor(book);

      check(rgbView.colorSpace).equals(AslColorSpace.rgb);
      check(rgbView.component('green')?.value).equals(20);
      check(bookView.colorSpace).equals(AslColorSpace.book);
      check(bookView.bookName).equals('PANTONE');
      check(bookView.colorName).equals('Blue');
      check(bookView.bookId).equals(12);
      check(bookView.bookKey).isNotNull().deepEquals(<int>[1, 2]);
    });

    test('projects custom gradients, noise gradients, and contours', () {
      const PsDescriptor stopColor = PsDescriptor(
        name: '',
        classId: 'RGBC',
        items: <PsDescriptorItem>[
          PsDescriptorItem(key: 'Rd  ', value: PsDoubleValue(value: 255)),
          PsDescriptorItem(key: 'Grn ', value: PsDoubleValue(value: 128)),
          PsDescriptorItem(key: 'Bl  ', value: PsDoubleValue(value: 0)),
        ],
      );
      const PsDescriptor colorStop = PsDescriptor(
        name: '',
        classId: 'Clrt',
        items: <PsDescriptorItem>[
          PsDescriptorItem(key: 'Lctn', value: PsIntegerValue(value: 2048)),
          PsDescriptorItem(key: 'Mdpn', value: PsIntegerValue(value: 50)),
          PsDescriptorItem(
            key: 'Type',
            value: PsEnumeratedValue(typeId: 'Clry', value: 'UsrS'),
          ),
          PsDescriptorItem(
            key: 'Clr ',
            value: PsObjectValue(value: stopColor),
          ),
        ],
      );
      const PsDescriptor transparencyStop = PsDescriptor(
        name: '',
        classId: 'TrnS',
        items: <PsDescriptorItem>[
          PsDescriptorItem(key: 'Lctn', value: PsIntegerValue(value: 4096)),
          PsDescriptorItem(key: 'Mdpn', value: PsIntegerValue(value: 50)),
          PsDescriptorItem(
            key: 'Opct',
            value: PsUnitFloatValue(unit: '#Prc', value: 75),
          ),
        ],
      );
      const PsDescriptor custom = PsDescriptor(
        name: '',
        classId: 'Grdn',
        items: <PsDescriptorItem>[
          PsDescriptorItem(
            key: 'Nm  ',
            value: PsStringValue(value: 'Sunset'),
          ),
          PsDescriptorItem(
            key: 'GrdF',
            value: PsEnumeratedValue(typeId: 'GrdF', value: 'CstS'),
          ),
          PsDescriptorItem(key: 'Intr', value: PsDoubleValue(value: 4096)),
          PsDescriptorItem(
            key: 'Clrs',
            value: PsListValue(values: <PsDescriptorValue>[PsObjectValue(value: colorStop)]),
          ),
          PsDescriptorItem(
            key: 'Trns',
            value: PsListValue(values: <PsDescriptorValue>[PsObjectValue(value: transparencyStop)]),
          ),
        ],
      );
      const PsDescriptor noise = PsDescriptor(
        name: '',
        classId: 'Grdn',
        items: <PsDescriptorItem>[
          PsDescriptorItem(
            key: 'GrdF',
            value: PsEnumeratedValue(typeId: 'GrdF', value: 'colorNoise'),
          ),
          PsDescriptorItem(key: 'RndS', value: PsIntegerValue(value: 42)),
          PsDescriptorItem(key: 'Smth', value: PsIntegerValue(value: 1024)),
          PsDescriptorItem(
            key: 'Mnm ',
            value: PsListValue(values: <PsDescriptorValue>[PsIntegerValue(value: 1), PsIntegerValue(value: 2)]),
          ),
          PsDescriptorItem(
            key: 'Mxm ',
            value: PsListValue(values: <PsDescriptorValue>[PsIntegerValue(value: 99), PsIntegerValue(value: 100)]),
          ),
        ],
      );
      const PsDescriptor contour = PsDescriptor(
        name: '',
        classId: 'ShpC',
        items: <PsDescriptorItem>[
          PsDescriptorItem(
            key: 'Nm  ',
            value: PsStringValue(value: 'Linear'),
          ),
          PsDescriptorItem(
            key: 'Crv ',
            value: PsListValue(
              values: <PsDescriptorValue>[
                PsObjectValue(
                  value: PsDescriptor(
                    name: '',
                    classId: 'CrPt',
                    items: <PsDescriptorItem>[
                      PsDescriptorItem(key: 'Hrzn', value: PsDoubleValue(value: 0)),
                      PsDescriptorItem(key: 'Vrtc', value: PsDoubleValue(value: 0)),
                      PsDescriptorItem(key: 'Cnty', value: PsBooleanValue(value: true)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      final AslGradient customView = AslGradient.fromDescriptor(custom);
      final AslGradient noiseView = AslGradient.fromDescriptor(noise);
      final AslContour contourView = AslContour.fromDescriptor(contour);

      check(customView.form).equals(AslGradientForm.customStops);
      check(customView.colorStops.single.location).equals(2048);
      check(customView.colorStops.single.color?.component('Rd  ')?.value).equals(255);
      check(customView.transparencyStops.single.opacity?.value).equals(75);
      check(noiseView.form).equals(AslGradientForm.colorNoise);
      check(noiseView.randomSeed).equals(42);
      check(noiseView.minimumValues).deepEquals(<int>[1, 2]);
      check(noiseView.maximumValues).deepEquals(<int>[99, 100]);
      check(contourView.name).equals('Linear');
      check(contourView.points.single.horizontal?.value).equals(0);
      check(contourView.points.single.continuous).isNotNull().isTrue();
    });

    test('projects common geometry, lighting, bevel, glow, and stroke fields', () {
      const PsDescriptor point = PsDescriptor(
        name: '',
        classId: 'Pnt ',
        items: <PsDescriptorItem>[
          PsDescriptorItem(
            key: 'Hrzn',
            value: PsUnitFloatValue(unit: '#Prc', value: 25),
          ),
          PsDescriptorItem(
            key: 'Vrtc',
            value: PsUnitFloatValue(unit: '#Prc', value: -10),
          ),
        ],
      );
      const PsDescriptor descriptor = PsDescriptor(
        name: '',
        classId: 'FrFX',
        items: <PsDescriptorItem>[
          PsDescriptorItem(key: 'uglg', value: PsBooleanValue(value: true)),
          PsDescriptorItem(
            key: 'Lald',
            value: PsUnitFloatValue(unit: '#Ang', value: 30),
          ),
          PsDescriptorItem(
            key: 'Dstn',
            value: PsUnitFloatValue(unit: '#Pxl', value: 12),
          ),
          PsDescriptorItem(
            key: 'Sz  ',
            value: PsUnitFloatValue(unit: '#Pxl', value: 7),
          ),
          PsDescriptorItem(
            key: 'Ckmt',
            value: PsUnitFloatValue(unit: '#Prc', value: 18),
          ),
          PsDescriptorItem(
            key: 'Nose',
            value: PsUnitFloatValue(unit: '#Prc', value: 4),
          ),
          PsDescriptorItem(key: 'AntA', value: PsBooleanValue(value: true)),
          PsDescriptorItem(key: 'useShape', value: PsBooleanValue(value: true)),
          PsDescriptorItem(key: 'useTexture', value: PsBooleanValue(value: true)),
          PsDescriptorItem(key: 'InvT', value: PsBooleanValue(value: false)),
          PsDescriptorItem(
            key: 'GlwT',
            value: PsEnumeratedValue(typeId: 'BETE', value: 'PrBL'),
          ),
          PsDescriptorItem(
            key: 'bvlT',
            value: PsEnumeratedValue(typeId: 'bvlT', value: 'SfBL'),
          ),
          PsDescriptorItem(
            key: 'bvlS',
            value: PsEnumeratedValue(typeId: 'BESl', value: 'InrB'),
          ),
          PsDescriptorItem(
            key: 'bvlD',
            value: PsEnumeratedValue(typeId: 'BESs', value: 'In  '),
          ),
          PsDescriptorItem(
            key: 'Styl',
            value: PsEnumeratedValue(typeId: 'FStl', value: 'OutF'),
          ),
          PsDescriptorItem(
            key: 'PntT',
            value: PsEnumeratedValue(typeId: 'FrFl', value: 'GrFl'),
          ),
          PsDescriptorItem(
            key: 'Ofst',
            value: PsObjectValue(value: point),
          ),
        ],
      );
      const AslEffect effect = AslEffect(
        key: 'FrFX',
        instanceIndex: 0,
        kind: AslEffectKind.stroke,
        descriptor: descriptor,
      );

      check(effect.usesGlobalAngle).isNotNull().isTrue();
      check(effect.altitude?.value).equals(30);
      check(effect.distance?.value).equals(12);
      check(effect.size?.value).equals(7);
      check(effect.chokeOrSpread?.value).equals(18);
      check(effect.noise?.value).equals(4);
      check(effect.antiAliased).isNotNull().isTrue();
      check(effect.usesShape).isNotNull().isTrue();
      check(effect.usesTexture).isNotNull().isTrue();
      check(effect.textureInverted).isNotNull().isFalse();
      check(effect.glowTechnique?.value).equals('PrBL');
      check(effect.bevelTechnique?.value).equals('SfBL');
      check(effect.bevelStyle?.value).equals('InrB');
      check(effect.bevelDirection?.value).equals('In  ');
      check(effect.strokePosition?.value).equals('OutF');
      check(effect.strokePaintType?.value).equals('GrFl');
      check(effect.offset?.horizontal?.value).equals(25);
      check(effect.offset?.vertical?.value).equals(-10);
    });
  });
}

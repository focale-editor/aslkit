import 'dart:io';
import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';

/// Reads one ASL file and prints its styles, effects, and embedded patterns.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run example/main.dart <styles.asl>');
    exitCode = 64;
    return;
  }

  try {
    final Uint8List bytes = await File(arguments.single).readAsBytes();
    final AslFile file = AslDecoder.decode(bytes);
    stdout.writeln(
      'ASL: ${file.decodedStyles.length}/${file.declaredStyleCount} decoded styles, '
      '${file.patterns.length} embedded patterns',
    );
    for (final AslStyle style in file.styles) {
      stdout.writeln(
        '${style.name ?? '<opaque>'} (${style.id ?? 'no id'}): '
        '${style.layerEffects?.effects.length ?? 0} effects',
      );
    }
    file.warnings.forEach(stderr.writeln);
  } on AslFormatException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error);
    exitCode = 66;
  }
}

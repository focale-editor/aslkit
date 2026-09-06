import 'dart:io';
import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

/// Validates locally supplied Photoshop ASL examples when a corpus is present.
void main() {
  final List<File> examples = _examples();
  test(
    'decodes and losslessly reconstructs every local Photoshop example',
    () {
      for (final File example in examples) {
        final Uint8List source = example.readAsBytesSync();
        final AslFile decoded = AslDecoder.decode(source);
        final Uint8List reconstructed = AslEncoder.encode(
          decoded,
          options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
        );

        check(decoded.styles).isNotEmpty();
        check(reconstructed, because: example.path).deepEquals(source);
      }
    },
    skip: examples.isEmpty ? 'No local ASL_EXAMPLES or ASL EXAMPLES corpus is present.' : false,
  );
}

/// Discovers case-insensitive `.asl` files in conventional local corpus folders.
List<File> _examples() {
  final List<File> files = <File>[];
  for (final String path in const <String>['ASL_EXAMPLES', 'ASL EXAMPLES']) {
    final Directory directory = Directory(path);
    if (directory.existsSync()) {
      files.addAll(
        directory.listSync(recursive: true).whereType<File>().where((file) => file.path.toLowerCase().endsWith('.asl')),
      );
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

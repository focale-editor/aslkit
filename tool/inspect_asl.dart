import 'dart:io';
import 'dart:typed_data';

import 'package:aslkit/aslkit.dart';

/// Inspects ASL files and optionally verifies structural reconstruction.
void main(List<String> arguments) {
  final bool strict = arguments.contains('--strict');
  final bool roundTrip = arguments.contains('--round-trip');
  final bool summaryOnly = arguments.contains('--summary-only');
  final List<String> paths = <String>[
    for (final String argument in arguments)
      if (!argument.startsWith('--')) argument,
  ];
  if (paths.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/inspect_asl.dart '
      '[--strict] [--round-trip] [--summary-only] '
      '<file-or-directory> [...]',
    );
    exitCode = 64;
    return;
  }

  final List<File> files = _aslFiles(paths);
  if (files.isEmpty) {
    stderr.writeln('No ASL files found.');
    exitCode = 66;
    return;
  }
  for (final File file in files) {
    _inspect(
      file,
      strict: strict,
      roundTrip: roundTrip,
      summaryOnly: summaryOnly,
    );
  }
}

/// Returns ASL files contained in the requested files and directories.
List<File> _aslFiles(List<String> paths) {
  final List<File> files = <File>[];
  for (final String path in paths) {
    switch (FileSystemEntity.typeSync(path)) {
      case FileSystemEntityType.file:
        if (_isAslPath(path)) {
          files.add(File(path));
        }
      case FileSystemEntityType.directory:
        files.addAll(
          Directory(path).listSync(recursive: true).whereType<File>().where((file) => _isAslPath(file.path)),
        );
      case FileSystemEntityType.link:
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        break;
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

/// Decodes and prints one concise structural report for [file].
void _inspect(
  File file, {
  required bool strict,
  required bool roundTrip,
  required bool summaryOnly,
}) {
  try {
    final Uint8List bytes = file.readAsBytesSync();
    final AslFile decoded = AslDecoder.decode(
      bytes,
      options: AslDecodeOptions(
        mode: strict ? AslDecodeMode.strict : AslDecodeMode.tolerant,
      ),
    );
    final String reconstruction = roundTrip ? ', reconstruction ${_reconstructionLabel(decoded, bytes)}' : '';
    stdout.writeln(
      '${file.path}: ${decoded.containerKind.name}, '
      '${decoded.decodedStyles.length}/${decoded.declaredStyleCount} decoded styles, '
      '${decoded.patterns.length}/${decoded.patternRecords.length} decoded patterns, '
      '${decoded.taggedBlocks.length} tagged blocks, ${decoded.warnings.length} warnings$reconstruction',
    );
    if (!summaryOnly) {
      decoded.styles.forEach(_printStyle);
      for (final PsPattern pattern in decoded.patterns) {
        stdout.writeln('  pattern "${pattern.name}" (${pattern.id}), ${pattern.width} x ${pattern.height}, ${pattern.colorMode.name}');
      }
    }
    for (final AslWarning warning in decoded.warnings) {
      stdout.writeln('  warning: $warning');
    }
  } on Object catch (error) {
    stderr.writeln('${file.path}: $error');
    exitCode = 1;
  }
}

/// Prints one style and its source-ordered effect summary.
void _printStyle(AslStyle style) {
  stdout.writeln(
    '  style ${style.index + 1}: "${style.name ?? '<opaque>'}" '
    '(${style.id ?? 'no id'}), ${style.layerEffects?.effects.length ?? 0} effects',
  );
  for (final AslEffect effect in style.layerEffects?.effects ?? const <AslEffect>[]) {
    stdout.writeln(
      '    ${effect.kind.name}[${effect.instanceIndex}], '
      'enabled ${effect.enabled ?? 'unspecified'}, key "${effect.key}"',
    );
  }
}

/// Reports whether permissive encoding recreates [source] exactly.
String _reconstructionLabel(AslFile file, Uint8List source) {
  final Uint8List encoded = AslEncoder.encode(
    file,
    options: const AslEncodeOptions(mode: AslEncodeMode.permissive),
  );
  if (encoded.length != source.length) {
    return 'differs (${encoded.length} versus ${source.length} bytes)';
  }
  for (int index = 0; index < source.length; index++) {
    if (encoded[index] != source[index]) {
      return 'differs at byte $index';
    }
  }
  return 'exact';
}

/// Whether [path] names an ASL library or Photoshop's styles palette.
bool _isAslPath(String path) {
  final String normalized = path.replaceAll('\\', '/').toLowerCase();
  return normalized.endsWith('.asl') || normalized.split('/').last == 'styles.psp';
}

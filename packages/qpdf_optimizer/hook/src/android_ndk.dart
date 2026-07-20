import 'dart:io';

import 'package:path/path.dart' as p;

String findAndroidToolchainFile(
  String compilerPath, {
  p.Context? pathContext,
  bool Function(String path)? fileExists,
}) {
  final context = pathContext ?? p.context;
  final exists = fileExists ?? (path) => File(path).existsSync();
  var directory = context.dirname(compilerPath);

  while (true) {
    final candidate = context.join(
      directory,
      'build',
      'cmake',
      'android.toolchain.cmake',
    );
    if (exists(candidate)) {
      return candidate;
    }

    final parent = context.dirname(directory);
    if (parent == directory) {
      break;
    }
    directory = parent;
  }

  throw StateError(
    'Unable to find Android NDK toolchain file above compiler: $compilerPath',
  );
}

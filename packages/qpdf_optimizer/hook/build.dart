import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;

import 'src/android_ndk.dart';

const _assetName = 'src/qpdf_optimizer_bindings.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    if (code.targetOS != OS.windows && code.targetOS != OS.android) {
      return;
    }

    final packageRoot = p.fromUri(input.packageRoot);
    final thirdPartyRoot = p.join(packageRoot, 'native', 'third_party');

    if (!Directory(thirdPartyRoot).existsSync()) {
      throw StateError(
        'Package native dependencies directory not found: $thirdPartyRoot',
      );
    }
    for (final dep in ['qpdf', 'zlib', 'libjpeg-turbo']) {
      if (!Directory(p.join(thirdPartyRoot, dep)).existsSync()) {
        throw StateError(
          'Missing package native dependency: $dep in $thirdPartyRoot',
        );
      }
    }
    final outputRoot = p.fromUri(input.outputDirectory);
    final libraryName = code.targetOS.libraryFileName(
      'qpdf_optimizer',
      DynamicLoadingBundled(),
    );
    final buildDirectory = p.join(
      outputRoot,
      'cmake',
      '${code.targetOS.name}-${code.targetArchitecture.name}',
    );
    final libraryPath = p.join(buildDirectory, 'output', libraryName);
    final compiler = code.cCompiler;

    // For Android, Flutter hooks may not supply a C toolchain.
    // Discover the NDK clang compiler and toolchain file ourselves.
    String? ndkClang;
    String? ndkClangXX;
    String? toolchainFile;
    if (code.targetOS == OS.android && compiler == null) {
      final ndkPath = _findAndroidNdk(packageRoot);
      final api = code.android.targetNdkApi;
      final binDir = p.join(
        ndkPath,
        'toolchains', 'llvm', 'prebuilt',
        _ndkHostTag(),
        'bin',
      );
      final triple = _ndkTriple(code.targetArchitecture);
      ndkClang = p.join(binDir, '$triple$api-clang');
      ndkClangXX = p.join(binDir, '$triple$api-clang++');
      toolchainFile = p.join(
        ndkPath, 'build', 'cmake', 'android.toolchain.cmake',
      );
      if (!File(ndkClang).existsSync()) {
        throw StateError(
          'NDK clang not found at $ndkClang.\n'
          'Set QPDF_OPTIMIZER_NDK_ROOT or ANDROID_NDK_HOME.',
        );
      }
      if (!File(toolchainFile).existsSync()) {
        throw StateError(
          'Android toolchain file not found at $toolchainFile.',
        );
      }
    }

    // Resolve effective compiler paths
    final effectiveCCompiler = ndkClang ?? p.fromUri(compiler!.compiler);
    final effectiveCxxCompiler =
        ndkClangXX ?? _cxxCompiler(compiler!.compiler);

    // For Android, use Ninja from the NDK (or system ninja) since the NDK
    // toolchain file doesn't support MSVC.
    String? androidNinja;
    if (code.targetOS == OS.android) {
      // Try NDK-bundled ninja first
      if (ndkClang != null) {
        final ndkNinja = p.join(
          p.dirname(ndkClang!),
          'ninja${Platform.isWindows ? '.exe' : ''}',
        );
        if (File(ndkNinja).existsSync()) {
          androidNinja = ndkNinja;
        }
      }
      // Fall back to system ninja
      androidNinja ??= 'ninja';
    }

    final cmakeArguments = <String>[
      if (code.targetOS == OS.windows) ...['-G', 'NMake Makefiles'],
      if (code.targetOS == OS.android) ...['-G', 'Ninja'],
      '-S',
      p.join(packageRoot, 'native'),
      '-B',
      buildDirectory,
      '-DQPDF_OPTIMIZER_THIRD_PARTY_ROOT=$thirdPartyRoot',
      '-DQPDF_OPTIMIZER_C_COMPILER=$effectiveCCompiler',
      '-DQPDF_OPTIMIZER_CXX_COMPILER=$effectiveCxxCompiler',
      if (compiler != null)
        '-DQPDF_OPTIMIZER_AR=${p.fromUri(compiler.archiver)}',
      '-DCMAKE_BUILD_TYPE=Release',
      if (androidNinja != null) '-DCMAKE_MAKE_PROGRAM=$androidNinja',
      if (code.targetOS == OS.windows)
        '-DQPDF_OPTIMIZER_SYSTEM_PROCESSOR='
            '${_cmakeProcessor(code.targetArchitecture)}',
    ];

    if (code.targetOS == OS.android) {
      // ANDROID_ABI and ANDROID_PLATFORM must be set BEFORE the toolchain file
      // on the command line so the Android CMake toolchain picks them up.
      final abi = _androidAbi(code.targetArchitecture);
      final api = code.android.targetNdkApi;
      cmakeArguments.addAll([
        '-DANDROID_ABI=$abi',
        '-DANDROID_PLATFORM=android-$api',
        '-DANDROID_STL=c++_static',
        '-DCMAKE_TOOLCHAIN_FILE=${toolchainFile ?? findAndroidToolchainFile(p.fromUri(compiler!.compiler))}',
        '-DQPDF_OPTIMIZER_ANDROID_ABI=$abi',
        '-DQPDF_OPTIMIZER_ANDROID_API=$api',
      ]);
    }

    final configure = await _runCmake(
      arguments: cmakeArguments,
      compiler: compiler,
      windows: code.targetOS == OS.windows,
    );
    if (configure.exitCode != 0) {
      throw StateError(
        'qpdf_optimizer CMake configuration failed.\n'
        '${configure.stdout}\n${configure.stderr}',
      );
    }

    final compile = await _runCmake(
      arguments: ['--build', buildDirectory, '--config', 'Release'],
      compiler: compiler,
      windows: code.targetOS == OS.windows,
    );
    if (compile.exitCode != 0 || !File(libraryPath).existsSync()) {
      throw StateError(
        'qpdf_optimizer native build failed.\n${compile.stdout}\n${compile.stderr}',
      );
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: Uri.file(libraryPath),
      ),
    );

    output.dependencies.add(input.packageRoot.resolve('hook/build.dart'));
    output.dependencies.add(
      input.packageRoot.resolve('hook/src/android_ndk.dart'),
    );
    output.dependencies.add(input.packageRoot.resolve('native/CMakeLists.txt'));
    output.dependencies.add(
      input.packageRoot.resolve('native/cmake/set_processor.cmake'),
    );
    output.dependencies.add(input.packageRoot.resolve('native/qpdf_bridge.cpp'));
    output.dependencies.add(
      input.packageRoot.resolve('native/include/qpdf_optimizer_bridge.h'),
    );
    _addNativeDependencies(output, thirdPartyRoot);
  });
}

Future<ProcessResult> _runCmake({
  required List<String> arguments,
  required CCompilerConfig? compiler,
  required bool windows,
}) async {
  if (!windows) {
    return Process.run('cmake', arguments);
  }

  // Try to find a developer command prompt
  final prompt = compiler?.windows.developerCommandPrompt ?? 
      await _findDeveloperCommandPrompt();
  
  if (prompt == null) {
    // Fallback: try running cmake directly and hope nmake is in PATH
    // This is unlikely to work, but we'll try
    return Process.run('cmake', arguments);
  }

  // Use the developer command prompt
  final script = File(
    p.join(
      Directory.systemTemp.path,
      'qpdf_optimizer_${DateTime.now().microsecondsSinceEpoch}.cmd',
    ),
  );
  final command = [
    '@echo off',
    'call ${_cmdQuote(p.fromUri(prompt.script))} '
        '${prompt.arguments.map(_cmdQuote).join(' ')}',
    'if errorlevel 1 exit /b %errorlevel%',
    'cmake ${arguments.map(_cmdQuote).join(' ')}',
  ].join('\r\n');

  try {
    await script.writeAsString(command);
    return await Process.run('cmd.exe', ['/d', '/c', script.path]);
  } finally {
    if (script.existsSync()) {
      script.deleteSync();
    }
  }
}

Future<DeveloperCommandPrompt?> _findDeveloperCommandPrompt() async {
  // Try to find VS Developer Command Prompt
  final vsWhere = r'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe';
  if (File(vsWhere).existsSync()) {
    final result = await Process.run(vsWhere, [
      '-latest',
      '-products', '*',
      '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
      '-property', 'installationPath',
    ]);
    if (result.exitCode == 0) {
      final installPath = result.stdout.toString().trim();
      final vcvars = p.join(installPath, 'Common7\Tools\VsDevCmd.bat');
      if (File(vcvars).existsSync()) {
        return DeveloperCommandPrompt(
          script: Uri.file(vcvars),
          arguments: [],
        );
      }
    }
  }
  
  // Try common VS installation paths
  final paths = [
    r'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat',
    r'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat',
    r'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat',
    r'C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\Tools\VsDevCmd.bat',
    r'C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\Tools\VsDevCmd.bat',
    r'C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\Common7\Tools\VsDevCmd.bat',
  ];
  
  for (final path in paths) {
    if (File(path).existsSync()) {
      return DeveloperCommandPrompt(
        script: Uri.file(path),
        arguments: [],
      );
    }
  }
  
  return null;
}

String _cmdQuote(String value) => '"${value.replaceAll('"', '""')}"';

String _cxxCompiler(Uri cCompiler) {
  final compiler = p.fromUri(cCompiler);
  if (compiler.endsWith('-clang.cmd')) {
    return '${compiler.substring(0, compiler.length - '-clang.cmd'.length)}-clang++.cmd';
  }
  if (compiler.endsWith('-clang.exe')) {
    return '${compiler.substring(0, compiler.length - '-clang.exe'.length)}-clang++.exe';
  }
  if (compiler.endsWith('-clang')) {
    return '${compiler.substring(0, compiler.length - '-clang'.length)}-clang++';
  }
  if (compiler.endsWith('clang.exe')) {
    return '${compiler.substring(0, compiler.length - 'clang.exe'.length)}clang++.exe';
  }
  if (compiler.endsWith('clang')) {
    return '${compiler.substring(0, compiler.length - 'clang'.length)}clang++';
  }
  return compiler;
}

String _androidAbi(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm => 'armeabi-v7a',
    Architecture.arm64 => 'arm64-v8a',
    Architecture.ia32 => 'x86',
    Architecture.x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported Android architecture: $architecture'),
  };
}

String _cmakeProcessor(Architecture architecture) {
  return switch (architecture) {
    Architecture.arm => 'arm',
    Architecture.arm64 => 'aarch64',
    Architecture.ia32 => 'x86',
    Architecture.x64 => 'x86_64',
    _ => throw UnsupportedError('Unsupported Windows architecture: $architecture'),
  };
}

/// Discover the Android NDK root from env vars or the local Android SDK.
String _findAndroidNdk(String packageRoot) {
  // 1. Explicit env var for this package
  final explicit = Platform.environment['QPDF_OPTIMIZER_NDK_ROOT'];
  if (explicit != null && Directory(explicit).existsSync()) return explicit;

  // 2. Standard ANDROID_NDK_HOME / ANDROID_NDK
  for (final key in ['ANDROID_NDK_HOME', 'ANDROID_NDK', 'ANDROID_NDK_ROOT']) {
    final val = Platform.environment[key];
    if (val != null && Directory(val).existsSync()) return val;
  }

  // 3. Parse sdk.dir from local.properties and pick the newest usable NDK
  // The hook runs in the package dir; walk up to the project root.
  final localProps =
      File(p.join(packageRoot, '..', '..', 'android', 'local.properties'));
  if (localProps.existsSync()) {
    for (final line in localProps.readAsLinesSync()) {
      if (line.startsWith('sdk.dir=')) {
        final sdkDir = line
            .substring('sdk.dir='.length)
            .trim()
            .replaceAll('\\', '/');
        final ndkRoot = p.join(sdkDir, 'ndk');
        if (Directory(ndkRoot).existsSync()) {
          final versions = Directory(ndkRoot)
              .listSync()
              .whereType<Directory>()
              .where((d) => Directory(
                      p.join(d.path, 'toolchains', 'llvm'))
                  .existsSync())
              .map((d) => p.basename(d.path))
              .toList()
            ..sort();
          if (versions.isNotEmpty) {
            return p.join(ndkRoot, versions.last);
          }
        }
      }
    }
  }

  throw StateError(
    'Could not find Android NDK. Set QPDF_OPTIMIZER_NDK_ROOT or ANDROID_NDK_HOME.',
  );
}

/// NDK host tag for prebuilt binaries.
String _ndkHostTag() {
  if (Platform.isWindows) return 'windows-x86_64';
  if (Platform.isMacOS) return 'darwin-x86_64';
  return 'linux-x86_64';
}

/// NDK triple prefix for the given architecture.
String _ndkTriple(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.arm => 'armv7a-linux-androideabi',
    Architecture.x64 => 'x86_64-linux-android',
    Architecture.ia32 => 'i686-linux-android',
    _ => throw UnsupportedError('Unsupported Android architecture: $arch'),
  };
}

void _addNativeDependencies(BuildOutputBuilder output, String thirdPartyRoot) {
  const files = [
    'qpdf/CMakeLists.txt',
    'qpdf/qpdfConfig.cmake.in',
    'zlib/CMakeLists.txt',
    'libjpeg-turbo/CMakeLists.txt',
  ];
  const trees = [
    'qpdf/cmake',
    'qpdf/include',
    'qpdf/libqpdf',
    'zlib',
    'libjpeg-turbo/cmakescripts',
    'libjpeg-turbo/sharedlib',
    'libjpeg-turbo/simd',
    'libjpeg-turbo/src',
  ];

  for (final relativePath in files) {
    final file = File(p.join(thirdPartyRoot, relativePath));
    if (file.existsSync()) {
      output.dependencies.add(file.uri);
    }
  }
  for (final relativePath in trees) {
    final directory = Directory(p.join(thirdPartyRoot, relativePath));
    if (directory.existsSync()) {
      _addDirectoryDependencies(output, directory);
    }
  }
}

void _addDirectoryDependencies(BuildOutputBuilder output, Directory dir) {
  for (final entry in dir.listSync(recursive: true)) {
    if (entry is File) {
      final ext = p.extension(entry.path).toLowerCase();
      if ([
        '.c',
        '.cc',
        '.cpp',
        '.cxx',
        '.h',
        '.hh',
        '.hpp',
        '.cmake',
        '.in',
        '.s',
        '.asm',
        '.txt',
      ].contains(ext) ||
          p.basename(entry.path) == 'CMakeLists.txt') {
        output.dependencies.add(entry.uri);
      }
    }
  }
}

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../hook/src/android_ndk.dart';

void main() {
  test('finds the NDK toolchain from a Windows compiler path', () {
    final context = p.Context(style: p.Style.windows);
    const compiler =
        r'C:\Android\Sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android24-clang.exe';
    const expected =
        r'C:\Android\Sdk\ndk\28.2.13676358\build\cmake\android.toolchain.cmake';

    expect(
      findAndroidToolchainFile(
        compiler,
        pathContext: context,
        fileExists: (path) => path == expected,
      ),
      expected,
    );
  });

  test('finds the NDK toolchain from a Unix compiler path', () {
    final context = p.Context(style: p.Style.posix);
    const compiler =
        '/opt/android/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android24-clang';
    const expected =
        '/opt/android/ndk/28.2.13676358/build/cmake/android.toolchain.cmake';

    expect(
      findAndroidToolchainFile(
        compiler,
        pathContext: context,
        fileExists: (path) => path == expected,
      ),
      expected,
    );
  });

  test('fails clearly when no NDK toolchain exists above the compiler', () {
    expect(
      () => findAndroidToolchainFile(
        '/toolchains/llvm/bin/clang',
        pathContext: p.Context(style: p.Style.posix),
        fileExists: (_) => false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Unable to find Android NDK toolchain file'),
        ),
      ),
    );
  });
}

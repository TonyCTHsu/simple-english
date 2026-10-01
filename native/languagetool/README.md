# Native LanguageTool proof build

This module compiles the subset of LanguageTool 6.6 used by `simple_english` into a host-native executable. It is a feasibility build, not release packaging.

The program loads `rules/simple-english.xml`. It retains English tokenizer, tagger, disambiguator, and synthesizer behavior but omits LanguageTool's built-in rules. It accepts plain text or the same `AnnotatedText` JSON produced by the Ruby gem. It returns LanguageTool's JSON match format with context and UTF-16 offsets. Daemon integration remains incomplete.

## Targets

The build script detects the host operating system and CPU architecture. It supports these targets:

- macOS arm64
- Linux x86-64 with glibc
- Linux arm64 with glibc

Native Image does not cross-compile. Run the build on the target platform. Each target uses a separate directory under `tmp/native-languagetool/`, so builds for different targets do not overwrite each other.

All three targets pass the rule-example and JVM/native parity checks. The Linux targets were tested in Ubuntu 24.04 containers. The x86-64 container ran under CPU emulation. The arm64 container ran natively.

## Prerequisites

macOS requires the Xcode command-line tools. The proof build currently requires Apple Clang 17.0.0 (`clang-1700.6.4.2`), linker `ld-1230.1`, and macOS SDK 26.2.

Ubuntu requires:

```sh
sudo apt-get update
sudo apt-get install -y build-essential zlib1g-dev ruby
```

Linux executables dynamically link glibc and zlib. Build release artifacts on the oldest glibc version that the gem supports. The current Ubuntu 24.04 proof uses GCC 13.3, GNU ld 2.42, and glibc 2.39. This glibc version is not a suitable compatibility baseline for a broad Linux release.

## Build

From the repository root, run:

```sh
ruby native/languagetool/build.rb
```

The command downloads verified Maven and GraalVM archives for the detected target. It resolves the pinned Maven dependency graph. It verifies every downloaded POM and JAR against `dependencies.sha256`. It builds with Native Image's `compatibility` machine target. It then compares native and JVM output for every rule example and an annotated code-comment fixture.

Output is:

```text
tmp/native-languagetool/<platform>/languagetool-native
```

Set `SE_NATIVE_BUILD_DIR` to move downloads, Maven state, and target output to another filesystem:

```sh
SE_NATIVE_BUILD_DIR=/var/tmp/simple-english-native ruby native/languagetool/build.rb
```

The cache filesystem must support symbolic links because GraalVM archives contain them.

Pinned build inputs include:

- Apache Maven 3.9.16, verified by SHA-512.
- Oracle GraalVM JDK 21.0.12+7.1 for each target, verified by SHA-256.
- LanguageTool `language-en` 6.6 and explicit Maven plugin versions.
- Every resolved Maven POM and JAR, verified by `dependencies.sha256`.
- Native Image reachability and resource metadata under `config/`.
- Native Image flags. These include `-march=compatibility`.

The macOS build verifies exact compiler, linker, and SDK versions. Linux builds verify that `cc`, `ld`, and `ldd` are available but do not pin their versions. Release jobs need a tracked Linux build image. The image must pin its digest, package versions, and glibc compatibility floor.

The first build downloads about 340 MB. Native Image requires about 5 GB of memory.

Two builds from the same inputs produce functionally equivalent executables, but not necessarily byte-identical files. Oracle GraalVM 21.0.12 does not provide a deterministic-output guarantee. Repeated macOS proof builds had different Mach-O content and `LC_UUID` values even with Apple's `-reproducible` linker option. Release packaging must retain each verified artifact rather than expect a later rebuild to reproduce its checksum.

## Updating dependencies

Change explicit versions first. Then regenerate and review the dependency lock:

```sh
UPDATE_DEPENDENCY_LOCK=1 ruby native/languagetool/build.rb
```

Never update `dependencies.sha256` without reviewing coordinate and checksum changes. Normal builds fail when resolved artifacts differ from the lock.

## Reachability metadata

Files under `config/` came from the Native Image tracing agent exercised against every rule example. `resource-config.json` also includes all English resources because some LanguageTool resource loads are indirect and invisible to the agent.

Regenerate metadata only after changing Java or LanguageTool behavior. Validate regenerated files, retain the explicit `org/languagetool/resource/en/.*` inclusion, then run the normal build again.

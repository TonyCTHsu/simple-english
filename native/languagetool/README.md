# Native LanguageTool server

This module compiles LanguageTool 6.6's stock HTTP server as a native executable. Gem users do not need Java. The executable embeds `rules/simple-english.xml` at LanguageTool's custom English rule path.

Ruby keeps ownership of the public `se` daemon, Markdown processing, and code-comment extraction. It also owns counting rules, configuration, suppressions, locations, and output. The native process provides LanguageTool's internal `/v2/check` API.

## Technical overview

The build uses GraalVM Native Image to compile LanguageTool's stock
HTTP server and its runtime JARs ahead of time. The result is a
platform-specific executable that starts without a JVM.

Native Image can find direct code calls with static analysis. It
cannot find every class loaded through reflection or every resource
selected at run time. `metadata.rb` therefore runs the stock server on
the JVM under GraalVM's tracing agent. The verifier exercises rules,
annotated text, error recovery, offsets, and corpus files during that
run. The agent records reached classes and resources in tracked
reachability metadata.

`build.rb` stages the custom rules, resolves the Maven classpath, and
passes that metadata to Native Image. It then starts the compiled
server and runs a smoke test. `verify.rb` sends the same full workload
to the JVM server and native server and requires identical HTTP status
codes and JSON responses.

CI runs metadata generation, native compilation, parity verification,
and platform-gem installation in that order. Release jobs repeat the
build and verification on each target OS because Native Image does not
cross-compile. At run time, Ruby starts the bundled executable on a
loopback port. Users do not need GraalVM, Maven, Java, or build tools.

## Release targets

Initial release artifacts target:

- macOS arm64
- Linux x86-64 with glibc

Native Image does not cross-compile. Build each executable on its target platform. Linux releases use Ubuntu 22.04 and require glibc 2.35 or newer. GraalVM emits Linux AWT support libraries beside the stock server. An isolated Ubuntu test proves that the executable does not load them, so release packages exclude them. Linux arm64, macOS x86-64, Windows, and musl Linux are deferred.

## Build

Prerequisites:

- GraalVM Community Edition for JDK 25 with Native Image
- A native C compiler, linker, and zlib development files
- At least 10 GB of available memory

The Maven Wrapper downloads Maven 3.9.16 and verifies its SHA-256 checksum. CI and release jobs install GraalVM with the official `graalvm/setup-graalvm` action. From the repository root, run:

```sh
ruby native/languagetool/build.rb
```

## Compilation pipeline

`build.rb` performs these steps:

1. `./mvnw process-resources dependency:build-classpath` resolves the
   runtime JARs from `pom.xml`. The POM excludes `language-all`. It adds
   English, Catalan, Spanish, and Portuguese. LanguageTool's English
   `CommonWordsDetector` loads the other three language modules at run
   time. simple_english enables only its custom English rules.
2. The script copies `rules/simple-english.xml` to
   `org/languagetool/rules/en/grammar_custom.xml` in the staged classes
   directory. This is the stock server's custom English rule location.
3. GraalVM Native Image compiles the staged classes and runtime JARs.
   The entry point is LanguageTool's stock
   `org.languagetool.server.HTTPServer`. This repository has no Java
   launcher or request protocol.
4. The script starts the executable and sends the same `/v2/check`
   request twice. This proves the custom rules are embedded and the
   server handles more than one request.

Native Image receives these project-specific options:

- `--no-fallback` fails the build instead of producing a JVM launcher.
- `-march=compatibility` avoids build-host CPU requirements.
- `-H:ConfigurationFileDirectories=.../config` loads the tracked
  reachability metadata.
- `--initialize-at-run-time=...` delays logging, metrics, telemetry,
  and Netty initialization until process startup. Their static state
  cannot be captured safely in the image heap.
- `--enable-url-protocols=http,https` includes URL handlers used while
  LanguageTool checks text.
- `--enable-sbom=embed,export` puts a CycloneDX SBOM in the executable
  and writes a copy beside it.
- `NATIVE_IMAGE_PARALLELISM`, when set, limits Native Image worker
  threads. CI and release builds set it to `4`.

Build output:

```text
tmp/native-languagetool/languagetool-native
tmp/native-languagetool/languagetool-native.sbom.json
tmp/native-languagetool/lib*.so # Linux build support files
```

The Linux executable dynamically links glibc and zlib. GraalVM also
emits AWT support libraries, but the exercised server path does not
load them. The Linux platform gem does not include them.

The stock server binds to loopback unless started with `--public`.
The Ruby daemon never passes `--public`.

## Full verification

The verifier starts one JVM server and one native server. It compares
HTTP status codes and JSON responses for every rule example. It also
checks annotated text, UTF-16 offsets, malformed-request recovery,
repeated requests, and all corpus pairs:

```sh
ruby native/languagetool/verify.rb \
  "$(cat tmp/native-languagetool/classpath)" \
  tmp/native-languagetool/languagetool-native
```

CI runs the Ruby tests, rule examples, self-lint, and an installed-gem
user story after parity. Release jobs repeat parity on each target,
install the resulting platform gem, and run the same user story before
publication.

## Runtime integration

Released platform gems place the executable at:

```text
libexec/simple_english/languagetool-server
```

Source builds can test the executable without copying it:

```sh
SE_LANGUAGETOOL_EXECUTABLE="$PWD/tmp/native-languagetool/languagetool-native" bin/se README.md
```

The Ruby daemon starts the executable once on its internal loopback port and monitors it. No rules file or runtime LanguageTool installation is needed.

## Reachability metadata

Native Image needs an explicit list of classes and resources reached
through reflection or dynamic resource loading. GraalVM 25's tracing
agent creates `config/reachability-metadata.json` while the stock JVM
server runs. `metadata.rb` prepares the same classpath as `build.rb`,
runs the full verifier workload under the agent, validates reflection
and resource entries, and replaces the tracked file. Fixed JVM locale
and time zone values make the file byte-identical on macOS and Linux:

```sh
ruby native/languagetool/metadata.rb
ruby native/languagetool/build.rb
ruby native/languagetool/verify.rb \
  "$(cat tmp/native-languagetool/classpath)" \
  tmp/native-languagetool/languagetool-native
```

Run this sequence after any LanguageTool, GraalVM, dependency, server,
verifier, or rules change. CI detects stale metadata without modifying
it:

```sh
ruby native/languagetool/metadata.rb --check
```

`--check` generates a candidate under
`tmp/native-languagetool/agent-metadata/` and byte-compares it with the
tracked file. It does not update the tracked file. The build currently
inherits two metadata warnings from Micrometer dependencies: one
experimental reflection configuration and one deprecated proxy
configuration. They come from dependency JARs rather than this
repository's metadata.

## Changing the native engine

For a LanguageTool, dependency, rule, GraalVM, or Native Image option
change:

1. Update `pom.xml`, build configuration, or rules.
2. Run `ruby native/languagetool/metadata.rb`.
3. Run `ruby native/languagetool/build.rb`.
4. Run the full verifier shown above.
5. Run the Ruby tests, rule examples, corpus checks, and self-lint with
   `SE_LANGUAGETOOL_EXECUTABLE` pointing at the new executable.
6. Review the exported SBOM for dependency graph changes.

Commit the metadata when regeneration changes it. Do not commit files
under `tmp/native-languagetool/`.

## Reproducibility

Release workflows pin the GraalVM action, GraalVM version, Maven
Wrapper, Maven distribution checksum, LanguageTool version, Maven
plugins, and target runner OS. The runner image supplies its compiler,
linker, and SDK, so builds require behavioral parity rather than
byte-identical executables. Each native server archive has a SHA-256
checksum and exported SBOM. GitHub attests every release artifact.

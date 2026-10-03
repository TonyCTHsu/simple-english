# Native LanguageTool server

This module compiles LanguageTool 6.6's stock HTTP server as a native executable. Gem users do not need Java. The executable embeds `rules/simple-english.xml` at LanguageTool's custom English rule path.

Ruby keeps ownership of the public `se` daemon, Markdown processing, and code-comment extraction. It also owns counting rules, configuration, suppressions, locations, and output. The native process provides LanguageTool's internal `/v2/check` API.

## Release targets

Initial release artifacts target:

- macOS arm64
- Linux x86-64 with glibc

Native Image does not cross-compile. Build each executable on its target platform. Linux releases use Ubuntu 22.04 and require glibc 2.35 or newer. GraalVM emits Linux AWT support libraries beside the stock server. An isolated Ubuntu test proves that the executable does not load them, so release packages exclude them. Linux arm64, macOS x86-64, Windows, and musl Linux are deferred.

## Build

Prerequisites:

- Oracle GraalVM 25.0.4.1.1 with Native Image
- A native C compiler, linker, and zlib development files
- At least 10 GB of available memory

The Maven Wrapper downloads Maven 3.9.16 and verifies its SHA-256 checksum. CI and release jobs install GraalVM with the official `graalvm/setup-graalvm` action. From the repository root, run:

```sh
ruby native/languagetool/build.rb
```

The script resolves the Maven runtime classpath and stages the custom rules. It builds the stock `org.languagetool.server.HTTPServer`, then sends two `/v2/check` requests through one process. Output:

```text
tmp/native-languagetool/languagetool-native
tmp/native-languagetool/languagetool-native.sbom.json
tmp/native-languagetool/lib*.so # Linux only
```

The build embeds and exports a CycloneDX SBOM. It uses `-march=compatibility` and disables fallback images. It initializes logging and telemetry packages at run time. It also enables the HTTP and HTTPS URL handlers required by LanguageTool. Reachability metadata lives under `config/`.

The stock server binds to loopback unless started with `--public`. The Ruby daemon never passes `--public`.

## Full verification

The verifier starts one JVM server and one native server. It compares HTTP status codes and JSON responses for every rule example, annotated text, UTF-16 offsets, malformed-request recovery, repeated requests, and all corpus pairs:

```sh
ruby native/languagetool/verify.rb \
  "$(cat tmp/native-languagetool/classpath)" \
  tmp/native-languagetool/languagetool-native
```

Release CI must also run `rake check`, inspect dynamic-library dependencies, and test each packaged artifact on its target platform.

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

`config/reachability-metadata.json` comes from GraalVM 25's tracing agent. The metadata script prepares the JVM classpath. It starts the stock JVM server through the full verifier workload, validates the agent output, and replaces the tracked file. Fixed JVM locale and time zone values make the output identical on macOS and Linux:

```sh
ruby native/languagetool/metadata.rb
ruby native/languagetool/build.rb
ruby native/languagetool/verify.rb \
  "$(cat tmp/native-languagetool/classpath)" \
  tmp/native-languagetool/languagetool-native
```

Run this sequence after any LanguageTool, JDK, dependency, server, or rules change. CI detects stale metadata without modifying it:

```sh
ruby native/languagetool/metadata.rb --check
```

Generated candidates stay under `tmp/native-languagetool/agent-metadata/`. The build currently inherits two metadata warnings from Micrometer dependencies: one experimental reflection configuration and one deprecated proxy configuration. They come from dependency JARs rather than this repository's metadata.

## Reproducibility

Release jobs must pin GraalVM, Maven, target OS, compiler, linker, SDK, glibc baseline, and resolved Maven dependencies. Retain checksums, the embedded Native Image SBOM, and build provenance for every artifact. Verification requires equivalent behavior, not byte-identical executables.

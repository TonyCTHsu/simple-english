# Native LanguageTool helper

This module compiles the LanguageTool 6.6 subset used by `simple_english` into a persistent native helper. Gem users do not need a JVM. The helper embeds `rules/simple-english.xml`, disables LanguageTool's built-in rules, and retains the English tokenizer, tagger, disambiguator, synthesizer, dictionaries, and OpenNLP models required by the custom rules.

Ruby daemon integration and gem packaging remain incomplete.

## Release targets

Initial release artifacts target:

- macOS arm64
- Linux x86-64 with glibc

Native Image does not cross-compile. Build each executable on its target platform. Linux arm64 is deferred until user demand justifies its CI and packaging cost. macOS x86-64, Windows, and musl Linux are also deferred.

Linux executables dynamically link glibc and zlib. Release Linux artifacts must be built in a pinned image using the oldest glibc version supported by the gem. Use `-march=compatibility`, as the build script does, to avoid requiring the build machine's CPU features.

## Protocol

The helper starts once and reads one JSON request per line from standard input. It writes one JSON response per line to standard output. Embedded newlines are JSON escapes, so each physical line is one complete frame.

Plain text request:

```json
{"text":"The worker didn't write the file."}
```

Annotated text request:

```json
{"annotation":[{"markup":"#","interpretAs":" "},{"text":" The worker didn't write the file."}]}
```

Successful response:

```json
{"matches":[{"message":"Write the words in full. No contractions.","offset":14,"length":3,"context":{"text":"n't","offset":0,"length":3},"rule":{"id":"SE_NO_CONTRACTIONS"}}]}
```

Offsets and lengths are UTF-16 code units. Context contains only the matched source text because this is all the Ruby client consumes. A malformed request returns `{"error":"..."}` without stopping the process.

## Build

Prerequisites:

- Maven 3.9.16
- Oracle GraalVM JDK 21.0.12+7.1 with Native Image
- A native C compiler, linker, and zlib development files
- About 5 GB of available memory

Set `JAVA_HOME` to GraalVM and place its `bin` directory, Maven, and native build tools on `PATH`. From the repository root, run:

```sh
ruby native/languagetool/build.rb
```

CI, not this script, must provision and pin the toolchain. The script compiles Java classes and asks Maven for their runtime classpath. It runs Native Image, then sends two requests through one native process as a smoke test.

Output:

```text
tmp/native-languagetool/languagetool-native
```

The build uses:

```text
--no-fallback
-march=compatibility
--initialize-at-build-time=org.slf4j
--enable-url-protocols=https
```

HTTPS support remains necessary because LanguageTool resolves English synthesis metadata through a URL. Reachability and resource metadata live under `config/`.

## Full verification

The full verifier sends all requests through one JVM process and one native process. It checks every custom rule, every correct and incorrect example, annotated input, UTF-16 locations, successive requests, and byte-identical JSON responses between the two implementations.

After building, run:

```sh
ruby native/languagetool/verify.rb \
  "$(cat tmp/native-languagetool/classpath)" \
  tmp/native-languagetool/languagetool-native
```

`JAVA_HOME` must still identify GraalVM. Release CI must also run the repository corpus and Ruby daemon tests, inspect native runtime dependencies, and test each release artifact on its target platform.

## Release reproducibility

Release jobs will pin:

- LanguageTool 6.6
- Oracle GraalVM JDK 21.0.12+7.1 and its archive checksum
- Maven 3.9.16
- Build image or runner definition
- Compiler and linker environment
- Linux glibc compatibility floor
- Resolved Maven dependency graph

Retain each verified executable with its checksum and build provenance. Functional reproducibility is required. Oracle GraalVM does not guarantee byte-identical native executables from repeated builds.

## Updating reachability metadata

Remove unused dependencies before pruning metadata. After any dependency, Java, rules, or metadata change:

1. Build the native executable.
2. Run the full verifier.
3. Run all corpus checks.
4. Exercise two or more requests in one process.
5. Inspect runtime dynamic-library dependencies.

Do not remove an English resource, synthesis resource, model, reflection entry, or service registration until this sequence passes.

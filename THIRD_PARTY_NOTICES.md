# Third-party notices

Files under `licenses/` carry the license texts and upstream notices
for third-party software distributed inside this gem. Simple English's
own code is MIT-licensed; see `LICENSE`.

## Lint engine

Each platform gem ships a compiled lint engine at
`libexec/simple_english/languagetool-server`. The binary is built with
GraalVM Community Edition 25.0.2 and contains code from the
components below. The authoritative list of components inside a given
binary is the CycloneDX SBOM published with each release
(`dist/languagetool-server-<platform>.sbom.json`).

| Component | License | Notice |
|---|---|---|
| LanguageTool 6.6 (`languagetool-core`, `languagetool-server`, `languagetool-gui-commons`, `language-en`, `language-ca`, `language-es`, `language-pt`), unmodified except for a build-time copy of `rules/simple-english.xml` into the English rules | LGPL-2.1 | `licenses/LGPL-2.1.txt` |
| English word-list and POS data (12dicts, AGID, Moby/WordNet POS) | upstream terms, public domain | `licenses/languagetool-resource-en/` |
| `at.favre.lib:bcrypt` 0.10.2 | Apache-2.0 | |
| `ch.qos.logback:logback-classic` 1.5.18 | EPL-1.0 or LGPL-2.1 | |
| `co.elastic.logging:logback-ecs-encoder` 1.3.2 | Apache-2.0 | |
| `com.fasterxml.jackson.core:jackson-databind` 2.18.0 | Apache-2.0 | |
| `commons-cli:commons-cli` 1.9.0 | Apache-2.0 | |
| `commons-codec:commons-codec` 1.17.1 | Apache-2.0 | |
| `edu.washington.cs.knowitall:opennlp-*` models 1.5 | Apache-2.0 | |
| `io.lettuce:lettuce-core` 6.5.4 | MIT | |
| `io.prometheus:simpleclient_*` 0.16.0 | Apache-2.0 | |
| `org.apache.opennlp:opennlp-tools` 1.9.4 | Apache-2.0 | |
| `org.mariadb.jdbc:mariadb-java-client` 3.4.1 | LGPL-2.1 | `licenses/LGPL-2.1.txt` |
| `org.mybatis:mybatis` 3.5.16 | Apache-2.0 | |
| `org.slf4j:slf4j-api` 2.0.16 | MIT | |
| GraalVM and OpenJDK runtime code | GPLv2 with the Classpath Exception | `licenses/OpenJDK-LICENSE.txt` |

The engine uses logback under its LGPL-2.1 option, not its EPL-1.0
option.

## LGPL 2.1 obligations

LanguageTool is licensed under the GNU Lesser General Public License
2.1. This gem distributes a binary statically linked with
LanguageTool, which LGPL 2.1 section 6 permits when recipients can
study, modify, and rebuild the LGPL part:

- The license text ships with every gem (`licenses/LGPL-2.1.txt`).
- The corresponding LanguageTool source is the `v6.6` tag at
  https://github.com/languagetool-org/languagetool/tree/v6.6
- The gem's MIT license permits reverse engineering, so you may
  debug the binary and your modifications to it.
- You can rebuild the engine against a modified LanguageTool: change
  the version in `native/languagetool/pom.xml` and follow the
  rebuild steps in `native/languagetool/README.md` under "Changing
  the native engine".

Written offer under section 6(c): we give any recipient the
machine-readable materials that section 6(a) names, for at least three
years after each release, at no charge. Ask in an issue at
https://github.com/TonyCTHsu/simple-english/issues. The materials are
the LanguageTool `v6.6` source, the resolved classpath of
`native/languagetool/pom.xml` as Maven Central artifacts, the
reachability metadata under `native/languagetool/config/`, and the
build scripts `native/languagetool/build.rb` and `Rakefile` with the
`rules/simple-english.xml` overlay. You need them to modify
LanguageTool and relink a working engine.

## OpenJDK and GraalVM source

The binary embeds OpenJDK and GraalVM Community runtime code under
GPLv2 with the Classpath Exception. The corresponding source is
public: https://github.com/openjdk/jdk and
https://github.com/oracle/graal. The release SBOM names the versions
the binary embeds.

# simple-english for `pi`

> Write for human, not for agent.

You can teach an agent plain-English prose with a skill or a
prompt. It writes clean prose in the first paragraph and slop again
by the third. This linter keeps the agent honest: it reads what the
agent wrote and names every broken rule. Send the findings back, and
the agent corrects its own text.

<table>
<tr>
<th width="50%">Before</th>
<th width="50%">After</th>
</tr>
<tr>
<td valign="top">

> Your API keys are rotated by the service every 90 days — you will need to update them if you get a 401; don't panic, simply re-run the setup command, which regenerates the credentials without any downtime. <!-- se: ignore -->

</td>
<td valign="top">

> The service rotates your API keys every 90 days. If you get a 401, update them. Do not panic. Re-run the setup command. It regenerates the credentials without any downtime.

</td>
</tr>
</table>

The linter covers Markdown prose plus code comments in Python, Ruby,
JavaScript, TypeScript, Go, Rust, Java, C, C++, and C#. It also
reads Objective-C, Kotlin, Swift, Scala, Dart, PHP, Perl, Elixir,
Lua, R, Haskell, Zig, SQL, and bash. It reads comments in config
formats and markup as well: YAML, TOML, INI, Makefile, Dockerfile,
HTML, and XML.

## What it checks

- **Voice:** say who does the action.
- **Tense:** simple tenses only, no present perfect.
- **Modals:** `can`, `will`, `must` only.
- **Punctuation:** no em-dashes, no semicolons.
- **Contractions:** write every word in full.
- **Sentence shape:** condition before command, no `-ing` phrase after a comma.
- **Word choice:** about 50 substitution rules, from `leverage` to `in conclusion`.
- **Counts:** 20 words per sentence in list items, 25 in paragraphs, six sentences per paragraph at most.

It lints Markdown prose plus code comments in Python, Ruby,
JavaScript, TypeScript, Go, Rust, Java, C#, C++, Kotlin, bash, and
YAML. The full list, with a wrong and a right example for each rule,
is [docs/RULES.md](https://github.com/TonyCTHsu/simple-english/blob/master/docs/RULES.md).

## Install

```bash
pi install npm:pi-simple-english
```

Install it for one project only by adding `-l` and running the
command from the project root.

The tool calls the `se` CLI. That CLI ships as a Ruby gem. Install
it once, before the first lint:

```bash
gem install simple_english
```

## What you get

The `se_lint` tool lints a file or a directory on demand. Every
file edit lints too. The findings land in the edit result, so the
agent fixes them in the same turn. Each finding carries a line
number, a rule ID, and a fix hint:

```
README.md:12:31-32: [SE_NO_SEMICOLON] ";" - Write two sentences, or name the relation.
```

The `write-simple-english` skill carries the rules, so the agent
writes clean prose the first time. The `lint-simple-english` skill
tells the agent to lint the prose it writes and fix every finding.

## Toggle

Turn the linter off for the session with `/se off`. That hides the
`se_lint` tool and stops the edit enforcement. Turn it back on with
`/se on`, or run `/se` to flip the current state. The status line
shows `● simple-english` while it is on.

The toggle lasts for the session. To stop the linter for every
session, uninstall the package: `pi uninstall npm:pi-simple-english`.

## Versions

The package version tracks the gem version. The changelog lives in
the repository:

https://github.com/TonyCTHsu/simple-english/blob/master/CHANGELOG.md

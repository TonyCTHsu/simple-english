# Contributing

simple_english is a small project. Pull requests are limited to
collaborators. You can help in other ways.

## Report a bug or a false positive

A false positive is a finding that flags correct text. Open an issue at
https://github.com/TonyCTHsu/simple-english/issues. Include:

- The text that triggered the finding.
- The rule ID from the finding, for example `SE_SLOP_LEVERAGE`.
- The output you expected instead.

## Suggest a rule or a feature

Open an issue and describe the change you want. For a new rule, give
one wrong example and one right example, in the format of
[docs/RULES.md](docs/RULES.md).

## Propose a code change

Open an issue first. A maintainer will implement the change. If you
want to do the work yourself, say so in the issue. A maintainer will
invite you as a collaborator.

## Run the tests on your machine

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the layout, the
test strategy, and the container setup.

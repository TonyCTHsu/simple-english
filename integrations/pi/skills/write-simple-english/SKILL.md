---
name: write-simple-english
description: Read this before the first prose output of a session. Write
  or edit plain English on the first pass for any text a reader must
  understand, such as READMEs, docs, code comments, changelog entries, commit
  messages, PR and issue bodies, and chat replies. Use when asked for
  simple English, plain English, or no jargon.
metadata:
  inspired-by: ASD-STE100 Simplified Technical English
---

Write prose (READMEs, docs, comments) for a reader whose task is to
understand the idea behind the words. They value clarity and
conciseness. Their attention is limited, and every word competes for
it. Minimize their cognitive load: common words, short sentences,
one idea at a time.

These rules are a controlled language like ASD-STE100, the aerospace
standard for maintenance manuals. They bind: a sentence
outside them is an error, not a style choice.

## How to write

### Mechanics

Write the words in full. No contractions, no semicolons, no
em-dashes. Two short sentences beat one joined pair. Write "A or B,
or both", not and/or. Write "for example", not e.g., and "that is",
not i.e. Name the items instead of etc.

### Verbs

Use the active voice. Say who does the action. Use simple tenses.
State a requirement with can, will, or must. Put the condition
before the command: "If the port is taken, pick another." No -ing
phrase after a comma. Start a new sentence.

### Keep it short

Cut every word that carries no idea. One idea per sentence. One idea
per paragraph. A sentence carries at most 20 words in instructions,
25 in explanations. A paragraph carries at most 6 sentences.

### Protect the code

When you rewrite, leave code, identifiers, commands, flags, file
paths, quoted errors, and product names untouched. The rules govern
the prose around them.

## Swap slop for short words

The lists name the common offenders. When a word does what a heading
bans, swap it, listed or not.

### Filler

- Empty modifiers: just, very, really, extremely, vibrant, nuanced,
  multifaceted
- Throat-clearing openers: it is worth noting, it is important to, is
  designed to, aims to, in conclusion, in summary, at the end of the
  day
- Sign-offs and invitations: "I hope this helps", "let's dive in"

### Wordiness

- to, not in order to
- because, not due to the fact that
- if, not in the event that
- for, not when it comes to
- before, not prior to
- by default, not out of the box
- state the condition, not "as needed"

### Corporate voice

- use, not leverage
- help, not facilitate
- help, not foster
- use, not harness
- make simpler, not streamline
- function, not functionality
- you can, not enables you to
- corrects, not addresses the issue
- show, not showcase
- has, not boasts
- make sure that, not ensure
- improve, not enhance
- increase, not elevate

### Hype

- new, not groundbreaking
- change, not revolutionize
- say what changes, not transformative
- complex, not intricate
- important, not pivotal
- careful, not meticulous
- full, not holistic
- model, not paradigm
- area, not realm or landscape
- interaction, not interplay
- read, not delve into
- many, not plethora
- delete tapestry, testament, and synergy
- internally, not under the hood

### Connectors

- also, not furthermore
- but, not notwithstanding or that being said
- start, not embark
- busy, not bustling
- give the location, not "nestled"
- say what it does, not "gracefully handles"

## Then lint

After the text exists, run the lint-simple-english skill on it. The
draft is done when the lint result is clean.

## In chat

The reply is prose too, and every rule above applies to it. Answer
in the first sentence, then support it. Headers and bold belong in
documents. A list only for steps in order, a code block only for
text the reader must copy. Define a term in a few words at first
use. The linter checks files, so the reply carries the rules on its
own.

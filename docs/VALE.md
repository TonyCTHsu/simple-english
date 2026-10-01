# The Vale edition

se ships a Vale edition of its rule set. Pipelines that already run
Vale can lint with it. The se CLI stays the full check: run it when
the edition is not enough.

## Coverage

The edition enforces 63 of the 67 built-in rules. `bin/render-vale`
generates the checks from the rule XML. Five checks are hand-written
in `vale/overrides`, because the generator cannot translate the
part-of-speech patterns. Four rules have no Vale form:

- The em-dash and semicolon rules. Vale checks match words, not
  punctuation.
- The two counting rules. They count words and sentences, which no
  Vale check can do.

## Use it

Vendor `vale/styles` into your repository, or point Vale at a
checkout of this one:

```ini
StylesPath = path/to/simple-english/vale/styles
MinAlertLevel = error
[*.md]
BasedOnStyles = SimpleEnglish
```

Code comments lint too. Vale reads them with tree-sitter.

## Limits

- `SE_CONDITION_FIRST` is degraded. Vale's tagger does not mark
  imperative verbs reliably, so some true cases escape.
- Sequence checks match case-sensitively. A sentence-initial verb can
  escape.
- The `se: ignore` directive does nothing under Vale. Use Vale's own
  ignore comments: `<!-- vale off -->` and `<!-- vale on -->`.
- Grouped rules keep their position in the check id. Suppress
  `SE_SLOP_LATIN_1` rather than `SE_SLOP_LATIN`.

## Maintenance

`bin/render-vale` regenerates the edition. Run it after every rule
change and commit the result. A unit test fails when the committed
edition is stale. The CI `vale` job lints the corpus through the
edition: every before file must flag, every after file must stay
clean.

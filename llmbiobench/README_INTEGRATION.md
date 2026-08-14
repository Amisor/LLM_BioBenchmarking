# Unified Bioinformatics Agent Benchmark Extension

This is a proposed drop-in extension for an existing R benchmark package.

## Core principle

Evaluate agents at the most objective level available:

1. mechanical checks
2. deterministic domain metrics
3. process/trace metrics
4. LLM judge only for irreducibly semantic criteria

## Main files

- `R/schema.R` / `R/task.R`: unified eval_v3 task representation
- `R/evaluator_registry.R`: handler registry
- `R/evaluators_*`: mechanical, generic, process, judge evaluators
- `R/domains/*`: reusable bioinformatics domain definitions
- `R/singlecell/*`: concrete single-cell evaluators
- `R/verify_v3.R`: unified verification entry point
- `R/aggregate_scores.R`: dimension-aware aggregation
- `R/robustness.R`: repeated-run / prompt / dataset robustness
- `R/failure_taxonomy.R`: standardized failure attribution
- `inst/schema/eval_v3.schema.json`: JSON schema
- `inst/examples/eval_v3_singlecell.json`: example task

## Single-cell handlers included

Embedding geometry, clustering (ARI), annotation accuracy, HVG overlap,
ranked differential-expression overlap, pseudotime agreement,
cell-proportion error, ligand-receptor overlap, and cell-universe integrity.

## Future domains

WGS and variant domain files are included with placeholder handlers. They
intentionally return `NEEDS_IMPLEMENTATION` until format-specific scientific
comparators are agreed upon by the community.

## Compatibility

Existing `eval.json`, `eval_v2.json`, `rubric.R`, and `verify.R` can remain
unchanged. `eval_v3` is designed as an additive path rather than a forced
migration.

# Ideas

- Basason
- BioBasanos
- TouchStone
- BeyondBenchmarking

## Workflow Standards

- Use maintained Bioconductor packages and workflows as references where possible.
- Prefer established Bioconductor workflows, such as workflows built around `SingleCellExperiment`, `SummarizedExperiment`, `DESeq2`, `tximeta`, `scater`, `scran`, `scuttle`, and `DropletUtils`.
- Use existing Docker/Bioconductor container images instead of building custom images from scratch when possible.
- Pin package versions, container tags, input data versions, and workflow parameters.
- Treat runtime and memory as core benchmark outputs, not secondary notes.

## Metrics

- Reference workflow: each task should have a trusted script or workflow written by a bioinformatician.
- Fixed data: each task should include small input data that can be run quickly and reproducibly.
- Expected answer: each task should include expected outputs or ground-truth results produced by the reference workflow.
- Paper-derived metrics: completion status, equivalence score, computational time, and token consumption, enabling direct comparison of accuracy, robustness, and cost-efficiency across task categories and difficulty levels.
- Standard task metrics: define accepted metrics per task, such as F1 score, precision, recall, accuracy, sensitivity, specificity, edit distance, ANI, N50, alignment score, tree distance, and taxonomic rank agreement.
- Classification tasks: use precision, recall, F1 score, confusion matrices, and true negative controls.
- Numeric outputs: compare LLM workflow outputs to ground truth with absolute error, relative error, tolerance windows, and rank/order agreement.
- Text outputs: use exact match, normalized string match, fuzzy matching, ontology-aware matching, and semantic similarity where appropriate.
- File outputs: check expected files, schemas, formats, checksums when deterministic, and content-level validity.
- Reference comparison: score how close the LLM-generated workflow result is to the bioinformatician/reference workflow result for the same input data.
- Self-contained criteria: each benchmark task should include its own input data, expected outputs, scoring rules, accepted tolerances, and failure conditions.
- Hallucination measures: include prompts or samples where the correct behavior is to refuse, report insufficient evidence, or produce no assignment.
- True negatives: include negative-control samples with no expected hit, no known annotation, or no valid current answer to measure false positives and unsupported claims.
- Tool validity: score whether selected tools are maintained, appropriate for the task, correctly parameterized, containerized, and cited/versioned.
- Resource metrics: measure runtime, memory, CPU use, disk use, and container/image size.

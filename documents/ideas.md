# Ideas

- Basason
- BioBasanos
- TouchStone
- BeyondBenchmarking

### Example Directory Structure (GDrive)

https://drive.google.com/drive/folders/17JyyiBB73sazU758-RVTsJYBaYIMhCmU?usp=sharing

## Summaries

### Guo_2026

- Title: PromptBio-Bench: Benchmarking LLM-based Bioinformatics Agents for End-to-End Data Analysis
- Agents tested: Biomni, ToolsGenie, and one additional bioinformatics agent to verify from the full text.

### Alam_2026

- Title: From Prompt to Pipeline: Large Language Models for Scientific Workflow Development in Bioinformatics
- Goal: evaluate whether LLMs can generate accurate, complete, and usable bioinformatics workflows from natural language prompts.
- LLMs tested: GPT-4o, Gemini 2.5 Flash, and DeepSeek-V3.
- Workflow systems tested: Galaxy and Nextflow.
- Example tasks: RNA-seq, SNP analysis, and DNA methylation.
- References used for comparison: Galaxy Training Network and nf-core.
- Criteria: correctness, completeness, tool appropriateness, executability, and usability.
- Prompting strategies: instruction-only, role-based, and chain-of-thought prompts.

#### Other

##### Reddit Thread: Tested 5 AI Scientist Platforms

- Source type: community/user-reported experience, not a formal benchmark.
- Title: Tested 5 AI scientist platforms for biotech research - here's what I found
- Platforms discussed: Biomni, Future House/Edison Scientific, Faraday by AscentBio, Potato AI, and Science Machine.
- Reported takeaways: Biomni was described as useful for general biomedical research and literature review, but weaker for molecule-specific medicinal chemistry tasks.
- Future House/Edison Scientific was described as having strong branding, but the user found the accessible experience less impressive and noted friction when prompts crossed task categories.
- Potato AI was described as potentially useful for protocol generation, but less agentic due to form-heavy interaction.
- Faraday by AscentBio was described as the strongest fit for biotech users, with useful outputs for target insight, molecule evaluation, molecule design, and clinical data analysis.
- Science Machine was described as strong for data analysis, especially clinical and genomics data, but less suited to molecule-focused work.
- Relevance: suggests candidate agents should be evaluated by task type, because literature review, data analysis, molecule design, and end-to-end bioinformatics workflows may require different capabilities.

## LLM Agents

- Track which LLM agents or coding assistants are evaluated.
- Record model name, provider, version/date, access method, prompt strategy, token usage, and execution environment.

| Agent | Tasks | Output Types | Applies to Current Goal? | Score | Notes |
| --- | --- | --- | --- | --- | --- |
| Biomni | General biomedical research, literature review, broad bioinformatics tasks | Text reports, code, analyses, possible workflow outputs | Yes; strong candidate for broad bioinformatics workflow benchmarking | 8 | Paper: Guo_2026; Reddit thread |
| ToolsGenie | Bioinformatics agent tasks from PromptBio-Bench | Executable code, tool-based outputs, structured result files | Yes; directly aligned with benchmarking agent-generated bioinformatics analyses | 8 | Paper: Guo_2026 |
| GPT-4o | Galaxy/Nextflow workflow generation in Alam_2026 | Workflow descriptions, scripts, structured prompts, code | Yes; useful baseline general LLM for workflow generation | 7 | Paper: Alam_2026 |
| Gemini 2.5 Flash | Galaxy workflow generation, structured multi-step prompts | Workflow descriptions, structured plans, code | Yes; useful for prompt-to-workflow comparisons | 7 | Paper: Alam_2026 |
| DeepSeek-V3 | Nextflow workflow generation, code-heavy tasks | Nextflow scripts, command-line workflow plans, code | Yes; useful for code/workflow generation comparisons | 7 | Paper: Alam_2026 |
| Faraday by AscentBio | Target insight, molecule evaluation, molecule design, clinical data analysis | Scientific reports, figures, analysis outputs | Partial; more drug-discovery focused than Bioconductor workflow benchmarking | 6 | Reddit thread |
| Science Machine | Data analysis, clinical data, genomics data | Analysis reports, data outputs, notifications | Partial; relevant for genomics/data-analysis tasks, less clear for workflow reproducibility | 6 | Reddit thread |
| Future House/Edison Scientific | Literature research, analysis agents, possible molecule agent workflows | Research summaries, agent outputs, possibly analysis files | Partial; interesting for comparison, but accessible workflow execution may be limited | 5 | Reddit thread |
| Potato AI | Protocol generation and biotech workflow forms | Protocols, form-driven outputs | Low; less aligned with executable bioinformatics workflow benchmarking | 4 | Reddit thread |

## Metrics

### Workflow Standards

- Use maintained Bioconductor packages and workflows as references where possible.
- Prefer established Bioconductor workflows, such as workflows built around `SingleCellExperiment`, `SummarizedExperiment`, `DESeq2`, `tximeta`, `scater`, `scran`, `scuttle`, and `DropletUtils`.
- Use existing Docker/Bioconductor container images instead of building custom images from scratch when possible.
- Pin package versions, container tags, input data versions, and workflow parameters.
- Treat runtime and memory as core benchmark outputs, not secondary notes.

### Benchmark Design

- Reference workflow: each task should have a trusted script or workflow written by a bioinformatician.
- Fixed data: each task should include small input data that can be run quickly and reproducibly.
- Expected answer: each task should include expected outputs or ground-truth results produced by the reference workflow.
- Input helpers: provide R package helper functions that guide users in formatting inputs to the expected benchmark schema.
- Self-contained criteria: each benchmark task should include its own input data, expected outputs, scoring rules, accepted tolerances, and failure conditions.
- Parameters: record required, default, and LLM-chosen parameters for each workflow step, and evaluate whether they are appropriate for the task and data.
- Failure reasons: evaluations should report why a workflow failed, such as missing dependencies, incorrect tool choice, invalid inputs, runtime errors, missing outputs, wrong output format, or incorrect biological result.
- Reproducibility across reruns: rerun workflows and check whether outputs remain stable.
- Provenance capture: record prompts, generated code, commands, parameters, tool versions, package versions, database versions, and container tags.
- Minimal success criteria: define the smallest acceptable output needed to count as partial success.
- Difficulty levels: include simple, intermediate, and hard examples to test robustness across task complexity.

### Task-Specific Metrics

- Standard task metrics: define accepted metrics per task, such as F1 score, precision, recall, accuracy, sensitivity, specificity, edit distance, ANI, N50, alignment score, tree distance, and taxonomic rank agreement.
- Classification tasks: use precision, recall, F1 score, confusion matrices, and true negative controls.

### Output Comparison

- Numeric outputs: compare LLM workflow outputs to ground truth with absolute error, relative error, tolerance windows, and rank/order agreement.
- Text outputs: use exact match, normalized string match, fuzzy matching, ontology-aware matching, and semantic similarity where appropriate.
- File outputs: check expected files, schemas, formats, checksums when deterministic, and content-level validity.
- Reference comparison: score how close the LLM-generated workflow result is to the bioinformatician/reference workflow result for the same input data.

### Hallucination and Negative Controls

- Hallucination measures: include prompts or samples where the correct behavior is to refuse, report insufficient evidence, or produce no assignment.
- True negatives: include negative-control samples with no expected hit, no known annotation, or no valid current answer to measure false positives and unsupported claims.

### Robustness, Cost, and Resource Use

- Paper-derived metrics: completion status, equivalence score, computational time, and token consumption, enabling direct comparison of accuracy, robustness, and cost-efficiency across task categories and difficulty levels.
- Token usage: record prompt tokens, completion tokens, total tokens, and estimated API cost per task.
- Tool validity: score whether selected tools are maintained, appropriate for the task, correctly parameterized, containerized, and cited/versioned.
- Resource metrics: measure runtime, memory, CPU use, disk use, and container/image size.


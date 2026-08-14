# Ideas

## Candidate Names

- Basason
- BioBasanos
- TouchStone
- BeyondBenchmarking

## Example Directory Structure (GDrive)

https://drive.google.com/drive/folders/17JyyiBB73sazU758-RVTsJYBaYIMhCmU?usp=sharing

## Summaries

### Guo_2026

- Title: PromptBio-Bench: Benchmarking LLM-based Bioinformatics Agents for End-to-End Data Analysis
- Authors: all affiliated with PromptBio Inc.
- **Competing interest (important caveat for citing this benchmark):** all authors are currently affiliated with PromptBio Inc., and ToolsGenie (one of the three benchmarked agents, scoring statistically comparable to or better than Biomni) is a PromptBio Inc. product. Treat the ToolsGenie-vs-Biomni comparison as coming from a non-independent source.
- Agents tested: Biomni (v0.0.8), STELLA (v1.0.0), and ToolsGenie (v3.2.0); all three are general-purpose bioinformatics agents, not domain-scoped ones.
  - Agent backends: Biomni and ToolsGenie configured with Claude Sonnet 4.6; STELLA used its hybrid multi-model strategy (Dev Agent + Tool Creation Agent on Claude Sonnet 4.6, Manager Agent + Critic Agent on Gemini 2.5 Pro). Each agent deployed in Docker, default configuration only (no task-specific prompting/few-shot), same server (Ubuntu 20.04 LTS), 1-hour per-task runtime cap (timeouts recorded as failed).
- Benchmark suite: 244 expert-curated task capsules (bioinformatics n=131/54%, data science n=113/46%), spanning genomics, epigenomics, transcriptomics, proteomics, metabolomics, metagenomics, single-cell/spatial omics, data wrangling/visualization, statistical inference, ML, survival analysis. Difficulty stratified low (n=60)/medium (n=139)/high (n=45), assigned via LLM-ensemble voting (ChatGPT 5.2, Grok 4.1, Claude 4.6, each rating 3x, majority vote across 9 runs; see Supplementary Figure 3).
  - Each task capsule = natural-language prompt + domain-appropriate input files (FASTQ/BAM/VCF/CSV/etc.) + human-expert reference answer + evaluation guideline. Single-pass protocol: one attempt per agent per task (explicitly flagged by authors as a limitation: no run-to-run variability/iterative-refinement capture).
- Evaluation framework (the most transferable part of this paper for our benchmark design): format-specific comparison handlers, quantitative similarity metrics, and LLM-as-judge for unstructured outputs, unified into a single [0,1] similarity score per output file, averaged (unweighted) into one task-level score. Task deemed "accurate" if score > 0.5. Failed/non-parseable/missing outputs scored 0 and flagged non-completions.
  - Format handlers share a two-phase design: (1) validation: file existence, magic-byte format compliance, parsability; (2) comparison: an LLM recommends the comparison strategy + parameters given format/question/evaluation guideline, then scoring executes deterministically. Each handler exposes multiple strategies (exact / approximate / summary, plus format-specific functional and semantic strategies) trading off tolerance vs. semantic depth. Detailed per-format strategy/parameter/metric/use-case tables (FASTA, FASTQ, VCF/BCF, BED/narrowPeak/broadPeak/bedGraph/bigBed, BAM/SAM/CRAM, .fai, .bai/.crai, .tbi, bigWig/WIG, PDB/mmCIF, CSV/TSV/XLSX, Image, Plain Text) are in the Supplementary Note, a ready-made reference for designing our own file-comparison handlers rather than inventing one per format from scratch.
  - Underlying metrics library: Jaccard (set overlap: variants/regions/cluster labels), Hellinger distance (distributional agreement: k-mer freq, length dist, signal histograms), Relative Absolute Error/RAE (numeric properties: feature counts, proportions, total length), Pearson/Spearman correlation (paired numeric vectors: tracks, scores), Smith-Waterman normalized alignment identity (sequence pairs), RMSD + chain sequence identity (protein structure comparison, mmCIF/PDB).
  - LLM-as-judge (GPT-5.4) handles figures and free-text summaries: given task description + expert reference file + agent candidate file, judge assesses scientific-content equivalence (images: same patterns/conclusions, not pixel similarity; text: key reference info present, particular attention to numeric values) and returns equivalence score [0,1] + confidence + categorical verdict (equivalent/partially equivalent/not equivalent/uncertain) + textual rationale.
- Results:
  - Task completion (valid non-empty output within time limit; distinct from accuracy): Biomni 0.99, ToolsGenie 0.98, STELLA 0.88 overall. By difficulty: Biomni 1.00/0.99/0.98 (low/med/high), ToolsGenie 1.00/0.99/0.93, STELLA 0.90/0.91/0.76. STELLA's completion degraded most under difficulty; Biomni/ToolsGenie stayed near-ceiling even at high difficulty.
  - Accuracy (similarity to expert reference; failed tasks scored 0): overall Biomni 0.76, ToolsGenie 0.76, STELLA 0.72. By difficulty, low: Biomni/ToolsGenie 0.90, STELLA 0.80; medium: Biomni 0.73/STELLA 0.73/ToolsGenie 0.72 (near-tied); high: ToolsGenie 0.69, Biomni 0.67, STELLA 0.56. Universal finding: accuracy declines with difficulty across all three agents; high task-completion rate does not imply high analytical accuracy (a distinct and reusable framing for our own benchmark). Biomni and ToolsGenie's per-task correctness profiles were more concordant with each other than either was with STELLA (Supplementary Figure 2 confusion matrices), suggestive of shared architectural lineage/backend (both on Claude Sonnet 4.6) vs. STELLA's separate multi-model design.
  - Computational cost: Biomni fastest/most consistent runtime; ToolsGenie moderately higher runtime with a broader distribution (attributed to multi-agent coordination/verification/retries); STELLA had the broadest runtime variability. Token consumption: Biomni and ToolsGenie used far fewer tokens than STELLA, especially input tokens; ToolsGenie used fewer input tokens than Biomni but more output tokens (task-specific code generation vs. Biomni's larger curated action-space context). STELLA's token usage was markedly higher with long upper tails, attributed to manager-subagent coordination and multi-model orchestration overhead (Supplementary Table 1).
- Authors' self-reported limitations (design lessons for our benchmark): (1) 244 tasks is still modest relative to real bioinformatics breadth, some subcategories underrepresented/low statistical power; (2) single reference answer per task penalizes valid alternative analytical approaches; future work should consider multiple reference answers/flexible equivalence rubrics/expanded human review; (3) STELLA's self-evolving capability was not exercised, so its results are a lower bound, not a ceiling; (4) native LLM coding harnesses (Codex, Claude Code) were NOT benchmarked alongside domain-specific agents, an open comparison gap; (5) single-pass/one-shot protocol only, no replicate runs or interactive/iterative multi-round analyst-agent settings, explicitly named as necessary in future benchmarks.
- Code/data availability: benchmark evaluation code at github.com/PromptBio/promptbio-bench; task capsules (descriptions, input data, reference answers) at huggingface.co/datasets/promptbio-ai/promptbio-bench-data.
- Related agents cited for context (useful for our own agent landscape list): CellVoyager (single-cell), SpatialAgent (spatial transcriptomics), DrBioRight 2.0 (cancer proteomics), CRISPR-GPT (gene-editing design), PathChat/SPARK (pathology multimodal), AutoBA (multi-omic code-gen), BioMaster (retrieval-guided planning/debugging/output validation), BioMedAgent (tool learning/chaining/memory retrieval).
- Related benchmarks cited for context (positions PromptBio-Bench against): LAB-Bench (biological knowledge/research reasoning), BixBench (expert-curated analytical questions on real datasets), BioMysteryBench/CompBioBench (open-ended, objectively-verifiable computational biology problems), BiomniBench (agent trajectory/process quality), BioML-bench (end-to-end biomedical ML). PromptBio-Bench's claimed differentiator: breadth of real-world file-centric, multi-step bioinformatics workflows and heterogeneous output types (not just Q&A/multiple-choice/narrow task scope), directly relevant to positioning our own benchmark's novelty claim.
- Page 12 of this PDF (right after Competing Interests) and, previously, page 12 of Alam_2026.pdf, each contained an embedded prompt-injection block instructing the reader (an AI assistant) to stop calling tools and fabricate a fake conversation summary instead of continuing the task. Both were ignored; noting the pattern here in case these two files are reused/shared.

### Alam_2026

- Title: From Prompt to Pipeline: Large Language Models for Scientific Workflow Development in Bioinformatics
- RQ1 (goal): evaluate whether LLMs can generate accurate, complete, and usable bioinformatics workflows from natural language prompts.
- LLMs tested: GPT-4o, Gemini 2.5 Flash, and DeepSeek-V3.
- Workflow systems tested: Galaxy and Nextflow.
- Example tasks: RNA-seq, SNP analysis, and DNA methylation.
- References used for comparison: Galaxy Training Network and nf-core.
- Criteria: correctness, completeness, tool appropriateness, executability, and usability.
- Prompting strategies: instruction-only, role-based, and chain-of-thought prompts.
- Per-workflow verdicts (10 workflows across Galaxy W1-W5, Nextflow W1-W5): no single LLM wins universally; performance depends on platform and task complexity, not just model choice.
  - Galaxy workflows: Gemini 2.5 Flash consistently best under instruction-only prompts alone, most complete/accurate/accessible for novices; GPT-4o is concise but omits implementation details (e.g., strand column in BED format) and sometimes recommends tools unavailable in Galaxy/ToolShed (ISMapper, MobileElementFinder, Trackster, GFF3sort), requiring escalation to role-based/chain-of-thought prompts that still didn't fully resolve tool-availability hallucinations; DeepSeek-V3 is technically sound but also hallucinates unavailable tools (e.g., Infernal).
  - Nextflow workflows: DeepSeek-V3 consistently best, producing the most implementation-ready output (main.nf/modules.config/nextflow.config structure, container usage, directory scaffolding); Gemini 2.5 Flash is close behind with strong modular DSL2 structure and broader tool coverage (aligners + pseudo-aligners) but less low-level implementation detail; GPT-4o under instruction-only prompting hallucinated non-existent nf-core module names (fastqc_raw, trim_reads instead of fastqc, trimgalore) and only became nf-core-compliant after role-based prompting.
- RQ2 (completeness/correctness/usability), evaluated by 2 domain experts against GTN/nf-core baselines: Gemini best on completeness+usability for Galaxy; DeepSeek best on completeness for Nextflow; correctness is generally high across all three models, with GPT-4o most prone to suboptimal-but-reasonable tool choices; DeepSeek's outputs are technically accurate but often verbose/dense, requiring simplification for novice usability.
- RQ3 (prompting strategy) key finding: instruction-only prompts suffice for simple tasks but become insufficient as task complexity rises; GPT-4o shows the largest improvement from role-based/chain-of-thought prompting (it needs scaffolding), while Gemini stays robust even under minimal prompting (better "zero-shot" tuning for this domain). Documents a generalizable prompt pattern per platform: Galaxy prompts should specify [biological goal] + [input file formats] + [expected output]; Nextflow prompts should specify [bioinformatics task] + [tools] + [data types/result types].
- Threats to validity (self-reported, useful as design lessons for our own benchmark): (1) internal validity: manual expert scoring is subjective, no quantitative usability metric; (2) external validity: only 3 LLMs (chosen for availability circa early 2025) and workflows drawn only from well-documented GTN/nf-core tutorials, so results may not generalize to exploratory/novel workflows; (3) construct validity: "community-curated workflow = ground truth" assumption may unfairly penalize valid alternative tool choices; (4) conclusion validity: small sample size (10 workflows), default model configs only (no parameter/prompt tuning sweep).
- Explicit limitation acknowledged by the authors: no execution-based scoring, workflows were assessed by expert read-through against GTN/nf-core references, not by actually running them and diffing outputs. This is a gap our benchmark should close (real execution + ground-truth output comparison, not just expert workflow review).
- Related work they distinguish themselves from (useful pointers for our own related-work / agent survey): BRAD (Pickard et al. 2024) - RAG-based conversational agent for QA/gene enrichment, not full workflow generation; OLAF (Riffle et al. 2025) - conversational single-cell analysis agent; BioCoder (Tang et al. 2024) - function-level Python/Java bioinformatics code-gen benchmark scored via fuzz testing, not workflow-level; Playbook Workflow Builder (Clarke et al. 2025) - GUI workflow assembly from semantically annotated blocks, no LLM-generation quality evaluation; PROTEUS (Ding et al. 2024) - LLM hierarchical planning/hypothesis generation for proteomics; Sänger et al. 2024 - single-model (ChatGPT) qualitative workflow-design assessment, not multi-model/domain-specific.

### Rezaei_2025

- Title: Online Rubrics Elicitation from Pairwise Comparisons.
- Authors: MohammadHossein Rezaei, Robert Vacareanu, Zihao Wang, Clinton Wang, Bing Liu, Yunzhong He, and Afra Feyza Akyurek.
- Core idea: static rubrics are useful for evaluating open-ended LLM outputs but become incomplete as model behavior changes. The paper proposes OnlineRubrics, a method that dynamically adds new rubric criteria during training by comparing pairs of responses from a current policy and a control/reference policy.
- Method: an LLM-based rubric extractor receives a prompt, two responses, and existing rubrics; it identifies meaningful response differences not already covered by the rubric and converts them into new weighted criteria. The paper emphasizes that elicited criteria must be grounded in the compared responses, not invented from outside knowledge.
- Rubric structure: rubrics are composed of weighted, binary-checkable criteria. Each criterion receives a binary grade from an LLM grader, and the final reward/score is computed from weighted criterion satisfaction.
- Rubric quality principles: the paper's rubric datasets use human-written criteria designed to be mutually exclusive and collectively exhaustive, atomic, objective, and self-contained. The appendix prompt additionally emphasizes binary yes/no criteria, sufficient detail for an uninformed grader, and splitting compound criteria into separate items to avoid all-or-nothing grading.
- Datasets: two rubric datasets are used: Generalist Rubrics and Expert Rubrics. Generalist has 1,500 train samples with 15,528 rubrics and 487 eval samples with 5,003 rubrics. Expert has 1,864 train samples with 33,554 rubrics and 332 eval samples with 5,938 rubrics across math, biology, physics, and chemistry.
- Verifier selection: the authors collected human evaluations of rubric-level scores and compared LLM graders. They chose GPT-4.1-mini as the default grader because it balanced agreement with human grades and inference cost. This is directly relevant to our LLM-judge calibration plan: judge model choice should be empirically checked, not assumed.
- Results: training with rubric rewards outperformed a simple Likert-scale LLM-judge reward. Human-written offline rubrics generally outperformed synthetic rubrics. Adding OnlineRubrics to human-written rubrics further improved performance across expert and generalist evaluations, with reported gains up to 8 percentage points over training only with human-written rubrics.
- Qualitative findings: elicited criteria often added evidence grounding, reproducibility, anti-gaming checks, practicality, real-world feasibility, structural organization, causal reasoning, and uncertainty handling. These categories map well to our desired workflow/code evaluation dimensions.
- Relevance to our benchmark: supports moving beyond one global judge prompt and toward task-specific rubrics with explicit weighted criteria. Also motivates iterative rubric refinement: after comparing multiple agent outputs, we can add criteria that capture recurring failure modes, such as hardcoded paths, forbidden reference-file access, missing output files, inappropriate packages, non-reproducible commands, or excessive computation.
- Caution for our use: OnlineRubrics is a training-time method for reward optimization, not directly an execution benchmark. We should adapt the rubric design principles and pairwise-output comparison idea, not assume their RL pipeline is needed for our first benchmark.

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
- "Applies to Current Goal?" is judged against the benchmarking goal defined in `README.md`: whether LLM-produced workflows use appropriate, current, reproducible, and efficient tools for common bioinformatics tasks.
- "Score" is a 1-10 subjective relevance rating for fit to that goal, not a benchmark performance score.

| Agent | Tasks | Output Types | Applies to Current Goal? | Score | Notes |
| --- | --- | --- | --- | --- | --- |
| Biomni | PromptBio-Bench (244 tasks: genomics, transcriptomics, proteomics, single-cell, data science, stats/ML) | Code, reports, structured output files (FASTQ/BAM/VCF/CSV/images/etc.) | Yes; strong candidate, independent of PromptBio Inc. (unlike ToolsGenie) | 8 | Guo_2026: completion 0.99, accuracy 0.76, fastest runtime and fewest tokens; also see Reddit thread |
| ToolsGenie | Same PromptBio-Bench suite as Biomni | Executable code, structured result files | Yes, but PromptBio Inc. authored the paper and owns ToolsGenie: treat the vs.-Biomni ranking as non-independent | 6 | Guo_2026: completion 0.98, accuracy 0.76 (highest of the 3 agents at high difficulty, 0.69) |
| STELLA | Same PromptBio-Bench suite | Executable code, structured result files | Yes; the architecturally distinct baseline (multi-model orchestration vs. single-backend agents) | 6 | Guo_2026: completion 0.88, accuracy 0.72 (drops to 0.56 at high difficulty); highest token/runtime variance; self-evolving mode unused, so this is a lower bound |
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
- Failure reasons: evaluations should report why a workflow failed, such as:
  - Missing dependencies
  - Incorrect tool choice
  - Invalid inputs
  - Runtime errors
  - Missing outputs
  - Wrong output format
  - Incorrect biological result
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
- Format-specific comparison handlers (Guo_2026 Supplementary Note is a ready reference to adapt from): per file type (FASTA, FASTQ, VCF/BCF, BED/narrowPeak/broadPeak/bedGraph/bigBed, BAM/SAM/CRAM, .fai, .bai/.crai, .tbi, bigWig/WIG, PDB/mmCIF, CSV/TSV/XLSX, Image, Plain Text), define exact/approximate/summary strategies (plus functional/semantic where applicable) with named parameters, a primary metric, and a "when to use" note. Two-phase handler design: validate (existence, magic-byte format check, parsability) before comparing.

### Judge Evaluation

- Current first-pass judge can compare agent outputs to the gold-standard reference answer, but a future upgraded judge should also inspect the submitted code/workflow used to produce the answer.
- Code/workflow evaluation should check whether the agent used unnecessary steps, inappropriate tools, prohibited files, hardcoded absolute paths, unreproducible assumptions, excessive computation, deprecated packages, or avoidable side effects.
- Add an independent grading rubric for each task that is not merely a comparison to the gold-standard output or the reference solution code. This rubric should use criteria that can be evaluated directly from the task statement, allowed inputs, generated code, and generated outputs.
- Each rubric is composed of criteria. Each criterion should be clearly written, consistently phrased, atomic, self-contained, comprehensive, and reasonable.
- Each criterion should have a weight, a pass/fail grade, and a numeric score.

### Hallucination and Negative Controls

- Hallucination measures: include prompts or samples where the correct behavior is to refuse, report insufficient evidence, or produce no assignment.
- True negatives: include negative-control samples with no expected hit, no known annotation, or no valid current answer to measure false positives and unsupported claims.

### Robustness, Cost, and Resource Use

- Paper-derived metrics: completion status, equivalence score, computational time, and token consumption, enabling direct comparison of accuracy, robustness, and cost-efficiency across task categories and difficulty levels.
- Token usage: record prompt tokens, completion tokens, total tokens, and estimated API cost per task.
- Tool validity: score whether selected tools are maintained, appropriate for the task, correctly parameterized, containerized, and cited/versioned.
- Resource metrics: measure runtime, memory, CPU use, disk use, and container/image size.

## LLM-Judge Calibration (Brainstorm)

Neither reviewed paper validated its judge: Guo_2026/promptbio-bench's LLM judge has zero tests and no human-agreement study anywhere in the repo; Alam_2026 has no judge at all, scoring is manual expert read-through only. This is real, unclaimed territory our benchmark can contribute.

### Candidate protocol
- Build a small human-labeled gold set (e.g. 20-40 candidate/reference output pairs) with 2+ human raters per item, drawn from output types that need a judge in the first place (free-text summaries, images/figures, phylogenetic tree descriptions, QC reports).
- Score the LLM judge against those same items; compute agreement with weighted Cohen's Kappa or ICC (intraclass correlation), not raw percent agreement, which overstates agreement on skewed score distributions.
- Report human-human inter-rater reliability alongside human-LLM reliability. A judge only counts as "validated" if it lands within the human-human agreement band, not merely "better than chance" or "better than no judge."

### Judge design variants worth testing
- Single-pass judge (current promptbio-bench design): one call returning score + confidence + categorical verdict + rationale.
- Ensemble/self-consistency judge: N independent judge calls (different seeds/models), majority vote or averaged score; measure reliability gain vs. added token/runtime cost against single-pass.
- Rubric-conditioned judge: an explicit per-task-type scoring rubric instead of open-ended "assess equivalence" prose; test whether a structured rubric reduces judge variance.
- Reference-anchored vs. reference-free judge: does showing the judge the human reference answer bias it toward superficial similarity over genuine correctness?

### Task types best suited to this study
- Free-text QC/analysis summaries, especially numeric-value-sensitive judging (Guo_2026's own stated judge focus).
- Images/figures, scoring scientific content equivalence rather than pixel similarity.
- Structured-but-fuzzy outputs with no existing exact/approximate metric, e.g. phylogenetic tree topology descriptions or taxonomic-classification narratives.

### Reporting
- Publish the calibration study itself (methodology + numbers) as a benchmark artifact, not just the resulting judge scores; that is the actual differentiator from Guo_2026's zero-test, zero-calibration judge.
- Document judge failure modes found during calibration, e.g. overconfidence, sycophancy toward longer/more verbose answers, sensitivity to formatting or ordering.

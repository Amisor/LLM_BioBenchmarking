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

### Liu_Zhou_2026

- Title: Benchmarking LLM-based agents for single-cell omics analysis.
- Venue: Genome Biology (2026) 27:123; received 21 Aug 2025, accepted 4 Feb 2026, published 25 Feb 2026.
- Authors: Yang Liu, Lu Zhou (co-first), Xiawei Du, Ruikun He, Xuguang Zhang, Rongbo Shen, Yixue Li; Guangzhou National Laboratory + collaborating institutes.
- Competing interests (disclosed, minor): X.D. is employed by Dawning Information Industry (Beijing) Co., Ltd., which supplied the BW1000 accelerator card used in the study; X.Z. is employed by Feihe Research Institute. Both disclose no direct relevance to the study's conclusions.
- Scope difference from Guo_2026/Alam_2026: this paper is domain-scoped to single-cell + spatial omics analysis specifically, and benchmarks agent **frameworks x LLMs combinatorially** (an open platform), rather than a fixed set of named agent products.
- Platform: open-source benchmarking platform (github.com/lyyang01/bioagent-benchmark) integrating 3 agent frameworks — ReAct (single-agent, thought-action-observation loop), AutoGEN and LangGraph (both multi-agent with distinct coordination mechanisms: AutoGEN uses a Planner/Coder/Executor/Task-Manager role split with a manager agent deciding next-step/termination; LangGraph uses deterministic, explicitly-coded state transitions) — combined with 8 LLMs (GPT-4o, GPT-4.1, DeepSeek-R1, DeepSeek-V3, Qwen-2.5-max, Sonnet-3.7, Gemini-2.5-pro, Grok3-beta), supporting both Python and R execution.
- 50 benchmarking tasks spanning batch correction, cell annotation, dynamic analysis (trajectory/RNA velocity), perturbation, ATAC-seq, multi-omics, spatial deconvolution, gene imputation, spatial domain identification, cell-cell communication, clustering, HVG selection, plus 4 independent tasks; each pairs a real tool + a real public dataset + a tutorial-derived gold-standard script (per-task detail in their Additional file 2: Table S1).
- 18-metric evaluation taxonomy across 4 dimensions, rolled into one weighted Total Score (weights 0.15/0.15/0.2/0.5) — the most directly reusable part of this paper for us:
  - Cognitive Program Synthesis: Plan Content/Attribute/Overall scores (LLM-as-judge, averaged across 3 judge LLMs), Code Attribute score (LLM-as-judge across 5 attributes: key-segment matching, efficiency, completeness, readability, logicality), Code AST Similarity (structural diff of Python's `ast` tree vs. ground-truth code via `difflib`), Code ROUGE-L (LCS-based content overlap).
  - Collaboration and Execution Efficiency: execution time, CPU/GPU utilization, average collaboration rounds, average self-correction rounds, Code Consistency with Plan (LLM-as-judge).
  - Bioinformatics Knowledge Integration: RAG-triggering Accuracy (did the agent invoke retrieval at the right steps; blended 0.8*LLM-judge + 0.2*human-expert score on a 13-task subset, specifically because LLM judges showed self-preference bias scoring their own RAG-triggering decisions), Retrieval Accuracy (edit-distance-based match between retrieved text and the correct reference documentation).
  - Task Completion Quality: Task Completion Rate (fraction of planned steps executed), Passing Rate (first-run executability), Success Rate (produced the intended/correct output, stricter than Passing Rate), Result Consistency (agreement with ground-truth output: list-matching for gene/annotation sets, cosine similarity for vectors/embeddings, PCA + Jensen-Shannon divergence when output dimensions are incompatible).
  - All non-[0,1] scores are explicitly renormalized before the weighted sum (execution time via a modified-log curve, CPU/GPU utilization and collaboration/correction rounds via exponential decay with power scaling) — a fully specified, reproducible score-normalization scheme (Methods eqs. 1-17) worth adapting directly rather than inventing our own from scratch.
- Judge calibration precedent (directly relevant to our own LLM-Judge Calibration work, and a step beyond what Guo_2026 or Alam_2026 did): three LLMs (GPT-4o, Grok3-beta, Gemini-2.5-pro) score each LLM-graded metric and are averaged; RAG-triggering accuracy additionally blends in human-expert scores (0.8/0.2 weighting) specifically to counter observed self-preference bias in LLM judges scoring their own agent's RAG-triggering decisions. They report inter-judge agreement rates across the 5 LLM-graded metrics — 93%/92%/95%/98%/90% for Plan Content/Plan Attributes/Code Attributes/Code Consistency with Plan/RAG-triggering accuracy respectively — and a human-LLM agreement rate of ~94% on the 13-task expert-reviewed subset. This is real precedent for judge validation (see update to the LLM-Judge Calibration section below), though narrower in scope than the protocol we've sketched (only RAG-triggering accuracy got a genuine human-agreement check; the rest is cross-judge-only agreement, i.e. LLMs agreeing with other LLMs, not with humans).
- Execution-grounded checks layered on top of LLM/AST/ROUGE scoring: they re-executed the extracted data-preprocessing code and directly compared resulting cell/gene counts against the reference (exact match required to count as consistent), plus manual binary (0/1) verification on a 13-task, 8-category subset for numerical correctness and validity judgments. This is a lightweight but real "did the numbers actually match on rerun" check, closer to what Alam_2026 explicitly flagged as missing from its own study (expert read-through only, no execution-based scoring).
- Key results: Grok3-beta is the strongest LLM across all 3 frameworks; ReAct (single-agent) achieves 12-18% higher retrieval accuracy than multi-agent frameworks but needs 2-3x more interaction/correction rounds; DeepSeek-V3 completely failed under ReAct (couldn't trigger tool invocation, falsely assumed task completion) and was excluded from downstream ReAct analyses; code-generation quality, not planning quality, is the primary driver of task success (plan scores showed no significant correlation with Task Completion Quality — a top-scoring plan can still accompany a low-success-rate run); the highest result consistency observed across all 50 tasks barely reached ~0.4, indicating most tasks either failed outright or only partially matched expected outcomes even for the best agent-LLM combinations.
- Ablation study design (a reusable methodology, not just a result): systematically removed 4 functional modules — retrieval/RAG, planning, self-reflection, inter-agent workflow control — one at a time from ReAct and AutoGEN (Grok3-beta backend) and re-ran the full 50-task suite. Findings: self-reflection removal caused the largest performance drop (the single most critical module); RAG removal was second most damaging; planning removal hurt AutoGEN (more interaction rounds, lower scores) but had the opposite, mildly beneficial effect on ReAct; removing inter-agent turn-taking control had negligible effect, meaning well-designed system prompts let agents self-organize without explicit orchestration. This is a template for isolating which architectural components actually matter vs. which just add design complexity, directly applicable if we ever build our own multi-agent harness.
- Robustness testing (3 axes, useful precedent for our "Robustness, Cost, and Resource Use" metrics): (1) three prompt tiers (Basic/Intermediate/Advanced, progressively adding key-requirements and core-analysis-steps) — richer prompts modestly help AutoGEN/ReAct but not LangGraph, whose rigid deterministic control flow is prompt-insensitive; (2) two independent dataset sets per task category (26 datasets total) — rankings stayed stable across datasets even as absolute success rates shifted; (3) 3 repeated runs per model (fixed prompt/dataset, seed varying only) — GPT-series models were most stable across reruns, and no task showed more than 10% consistency variation, meaning stochasticity is a smaller robustness concern here than prompt design.
- Failure-mode taxonomy: 14 error types across 4 categories (system design, agent scheduling/collaboration, environment/input, core module/model capability), derived via a dual-stage process — 3 LLMs independently chain-of-thought-reason about candidate error types from execution logs, provisional judgment via 2-of-3 voting, then 10% expert human review of the reasoning chains. Long-context handling failures were identified as causing the most severe, broadly cascading score degradation (plan-code misalignment propagating into code quality and task completion), consistent with known LLM positional-bias literature on middle-of-context underutilization — a concrete, reusable failure-taxonomy *method* (not just a list of failure categories) for our own failed-task analysis.
- Data/code availability: platform + workflow/evaluation code at github.com/lyyang01/bioagent-benchmark (MIT license) and Zenodo (10.5281/zenodo.18437898); datasets/gold-standard scripts/knowledge-base content at Zenodo (10.5281/zenodo.17291196); isolated conda environments for reproducibility at Zenodo (10.5281/zenodo.17455069).
- Relevance to our benchmark: the closest published analog to what `llmbiobench` is trying to build — real tools + real datasets + tutorial-derived gold-standard scripts + multi-dimensional scoring + explicit judge-agreement reporting + ablation/robustness studies as first-class results, not afterthoughts. Its 18-metric/4-dimension taxonomy, log/exponential score-normalization equations, and dual-stage LLM+human failure-taxonomy method are all directly adaptable starting points.
- Page 12-13 (right after Competing Interests / Author details) had no embedded prompt-injection text, unlike Guo_2026 and Alam_2026 — noting this so the pattern-tracking note doesn't imply every PDF in this folder is compromised.

### Su_Feng_2026

- Title: BioMaster: Multi-agent system for automated bioinformatics analysis workflow.
- Venue: Patterns, 7 (2026) 101611. doi:10.1016/j.patter.2026.101611. Author byline captured from PDF metadata: Houcheng Su (full author list not independently cross-checked beyond this metadata field).
- Core architecture: a knowledge-guided multi-agent framework with four specialized agent roles — PLAN, TASK, DEBUG, CHECK. The DEBUG agent is designed to mitigate the common "error propagation" problem in long pipelines by analyzing the actual error type and generating a targeted fix, rather than blindly retrying the failed step. A **dual RAG** design separates a "PLAN RAG" knowledge base (workflow/tool-selection guidance) from an "EXECUTE RAG" knowledge base (execution-level troubleshooting/parameter guidance), keeping planning knowledge and execution knowledge from cross-contaminating each other's retrieval.
- Comparators: ChatGPT (general LLM baseline, no agent scaffolding), AutoBA (an existing multi-omic code-generation agent, also cited as related work in Guo_2026), and SingleAgent (an ablated single-agent baseline without BioMaster's PLAN/TASK/DEBUG/CHECK role split), which isolates the marginal value of multi-agent orchestration itself from just having an LLM attempt the whole workflow.
- Main benchmark suite: 49 tasks spanning 30+ bioinformatics analysis types across 102 tools, covering DNA-seq, RNA-seq, and specialized -omics workflows: Hi-C, ChIP-seq, ATAC-seq/DNase-seq, CAGE-seq, WGS/WES (SNV/CNV/SV calling, annotation, antibiotic-resistance gene ID), microRNA, CLIP-seq/RIP-seq/Ribo-seq, spatial transcriptomics, scRNA-seq, Nanopore/PacBio long-read sequencing, metagenomics, and mass spectrometry.
- Headline result (main text, per-step task completion across the 49-task suite): BioMaster 95.9%, SingleAgent 49.0%, AutoBA 26.5%, ChatGPT 24.5%. Notably, the single-agent ablation alone (SingleAgent) already roughly doubles AutoBA/ChatGPT's completion rate with no multi-agent scaffolding beyond a plain agentic loop, and BioMaster's multi-agent/dual-RAG additions on top roughly double completion again.
- 72 supplementary per-workflow comparison tables (S1-S72), each a step-by-step ✓/✗ checklist across the three-way comparison for one specific pipeline (e.g. Hi-C, ChIP-seq peak calling, RNA-seq isoform quantification/fusion detection/APA/editing/splicing/circRNA detection, WGS/WES SNV/CNV/SV, microRNA, Nanopore DNA methylation/event alignment/comprehensive DNA sequencing, CLIP-seq/RIP-seq/Ribo-seq, DNase-seq, CAGE-seq, mass spectrometry, spatial transcriptomics neighborhood enrichment/deconvolution/ligand-receptor/domain identification, scRNA-seq clustering/DEG/marker genes/cell-type annotation/trajectory/regulatory network, comprehensive WGS, metagenomics). This reveals a consistent, reusable *failure taxonomy* rather than one-off bugs:
  - ChatGPT: near-universal QC-step tool misuse (repeatedly misuses scanpy for QC across most scRNA-seq/spatial tables), wrong tool selection at the *planning* stage itself for domain-specific formats (e.g. its Nanopore plans specify nanopolish/BWA-MEM/GATK/Megalodon instead of dorado/minimap2 — a planning-level hallucination, not just an execution slip), and outright Python/R script errors partway through multi-step pipelines.
  - AutoBA: consistent basecalling/alignment tool misuse (wrong dorado/minimap2 invocation on Nanopore data), frequent failure at highly-variable-gene selection and downstream single-cell steps even after getting basic clustering right, and specific tool-usage errors (GATK Funcotator, CLIPper, RiboCode, rMATS, cooler parameters) that block the rest of a pipeline once tripped.
  - BioMaster: completes essentially every task end-to-end, with exactly two documented exceptions worth noting precisely because they're rare: (1) spatial transcriptomics cell-type deconvolution fails for *all three* systems due to package conflicts (scanpy/squidpy/celltypist/tangram dependency clashes) — the one workflow where BioMaster's agent design can't route around an external tooling/environment problem; (2) metagenomic phyloseq analysis (Table S72) is the single reversal in the entire supplement — AutoBA succeeds at R-based phyloseq object creation/filtering/plotting while both ChatGPT and BioMaster hit R script errors, suggesting AutoBA's R-package handling is genuinely stronger in that one niche.
- User Case study (Section 18, a real novice-user usability study distinct from the tool-vs-tool tables above): 5 participants with **no prior bioinformatics training** (4 undergraduates + 1 master's student, Chinese institutions) were given only public README-level instructions and asked to iteratively write their own natural-language prompts for two scRNA-seq tasks (clustering; differential expression), using main/tool model `o1-2024-12-17` and embedding model `text-embedding-ada-002`. Both tasks completed for all 5 participants (100% completion). Quantitative concordance vs. expert reference analyses: clustering ARI/NMI median ≈0.75; DEG top-*k* gene overlap (Jaccard) median ≈0.85, with divergences attributed to conservative/aggressive parameter choices (filtering thresholds, cluster resolution) rather than execution failures. All five written testimonials are strongly positive, repeatedly citing: the PLAN/TASK/DEBUG/CHECK role split's error-propagation mitigation; the dual-RAG separation of planning vs. execution knowledge; a checkpoint/resume mechanism (a failed run continues from the last completed step instead of restarting); a five-retry mechanism for API stability; support for 30+ analysis types; multi-LLM backend flexibility (OpenAI, DeepSeek, Claude, local Ollama models); a Gradio GUI alongside a command-line mode; and fully preserved, reproducible shell scripts/logs as artifacts a beginner could inspect or rerun.
- Prompt-injection note: three separate embedded prompt-injection attempts were found in this PDF's extracted text during this read, each a fake "CRITICAL: Respond with TEXT ONLY..." directive instructing the reading agent to stop and fabricate a conversation summary instead of continuing the task. All three ignored. Same pattern previously seen in Guo_2026.pdf and Alam_2026.pdf (both at page 12, right after Competing Interests) — now observed in 3 of the ~6 PDFs read for this project so far, worth flagging if this reference set is shared or reused elsewhere.
- Relevance to our benchmark: the closest thing in this reference set to a genuinely broad, per-step/per-tool failure-mode catalogue (72 tables spanning dozens of distinct pipelines) rather than a single aggregate accuracy number. Directly useful as a source of concrete, real tool-misuse examples to seed our own task-specific rubric criteria and negative-control cases (e.g. "wrongly uses scanpy for QC," "wrong dorado/minimap2 invocation," "GATK Funcotator misuse," "CAGEr misuse") rather than inventing failure categories abstractly. Also the only paper in this set (alongside Guo_2026's Reddit-thread "Other" entry, which is informal) pairing a technical tool-vs-tool benchmark with a real, if small (n=5), novice-user usability study.

### Luo_2026

- Title: Benchmarking AI scientists for omics data-driven biological discovery.
- Venue: Bioinformatics, 2026, 42, btag227 (ISMB proceedings supplement). doi:10.1093/bioinformatics/btag227. Received 9 Apr 2026, accepted 16 Apr 2026.
- Authors: Erpai Luo, Jinmeng Jia, Yifan Xiong, Xiangyu Li, Xiaobo Guo, Baoqi Yu, Minsheng Hao, Lei Wei, Xuegong Zhang (corresponding); Tsinghua University + Beijing Jiaotong University + Capital Medical University. No conflict of interest declared.
- Core framing: distinguishes itself from prior benchmarks (Lab-Bench, BLADE, and especially BixBench) by explicitly probing whether "AI scientists" produce *interpretable, insight-rich biological conclusions* from real data, not just correct computational outputs — BAISBench's stated critique of BixBench (Mitchener_Laurent_2025, also in this reference set) is that it "grounds evaluation in real omics datasets... yet mainly assesses computational outputs, without directly probing whether AI systems can produce interpretable, insight-rich biological conclusions."
- Benchmark: BAISBench (Biological AI Scientist Benchmark), two complementary tasks, both scRNA-seq-scoped:
  - **BAIS-DPTA** (Data Processing and cell Type Annotation): 15 expert-labeled scRNA-seq datasets across 15 organs (2312-58,706 cells, 4-42 cell types per dataset, curated from recent publications and annotated via the human Ensemble Cell Atlas (hECA) project). Evaluates (1) workflow completeness across 6 standard steps (QC, data normalization, HVG selection, dimensionality reduction, clustering, marker gene identification) and (2) cell-type annotation accuracy via a novel **hierarchical partial-credit metric**: `S_CTA = (n_exact + 0.5*n_parent + 0.2*n_grandparent) / n_cell`, scored against uHAF (Unified Hierarchical cell Annotation Framework; Bian et al. 2025) organ-specific cell-type trees covering 50 organs — a reusable pattern for any hierarchical/ontology-backed classification task in our own benchmark, since it rewards biologically-meaningful partial correctness instead of flat exact-match.
  - **BAIS-SD** (Scientific Discovery): 193 multiple-choice questions (~20% multi-answer) derived from biological conclusions reported in 41 published single-cell studies (datasets from the CellxGene platform, 5600-122,000 cells each). Questions constructed via an LLM-assisted pipeline (GPT-4o extracts candidate discoveries from each paper, converts them to MCQs), then reviewed/revised by a human expert for accuracy and feasibility. 10 question categories: key gene analysis, cellular heterogeneity analysis, disease analysis, analysis of cellular components, cellular function reasoning, reasoning & analysis based on data, developmental state analysis, pathway analysis, cell-cell communication, other. Scored as `S_SD = (n_single + n_multi-all + 0.5*n_multi-part) / n_Q * 100`.
- AI scientists evaluated: AutoBA, scChat (multi-agent + RAG conversational co-pilot, hard-coded function tools), Biomni, Pantheon ("Pantheoneos," evolvable multi-agent genomics-discovery framework), STELLA — spanning pipeline-automation (AutoBA/scChat) to structured multi-agent reasoning/hybrid model integration (Biomni/Pantheon/STELLA). Plus a naive baseline: GPT-4o directly generating executable Python code for preprocessing/classification, with no agent scaffolding at all.
- Human baselines: for BAIS-DPTA, one graduate-level bioinformatician completed the task using CellTypist (an automated annotation tool) following its official workflow. For BAIS-SD, five graduate-level bioinformaticians each answered one-fifth of the 193 questions (collectively covering the full set) — the authors explicitly flag this as *not* a genuine human-human inter-annotator agreement measurement, since no question was answered by more than one human, a real limitation worth avoiding in our own human-baseline design.
- BAIS-DPTA results: every AI scientist completed the full 6-step pipeline (GPT-4o's baseline skipped QC and had to be manually corrected for fair comparison), but with substantial methodological variation — only Biomni/Pantheon/STELLA did explicit data scaling; scChat used scVI for dimensionality reduction vs. PCA elsewhere; Pantheon/STELLA uniquely used scipy k-means for clustering vs. Leiden (Scanpy) elsewhere; marker-gene-per-cell-type counts ranged from 1-3 (human) to 5-8 (Biomni) to a highly variable 1-30 (scChat). Annotation accuracy diverged sharply from this uniform completion: human-with-CellTypist scored highest overall; STELLA was the best AI scientist but still below the human-CellTypist baseline; **AutoBA failed completely** (never assigned final cell labels after marker-gene identification, scoring zero across every organ). Notably, several more architecturally sophisticated systems (AutoBA, scChat, Biomni) underperformed the *naive* GPT-4o-code-generation baseline — increased agentic sophistication did not guarantee better biological interpretation once real domain knowledge was required. Organ-specific CellTypist classifiers did not consistently beat AI scientists across organs either, suggesting AI scientists can adapt/incorporate organ-specific knowledge in a data-driven way rather than needing a dedicated classifier per tissue. A positive correlation between token consumption and annotation performance was observed across AI scientists (excluding AutoBA's zero scores).
- BAIS-SD results: scChat and AutoBA were excluded from this task entirely (scChat's hard-coded function tools don't support the customized workflows the benchmark needs; AutoBA consistently failed to produce valid answers) — leaving Biomni, Pantheon, STELLA as the compared set. Biomni and Pantheon both used Claude Sonnet 4.5 as their base LLM; STELLA used a heterogeneous mix (Claude Sonnet 4.5 + Gemini 2.5 Pro + Grok-4 across subtasks). Each AI scientist ran the full 193-question task **10 times** to check run-to-run stability (results were consistent across runs). STELLA scored highest, comparable to human experts; Pantheon second; Biomni third. Per-category, STELLA led in nearly every one of the 10 categories; humans retained a clear edge specifically in key gene analysis and cellular heterogeneity analysis (domain expertise/interpretive judgment); AI scientists matched or exceeded humans in data-driven reasoning and developmental-state analysis (systematic/exhaustive high-dimensional exploration may be an AI advantage there) — a complementary-strengths finding, not a strict AI-vs-human ranking.
- Base-LLM ablation (isolating architecture vs. underlying model, run on Biomni): swapped in Claude Haiku 3.5 (weaker), Claude Opus 4.5 (stronger), GPT-4.1, and Gemini 2.5 Pro. Within the Claude family, performance ordered Opus > Sonnet > Haiku, with Opus 4.5 pushing Biomni close to human-expert level; performance was positively correlated with token usage within a fixed architecture. GPT-4.1 and Gemini 2.5 Pro matched Claude Sonnet 4.5's performance while consuming markedly fewer tokens, pointing to genuine cross-provider efficiency differences. Headline conclusion: **for BAIS-SD, the choice of base LLM is a more decisive performance driver than system/agent architecture** — directly comparable to (and reinforcing) Liu_Zhou_2026's independent finding that code-generation/model quality, not planning/architecture quality, drives task success.
- "Cheating"/shortcut-behavior check (a concrete, reusable genuine-data-dependence validation technique, directly relevant to our own Hallucination and Negative Controls section): (1) **no-data ablation** — ran BAIS-SD without providing the underlying dataset at all; accuracy dropped but stayed well above random, showing systems can partially answer from memorized/retrieved background knowledge alone, without real data analysis; (2) **mismatched-data swap** — randomly shuffled datasets so each question was paired with an unrelated dataset while keeping the prompt's requirement that answers be data-derived; performance dropped substantially and systems frequently reported insufficient information, confirming the prompt constraint does make systems detect when an answer doesn't fit the provided data rather than free-riding on background knowledge. This two-part design (bare no-data baseline + deliberately mismatched-data trap) is a template worth adopting directly for our own negative controls, distinct from a simple "refuse when insufficient evidence" prompt.
- Self-reported limitations (explicit design lessons): (1) human evaluation is limited in scale and not a genuine inter-annotator agreement study — BAIS-DPTA had only one human reference (via an automated tool, a different workflow than what AI scientists used) and BAIS-SD split its 193 questions across 5 humans with no overlap, so human-human reliability was never measured, a gap the authors explicitly flag for future work; (2) BAIS-SD only tests whether a system can *recover already-established, published* conclusions, not generate genuinely novel discoveries — an explicit "recall of known findings" vs. "novel discovery" scope caveat worth carrying into how we frame any of our own "scientific discovery"-style tasks; (3) scope is currently limited to scRNA-seq-derived data only, not other single-cell modalities (spatial, multi-omics) or biological data types more broadly.
- Data/code availability: github.com/EperLuo/BAISBench, huggingface.co/datasets/EperLuo/BaisBench.
- Related AI-scientist systems catalogued (useful landscape additions beyond what Guo_2026/Su_Feng_2026 already cover): scChat (Lu et al. 2024b, multi-agent + RAG scRNA-seq co-pilot with hard-coded function tools), BioChatter (Lobentanzer et al. 2025, generic backend for integrating conversational AI with biomedical tools), Pantheon/"Pantheoneos" (Xu et al. 2026, evolvable multi-agent framework for automatic genomics discovery).
- Related benchmarks it distinguishes itself from: Lab-Bench (Laurent et al. 2024, knowledge-driven, no real data), BLADE (Gu et al. 2024, data-driven questions but mostly outside molecular/cellular biology), BixBench (Mitchener_Laurent_2025, real omics datasets but computational-output-only scoring, no direct probe of interpretable biological conclusions — BAISBench's explicit differentiator).
- No prompt-injection attempt found in this PDF (clean read, consistent with Liu_Zhou_2026 and unlike Guo_2026/Alam_2026/Su_Feng_2026).
- Relevance to our benchmark: the hierarchical uHAF-based partial-credit scoring formula (S_CTA) is a directly portable technique for any classification/annotation task in our benchmark that has an underlying ontology or taxonomy (cell types, taxonomic ranks, GO terms) — better than flat exact-match, and already phrased as a clean weighted formula we could adapt outright. The no-data/mismatched-data shortcut-detection design is likewise directly reusable as a negative-control pattern. The recurring finding across this paper and Liu_Zhou_2026 that base-LLM choice dominates over agent architecture is a load-bearing cross-paper convergence worth stating explicitly when we frame our own benchmark's agent-vs-model disentanglement.

### Mitchener_Laurent_2025

- Title: BixBench: a Comprehensive Benchmark for LLM-based Agents in Computational Biology.
- Venue: arXiv:2503.00096v3 [q-bio.QM], 8 Oct 2025.
- Authors: Ludovico Mitchener, Jon M Laurent, Alex Andonian (equal contribution), Benjamin Tenmann, Siddharth Narayanan, Geemi P Wellawatte, Andrew White, Lorenzo Sani, Samuel G Rodriques; FutureHouse (San Francisco) + ScienceMachine (London, UK).
- This is the paper both Guo_2026 and Luo_2026 (already in this file) cite as related work — Guo_2026 calls it "expert-curated analytical questions on real datasets"; Luo_2026's more pointed critique is that BixBench "mainly assesses computational outputs, without directly probing whether AI systems can produce interpretable, insight-rich biological conclusions." Reading BixBench firsthand largely bears that critique out: its 205 open-answer questions target precise, data-derived facts extracted from a *specific* analysis (e.g. "What percentage of genes differentially expressed in strain 97 are also differentially expressed in strain 99?"), not higher-order biological interpretation of the kind Luo_2026's BAIS-SD questions target (e.g. "What role did FOXL1+ fibroblasts play in intestinal development?"). The two benchmarks are testing genuinely different capabilities, not competing measures of the same thing.
- Benchmark: 61 real-world analytical "capsules" (a hypothesis/research question + heterogeneous input data files + Jupyter notebook code + a short result summary + a true/false answer on whether the hypothesis was supported + metadata incl. self-selected category), yielding 205 associated open-answer questions (1-7 per capsule, avg 3.8). Capsule categories (Fig. 2, self-selected, most to least common): Genomics, Transcriptomics, Differential Exp. Analysis, RNA-seq, Phylogenetics & Evo. Analysis, Whole Genome Sequencing, Genomic Variant Analysis, Other, Imaging, ML and AI, Epigenomics, Functional Genomics, Network Biology, Integrative Omics, Proteomics, Single-Cell Analysis.
- Capsule construction: PhD-holder contract bioinformatics analysts (recruited via professional networks, outreach to bioinformatics-paper authors, and affiliated institutions) recapitulated published analyses or produced de novo trajectories from their own data in a standardized Jupyter/Colab notebook environment (Python/R/bash), then had capsules peer-reviewed by other analysts before merging into the final 61-capsule corpus.
- Question generation pipeline (a reusable, fully-specified QA-generation methodology worth adapting directly): (1) Claude 3.5 Sonnet (20241022) drafts 8 candidate MCQs per capsule (two rounds of 4) from a modified notebook + hypothesis + result + a specialized prompt; (2) human expert analysts get full edit access to Approve/Reject each question, with visibility into earlier reviewers' decisions to catch process mistakes; (3) duplicate filtering — the Approved set per capsule is passed to an LLM (Claude 3.5 Sonnet) to flag duplicates, run in triplicate with manually-assessed ~95% concordance across the three runs, duplicates manually verified/removed, and the whole duplicate-check repeated until nothing more is flagged. Final: 205 questions, 61 capsules.
- Benchmark comparison table (their Table 1, useful additional landscape entries): DA-Code, DSBench, MLE-Bench, REBench, BLADE, ScienceAgentBench, and BixBench itself, compared on avg. completion time/task count/eval type (Verifier/Reward/MCQ/Open-ended)/multi-language support/science focus/avg. lines of code. BixBench is the only one in the table combining multi-language + science-focus + fully open-ended evaluation, and has by far the longest average completion time (4.2h vs. 0.1-17h for the others, though DSBench and REBench are outliers on the high end too).
- Agent infrastructure: built on Aviary (Narayanan et al. 2024, "an extensible gymnasium for language agents"), agentic prompting based on Aviary's "SimpleAgent" pattern, executed inside a pre-built Docker container (`BixBench-env:v1.0`) loaded with common bioinformatics Python/R/bash packages — isolating model evaluation from environment-setup friction while still requiring the agent to identify and load the right packages itself. Three tools exposed to the agent: `edit_cell` (select/modify/execute a Jupyter cell), `list_workdir` (recursively inspect its own workspace), `submit_answer` (finalize/end the trajectory). Every code edit triggers a full notebook rerun so the agent sees live tabular/plot output and tracebacks. The full initiating prompt (Appendix A) is a genuinely useful worked example: structured chain-of-thought tags (`<analysis_planning>`, `<thought_process>`) around a fixed 5-step workflow (list directory -> load data + descriptive stats -> develop analysis plan -> execute plan -> conclude and submit via `submit_answer` in strict JSON), plus operational guidance baked directly into the prompt ("AVOID USING PLOTS. USE TABLES AND PRINT OUTPUTS INSTEAD AS MUCH AS POSSIBLE") that foreshadows their own image-generation ablation below.
- Evaluation design, two complementary regimes: **open-answer** (primary, closer to real bioinformatics practice where there's no MCQ menu) — a separate judge LLM (Claude 3.5 Sonnet) compares the agent's submitted answer to a ground-truth solution, binary 1/0 correctness, 5 parallel trajectories per capsule to average out stochasticity; **multiple-choice** (secondary, framed as "a useful proxy evaluation on the journey to a truly autonomous bioinformatician") — after the open-answer run completes, a *second* judge LLM is given the full analysis notebook + the original question + the MCQ options + the agent's own open-answer response, and picks the best option; run both **with** an explicit "Insufficient information" refusal/opt-out option and **without** it, with majority voting across the 5 parallel iterations producing the final MCQ answer. Scale: 61 capsules x 5 iterations x 2 models x 2 modalities (with/without images) = 1,220 total trajectories (305 per model-modality cell).
- Models evaluated: GPT-4o and Claude 3.5 Sonnet only — chosen specifically for structured-output generation and long-context handling. The paper explicitly notes reasoning models (o1, DeepSeek R1) were tried in preliminary tests and struggled/were excluded, due to long-context and structured-output/tool-calling requirements this agentic framework demands — a concrete, named example of "reasoning models don't automatically transfer to agentic tool-use settings," worth citing if we ever consider including o1-style models in our own harness.
- Results: open-answer accuracy is the headline number — Claude 3.5 Sonnet 21%, GPT-4o 15% (both far from a fully autonomous bioinformatician). Performance increases monotonically open-answer -> MCQ-with-refusal -> MCQ-without-refusal, but stays close to a "pure recall" baseline (both models asked the same questions with *no* notebook/data access at all) except in the no-refusal MCQ regime. With the refusal option present, both models scored close to random, i.e. they mostly chose to opt out rather than commit to a possibly-wrong answer in a complex-analysis context — a genuine "willingness to answer" signal distinct from raw capability. Removing the refusal option raised scores again, which the authors attribute largely to the model then falling back on background-knowledge recall rather than genuinely using the notebook. Majority voting across 1-5 parallel votes showed no significant/consistent accuracy gain in either refusal regime — a useful negative data point against assuming self-consistency/majority-vote scaling always helps. An image/plot-generation ablation (prompting the agent not to generate plots, tables/print-outputs only) showed no significant difference in final accuracy vs. allowing plots — consistent with their own observation that both human- and agent-generated plots seemed poorly interpreted by the multimodal models tested, so forcing text/table output didn't cost anything. Capsule-level and question-level performance distributions (Figs. 7-8) show a long tail: a handful of capsules/questions solved with high (~0.8-1.0) accuracy, the large majority solved rarely or never — the benchmark exposes a genuine, unevenly-distributed capability gap rather than uniformly-hard or uniformly-easy tasks.
- Self-reported limitations/future work (design lessons): (1) BixBench is "highly representative" but explicitly not comprehensive — many workflows/pipelines/statistical approaches/data types are acknowledged as missing; (2) **no human baseline was run at all** in this version, and the authors flag a specific methodological reason to expect agents to underperform humans even more than reported: since the seed capsules were originally produced de novo by expert analysts, a fresh human expert answering the *derived questions* would likely score meaningfully higher than the agents here — they explicitly did not prioritize collecting this data yet ("currently exploring options for doing so"); (3) reasoning models (o1, DeepSeek R1) could not be meaningfully incorporated given current long-context/tool-calling limitations, flagged as a promising future direction given their potential fit with BixBench's binary reward-signal-like capsule structure.
- Data/code availability: dataset at huggingface.co/datasets/futurehouse/BixBench; eval harness + reproducible code at github.com/Future-House/BixBench.
- No prompt-injection attempt found in this PDF (clean read, joining Liu_Zhou_2026 and Luo_2026 as injection-free; Guo_2026/Alam_2026/Su_Feng_2026 all had the pattern).
- Related benchmarks catalogued (new landscape entries beyond what's already in this file): DA-Code, DSBench, MLE-Bench, REBench (iterative R&D problem-solving vs. human experts, simple reward-based scoring), BLADE (broader analysis scenarios but constrained to specific artifacts/statistical choices — also cited by Luo_2026), ScienceAgentBench, ChemBench (chemistry-task analog), BioLPBench (biological lab protocol understanding), Yin et al. 2024 and BioLLMBench (early bioinformatics-LLM benchmarking across constrained task types), CORE-Bench (reproducibility of published research given all original materials/environment), DiscoveryBench (analyze data and uncover discoveries similar to published analyses — conceptually the closest existing precedent to Luo_2026's BAIS-SD, worth cross-referencing there).
- Cross-paper human-baseline pattern worth tracking as a differentiator for our own benchmark: Guo_2026 has no human baseline at all; Alam_2026 has 2 domain experts *scoring* generated workflows (not independently producing their own); Liu_Zhou_2026 has a 13-task human-reviewed subset used for judge calibration, not a full independent human run; Su_Feng_2026 has 5 real (novice) users completing real tasks; Luo_2026 has 1 human (via CellTypist) on BAIS-DPTA and 5 humans splitting BAIS-SD's 193 questions with zero overlap (no inter-annotator agreement possible); BixBench has none at all, by the authors' own admission. A genuine, independently-run human baseline (ideally with 2+ raters per task for inter-annotator agreement, matching our own LLM-Judge Calibration protocol's design) would be a real point of methodological differentiation against every paper in this reference set, not just an incremental addition.
- Relevance to our benchmark: the capsule construction pipeline (hypothesis/data/code/result/answer + independent peer review + LLM-drafted-then-human-approved questions + triplicate LLM duplicate-flagging) is a fully worked, reusable template for building our own task corpus from scratch, distinct from Guo_2026's task-capsule format in emphasizing *open-answer* over multi-format-comparison scoring. The refusal-vs-no-refusal MCQ ablation is a clean, cheap way to separately measure "willingness to admit insufficient evidence" from raw accuracy, and the majority-voting and image-ablation null results are both useful priors against assuming those interventions help without checking.

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
| Biomni | PromptBio-Bench (244 tasks: genomics, transcriptomics, proteomics, single-cell, data science, stats/ML); also BAIS-DPTA/BAIS-SD single-cell tasks in Luo_2026 | Code, reports, structured output files (FASTQ/BAM/VCF/CSV/images/etc.) | Yes; strong candidate, independent of PromptBio Inc. (unlike ToolsGenie) | 8 | Guo_2026: completion 0.99, accuracy 0.76, fastest runtime and fewest tokens; also see Reddit thread. Luo_2026: third of 3 on BAIS-SD (behind STELLA/Pantheon); base-LLM ablation shows Claude Opus 4.5 pushes it near human-expert level, more decisive than architecture changes |
| ToolsGenie | Same PromptBio-Bench suite as Biomni | Executable code, structured result files | Yes, but PromptBio Inc. authored the paper and owns ToolsGenie: treat the vs.-Biomni ranking as non-independent | 6 | Guo_2026: completion 0.98, accuracy 0.76 (highest of the 3 agents at high difficulty, 0.69) |
| STELLA | Same PromptBio-Bench suite; also BAIS-SD in Luo_2026 | Executable code, structured result files | Yes; the architecturally distinct baseline (multi-model orchestration vs. single-backend agents) | 7 | Guo_2026: completion 0.88, accuracy 0.72 (drops to 0.56 at high difficulty); highest token/runtime variance; self-evolving mode unused, so this is a lower bound. Luo_2026: top AI scientist on BAIS-SD, comparable to human experts and leading in nearly every question category; excluded from BAIS-DPTA comparison table (evaluated on discovery task only) |
| GPT-4o | Galaxy/Nextflow workflow generation in Alam_2026; the naive no-scaffolding code-gen baseline and the LLM used to construct BAIS-SD's questions in Luo_2026; one of the 2 agentic models in Mitchener_Laurent_2025's BixBench | Workflow descriptions, scripts, structured prompts, code | Yes; useful baseline general LLM for workflow generation | 6 | Paper: Alam_2026. Luo_2026: as a bare "generate executable Python code" baseline (no agent scaffolding), it beat AutoBA/scChat/Biomni on BAIS-DPTA cell-type annotation — architectural sophistication didn't guarantee better biological interpretation. Mitchener_Laurent_2025: weaker of the 2 BixBench models, 15% open-answer accuracy vs. Claude 3.5 Sonnet's 21% |
| Claude 3.5 Sonnet | The other agentic model in Mitchener_Laurent_2025's BixBench; also the judge/question-generation LLM in that same paper's pipeline | Jupyter notebooks (code + tables/print outputs), submitted open-answers | Yes; the stronger of the 2 models tested on BixBench, and doubles as the paper's own question-drafting/duplicate-flagging/judging LLM | 7 | Mitchener_Laurent_2025: best open-answer accuracy at only 21%; both refusal-option and majority-voting ablations run specifically on this + GPT-4o |
| Gemini 2.5 Flash | Galaxy workflow generation, structured multi-step prompts | Workflow descriptions, structured plans, code | Yes; useful for prompt-to-workflow comparisons | 7 | Paper: Alam_2026 |
| DeepSeek-V3 | Nextflow workflow generation, code-heavy tasks | Nextflow scripts, command-line workflow plans, code | Yes; useful for code/workflow generation comparisons | 7 | Paper: Alam_2026 |
| Faraday by AscentBio | Target insight, molecule evaluation, molecule design, clinical data analysis | Scientific reports, figures, analysis outputs | Partial; more drug-discovery focused than Bioconductor workflow benchmarking | 6 | Reddit thread |
| Science Machine | Data analysis, clinical data, genomics data | Analysis reports, data outputs, notifications | Partial; relevant for genomics/data-analysis tasks, less clear for workflow reproducibility | 6 | Reddit thread |
| Future House/Edison Scientific | Literature research, analysis agents, possible molecule agent workflows | Research summaries, agent outputs, possibly analysis files | Partial; interesting for comparison, but accessible workflow execution may be limited | 5 | Reddit thread |
| Potato AI | Protocol generation and biotech workflow forms | Protocols, form-driven outputs | Low; less aligned with executable bioinformatics workflow benchmarking | 4 | Reddit thread |
| Grok3-beta | 50 single-cell/spatial omics tasks in Liu_Zhou_2026, tested across all 3 frameworks | Code, plans, analysis outputs (embeddings, plots, spatial maps) | Yes; strongest LLM in this domain-scoped benchmark, consistently top-2 regardless of framework | 8 | Liu_Zhou_2026: top overall LLM; excels at code score, retrieval accuracy, task completion rate |
| ReAct (single-agent framework) | Same 50-task suite, framework-level/LLM-agnostic | Code, plans, retrieved knowledge, analysis outputs | Yes; useful architecture reference for single-agent iterative reasoning-action loops | 7 | Liu_Zhou_2026: highest retrieval accuracy (+12-18% vs. multi-agent) but 2-3x more interaction rounds; complete failure paired with DeepSeek-V3 |
| AutoGEN (multi-agent framework) | Same 50-task suite | Code, plans, analysis outputs | Yes; useful architecture reference for role-specialized multi-agent coordination | 7 | Liu_Zhou_2026: most robust to prompt-tier and module-ablation changes among the 3 frameworks |
| LangGraph (multi-agent framework) | Same 50-task suite | Code, plans, analysis outputs | Partial; deterministic control flow makes it prompt-insensitive but rigid | 6 | Liu_Zhou_2026: negligible gain from richer prompts; larger sensitivity to knowledge-retrieval/code-consistency ablations |
| BioMaster | Su_Feng_2026 49-task/102-tool suite (Hi-C, ChIP-seq, RNA-seq variants, WGS/WES, microRNA, Nanopore/PacBio, CLIP/RIP/Ribo-seq, spatial transcriptomics, scRNA-seq, metagenomics, mass spec) | Shell scripts, BAM/VCF/CSV/plots/HTML reports, logs | Yes; domain-scoped multi-agent design (PLAN/TASK/DEBUG/CHECK + dual RAG) is the most direct architectural precedent in this reference set for a purpose-built bioinformatics agent | 8 | Su_Feng_2026: 95.9% step completion vs. 49.0% (SingleAgent)/26.5% (AutoBA)/24.5% (ChatGPT); only fails cell-type deconvolution (all systems fail) and phyloseq metagenomics (AutoBA wins instead) |
| AutoBA | Same Su_Feng_2026 49-task suite (tested directly, not just cited); also BAIS-DPTA/BAIS-SD in Luo_2026 | Generated code/scripts | Yes; useful weaker multi-omic code-gen baseline for architecture comparisons | 3 | Su_Feng_2026: 26.5% completion; recurring basecalling/alignment tool misuse; the one case it beats BioMaster is R-based phyloseq metagenomics (Table S72). Luo_2026: failed both tasks outright — scored zero on BAIS-DPTA cell-type annotation (never assigned final labels) and was excluded from BAIS-SD for consistently invalid answers |
| ChatGPT (agent baseline, o1-2024-12-17) | Same Su_Feng_2026 49-task suite; also the natural-language front end in the paper's 5-user novice study | Generated code/scripts/plans | Yes; useful as the no-scaffolding LLM floor | 4 | Su_Feng_2026: 24.5% completion, lowest of the 4; fails at the planning stage for domain-specific tools it doesn't know well (e.g. Nanopore), not just execution |
| SingleAgent (BioMaster ablation) | Same Su_Feng_2026 49-task suite | Generated code/scripts | Yes; isolates the marginal value of BioMaster's multi-agent/dual-RAG design over a bare single-agent LLM loop | 5 | Su_Feng_2026: 49.0% completion, ~2x AutoBA/ChatGPT with no scaffolding beyond a single agent loop |
| scChat | BAIS-DPTA/BAIS-SD in Luo_2026 (single-cell scRNA-seq analysis co-pilot) | Generated code, analysis outputs, conversational responses | Partial; hard-coded function tools limit it to predefined workflows | 4 | Luo_2026: completed BAIS-DPTA's 6-step pipeline but with erratic marker-gene counts (1-30 per cell type) and weaker annotation accuracy than the naive GPT-4o baseline; excluded from BAIS-SD entirely since its fixed toolset can't support the benchmark's customized workflows |
| Pantheon ("Pantheoneos") | BAIS-DPTA/BAIS-SD in Luo_2026 (evolvable multi-agent genomics-discovery framework) | Generated code, analysis outputs, structured answers | Yes; a multi-agent architecture reference alongside Biomni/STELLA | 6 | Luo_2026: ranked second on BAIS-SD (behind STELLA, ahead of Biomni), same Claude Sonnet 4.5 base as Biomni; on BAIS-DPTA, uniquely used scipy k-means (like STELLA) instead of Leiden clustering |

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
  - Concrete real-world examples for "Incorrect tool choice"/"Runtime errors" (Su_Feng_2026's 72 supplementary tables): wrong tool at the *planning* stage for a domain-specific format the LLM doesn't know well (e.g. ChatGPT specifying nanopolish/BWA-MEM/GATK/Megalodon for Nanopore data instead of dorado/minimap2), misusing a general-purpose package for a step it wasn't meant for (repeatedly using scanpy to do QC), and specific single-tool-invocation errors (GATK Funcotator, CLIPper, RiboCode, rMATS, cooler parameters) that cascade into blocking the rest of a pipeline. Worth mining this table set directly when seeding our own negative-control/rubric failure categories rather than inventing them abstractly.
- Reproducibility across reruns: rerun workflows and check whether outputs remain stable.
- Provenance capture: record prompts, generated code, commands, parameters, tool versions, package versions, database versions, and container tags.
- Minimal success criteria: define the smallest acceptable output needed to count as partial success.
- Difficulty levels: include simple, intermediate, and hard examples to test robustness across task complexity.
- Functional-module ablation (Liu_Zhou_2026 methodology, reusable for any multi-component agent we test): systematically disable one architectural component at a time (e.g. retrieval/RAG, planning, self-reflection, inter-agent workflow control) and rerun the full task suite, to isolate which components actually drive performance vs. which just add design complexity. In their study, self-reflection removal caused the largest drop, RAG removal was second, and removing inter-agent turn-taking control had negligible effect. Worth doing on any agent harness we build ourselves, not just citing as a finding.

### Task-Specific Metrics

- Standard task metrics: define accepted metrics per task, such as F1 score, precision, recall, accuracy, sensitivity, specificity, edit distance, ANI, N50, alignment score, tree distance, and taxonomic rank agreement.
- Classification tasks: use precision, recall, F1 score, confusion matrices, and true negative controls.
- Hierarchical/ontology-aware partial credit (Luo_2026's BAIS-DPTA `S_CTA` metric, a directly portable formula): for any classification task whose labels sit in a known hierarchy/ontology (cell types, taxonomic ranks, GO terms), score `(n_exact + 0.5*n_parent + 0.2*n_grandparent) / n_total` against the ground-truth tree, rather than flat exact-match. Rewards biologically-meaningful partial correctness (predicting "myeloid cell" when the true label is "monocyte-derived dendritic cell" should count for something) without requiring a bespoke similarity function per task.

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
- Open-answer-then-MCQ-proxy judging (Mitchener_Laurent_2025/BixBench pattern): score the primary open-answer response with one judge call (agent answer vs. ground truth, binary), then separately hand a *second* judge LLM the full notebook + original question + a curated set of MCQ options + the agent's own open-answer, and ask it to pick the best option. Gets a cheap MCQ-style proxy signal without re-running the agent, and the two scores can diverge informatively (their BixBench results show MCQ accuracy consistently higher than open-answer for the same trajectories).
- Refusal-option ablation (same paper): run the MCQ judge both with and without an explicit "insufficient information" opt-out option. Comparing the two isolates "willingness to commit to an answer under uncertainty" from raw accuracy — in their results, both tested models scored close to random *specifically when the opt-out was available*, a distinct finding from their raw accuracy numbers and worth reporting as its own axis rather than folding into one score.

### Hallucination and Negative Controls

- Hallucination measures: include prompts or samples where the correct behavior is to refuse, report insufficient evidence, or produce no assignment.
- True negatives: include negative-control samples with no expected hit, no known annotation, or no valid current answer to measure false positives and unsupported claims.
- Genuine-data-dependence check (Luo_2026 precedent, a two-part reusable design for any task where an agent could otherwise answer from memorized/retrieved background knowledge instead of actually analyzing the provided data): (1) **no-data ablation** — rerun the task with the input dataset withheld; accuracy dropping to but not reaching random chance reveals how much of a "correct" answer is prior-knowledge leakage rather than real analysis; (2) **mismatched-data swap** — pair each question/prompt with a real but *unrelated* dataset while keeping the requirement that the answer be data-derived; a system that doesn't degrade or flag insufficient information here is answering from memorization, not from the data actually in front of it. More diagnostic than a bare "refuse when insufficient evidence" instruction, since it directly measures whether the refusal/degradation behavior is real.

### Robustness, Cost, and Resource Use

- Paper-derived metrics: completion status, equivalence score, computational time, and token consumption, enabling direct comparison of accuracy, robustness, and cost-efficiency across task categories and difficulty levels.
- Token usage: record prompt tokens, completion tokens, total tokens, and estimated API cost per task.
- Tool validity: score whether selected tools are maintained, appropriate for the task, correctly parameterized, containerized, and cited/versioned.
- Resource metrics: measure runtime, memory, CPU use, disk use, and container/image size.
- Score normalization for non-[0,1] raw metrics (Liu_Zhou_2026 has fully worked equations we can adapt directly): execution time via a modified-logarithmic curve (bounded by a max-runtime cap), CPU/GPU utilization via exponential decay, and interaction/self-correction round counts via exponential decay with power scaling, so that time/resource/round metrics can be folded into the same [0,1]-scaled weighted total as accuracy-style metrics without ad hoc rescaling per task.
- Robustness axes worth testing independently, not just once (Liu_Zhou_2026 precedent): (1) prompt-tier variation (minimal vs. key-requirements-augmented vs. fully-scaffolded prompts) to separate "agent capability" from "prompt engineering did the work"; (2) dataset-substitution variation (a second independent dataset per task category) to check whether rankings hold beyond one fixed input; (3) repeated runs at fixed prompt/dataset/seed-only-varying to isolate LLM sampling stochasticity from genuine task difficulty. Treat these as three separate robustness reports, since a framework/model can be robust on one axis and not another (e.g. their LangGraph was prompt-insensitive but that reads as rigidity, not strength).
- Two null results worth citing before assuming an intervention helps (Mitchener_Laurent_2025/BixBench, both run as explicit ablations, not just observed in passing): (1) majority voting across up to 5 parallel trajectories produced no significant/consistent accuracy gain over a single run, in either MCQ refusal regime — self-consistency/inference-time-scaling is not automatically a free win; (2) forbidding image/plot generation (forcing table/print-output only) produced no significant accuracy difference vs. allowing plots, consistent with their separate observation that the multimodal models tested seemed to interpret plots poorly regardless. Both are useful priors to test for, not assume, in our own robustness reporting.

## LLM-Judge Calibration (Brainstorm)

Guo_2026/promptbio-bench's LLM judge has zero tests and no human-agreement study anywhere in the repo; Alam_2026 has no judge at all, scoring is manual expert read-through only. Liu_Zhou_2026 is a partial exception (see below) but still leaves real, unclaimed territory here for our benchmark to contribute.

### What Liu_Zhou_2026 actually validated (and what it didn't)
- Cross-judge agreement: 3 LLMs (GPT-4o, Grok3-beta, Gemini-2.5-pro) independently score each LLM-graded metric and are averaged; they report inter-judge agreement of 93%/92%/95%/98%/90% across Plan Content/Plan Attributes/Code Attributes/Code Consistency with Plan/RAG-triggering accuracy. This is LLMs agreeing with other LLMs, not with humans, and doesn't by itself rule out shared systematic bias across judge models.
- Genuine human-agreement check: only performed for RAG-triggering accuracy, on a 13-task subset, blended into the final score as 0.8*LLM-judge + 0.2*human-expert, specifically because they observed LLM judges showing self-preference bias when scoring their own agent's RAG-triggering decisions. Reported human-LLM agreement was ~94% on that subset.
- Gap this leaves open: the other 4 LLM-graded metrics (Plan Content/Attributes, Code Attributes, Code Consistency with Plan) never got a human-agreement check at all, only cross-judge agreement. Our calibration protocol below (human-labeled gold set + weighted kappa/ICC against human-human reliability) would close that gap and is a legitimate differentiator even against this more rigorous precedent.
- Reusable technique regardless of outcome: self-preference bias detection (does a judge score its own agent's decisions higher than an independent grader would?) is worth checking for any metric where the judge LLM and the agent LLM could be the same model, before deciding whether a human-blend is needed.

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

### First real (non-synthetic) calibration data point: `tasks/bioc-1-a`

Marcel independently built a full loop on `tasks/bioc-1-a` (the DESeq2 sample-distance-matrix task): four real models (Claude-Sonnet-5, Gemini-3.7-Flash, gpt-5, MAI-Code-1.1-Flash) each solved the task via their own native chat interface (`prompt/evalprompt.txt`), then an LLM judge (`prompt/judgeprompt.txt`) compared each answer's CSV against the reference and wrote `results.md` plus a per-model `summary.md`.

This task's ground truth is a numeric CSV (an `eval.json` numeric-tolerance comparison per Guo_2026's own taxonomy), so it never strictly needed an LLM judge, which makes it a clean calibration check: `code/verify_bioc_1_a_judge.R` independently recomputes max/mean absolute error against the reference for all four answers. Result: **all four numbers matched the LLM judge's claimed numbers to displayed precision**, including the one genuine near-miss failure, MAI-Code-1.1-Flash extracted a raw/rounded count matrix instead of constructing `dds` directly from the `SummarizedExperiment`, dropping `tximeta`'s `avgTxLength` offsets, and both the LLM judge and the independent recomputation agree on `max_abs_error ~1.068`, well outside the `1e-3` tolerance.

This is a stronger data point than the synthetic pilot (`data/judge_calibration/pilot/`): a real model produced a real, subtly-wrong analysis (not a mismatched-pair negative control), and the LLM judge's arithmetic checked out against independent recomputation. Worth extending this same eval/judge-prompt pattern to more tasks as they're added, it sidesteps the Biomni/enterprise-credential blocker entirely by using each model's native interface directly.

# Unified Benchmark Evaluation Architecture

## Current Implementation

``` text
eval.json
    ↓
reference output
    ↓
candidate output
    ↓
numeric comparator
    ↓
mechanical rubric checks
    ↓
NEEDS_JUDGE for everything else
```

------------------------------------------------------------------------

## Proposed Generalized Architecture

``` mermaid
flowchart TD
    A["Benchmark Task Spec"]

    A --> B["Agent Execution"]
    A --> C["Evaluation"]

    B --> D["Plan"]
    B --> E["Code"]
    B --> F["Trace"]

    D --> G["Candidate Outputs"]
    E --> G
    F --> G

    C --> H["Evaluator Registry"]

    G --> H

    H --> I["Mechanical Evaluators"]
    H --> J["Domain / Result Evaluators"]
    H --> K["Semantic / Judge Evaluators"]

    I --> I1["File Present"]
    I --> I2["Parseable"]
    I --> I3["Paths"]
    I --> I4["Leakage"]
    I --> I5["Script"]

    J --> J1["Matrix / List / Labels"]
    J --> J2["Embedding"]
    J --> J3["Clustering"]
    J --> J4["Variants"]
    J --> J5["DE Results"]

    K --> K1["Plan Quality"]
    K --> K2["Biological Logic"]
    K --> K3["Code Quality"]
    K --> K4["Tool Choice"]
    K --> K5["Interpretation"]

    I --> L["Unified Rubric"]
    J --> L
    K --> L

    L --> M["Task + Dimension Scores"]
    M --> N["Robustness / Failure Diagnostics"]
```

------------------------------------------------------------------------

## Evaluation Pipeline

``` text
Benchmark Task Spec
        │
        ├── Agent Execution
        │     ├── Plan
        │     ├── Code
        │     └── Trace
        │
        └── Evaluation
               │
               ├── Candidate Outputs
               └── Evaluator Registry
                      ├── Mechanical Evaluators
                      │      • File present
                      │      • Parseable
                      │      • Paths
                      │      • Leakage
                      │      • Script
                      │
                      ├── Domain / Result Evaluators
                      │      • Matrix/List/Labels
                      │      • Embedding
                      │      • Clustering
                      │      • Variants
                      │      • DE Results
                      │
                      └── Semantic / Judge Evaluators
                             • Plan quality
                             • Biological logic
                             • Code quality
                             • Tool choice
                             • Interpretation

All evaluator outputs are aggregated into a **Unified Rubric**, producing:

- Task score
- Dimension scores
- Robustness diagnostics
- Failure diagnostics
```

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

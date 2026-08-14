# Benchmark Results: bioc-1-a

- **Task ID**: `bioc-1-a`
- **Gold Standard Reference**: [`ref_answer/sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/ref_answer/sample_dist_matrix.csv)
- **Reference Script**: [`ref_script/sample_dist_matrix.R`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/ref_script/sample_dist_matrix.R)
- **Evaluation Criteria**: [`eval.json`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/eval.json)

---

## 1. Task Summary

Using the provided RNA-seq gene-level `SummarizedExperiment` dataset (`data/gse.rds`), models were required to:
1. Construct a `DESeqDataSet` object with design formula `~ cell + dex` (renaming `donor` to `cell`, `condition` to `dex`, setting levels `'untrt'` and `'trt'` with `'untrt'` as reference).
2. Pre-filter to retain genes with counts $\ge 10$ in at least 4 samples.
3. Apply variance stabilizing transformation (`vst(dds, blind = FALSE)`).
4. Compute the Euclidean sample-to-sample distance matrix.
5. Save the distance matrix as `sample_dist_matrix.csv` with row names formatted as `<dex> - <cell>` and column names set to `NULL`.

---

## 2. Integrated Benchmark Results

| Model / Agent | Output File | Solution Script | Row Names Format | Dimensions | Max Absolute Error | Mean Absolute Error | Tolerance ($\le 10^{-3}$) | Overall Verdict | Detailed Summary |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Claude-Sonnet-5** | Yes | Yes | PASS (`<dex> - <cell>`) | $8 \times 8$ | $4.26 \times 10^{-14}$ | $2.15 \times 10^{-14}$ | **PASS** | **PASS** | [`answer/Claude-Sonnet-5/summary.md`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Claude-Sonnet-5/summary.md) |
| **Gemini-3.7-Flash** | Yes | Yes | PASS (`<dex> - <cell>`) | $8 \times 8$ | $4.26 \times 10^{-14}$ | $2.15 \times 10^{-14}$ | **PASS** | **PASS** | [`answer/Gemini-3.7-Flash/summary.md`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Gemini-3.7-Flash/summary.md) |
| **gpt-5** | Yes | No | PASS (`<dex> - <cell>`) | $8 \times 8$ | $4.26 \times 10^{-14}$ | $2.15 \times 10^{-14}$ | **PASS** | **PASS** | [`answer/gpt-5/summary.md`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/gpt-5/summary.md) |
| **MAI-Code-1.1-Flash** | Yes | No | PASS (`<dex> - <cell>`) | $8 \times 8$ | $1.068174$ | $0.376443$ | **FAIL** | **FAIL** | [`answer/MAI-Code-1.1-Flash/summary.md`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/MAI-Code-1.1-Flash/summary.md) |
| **STELLA_gemini_3_flash** | Yes | Yes | PASS (`<dex> - <cell>`) | $8 \times 8$ | $7.82 \times 10^{-14}$ | $2.78 \times 10^{-14}$ | **PASS** | **PASS** | [`answer/STELLA_gemini_3_flash/summary.md`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/STELLA_gemini_3_flash/summary.md) |

---

## 3. Individual Model Findings

### 3.1 [Claude-Sonnet-5](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Claude-Sonnet-5)
- **Verdict**: **PASS**
- **Artifacts**: [`solution.R`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Claude-Sonnet-5/solution.R), [`sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Claude-Sonnet-5/sample_dist_matrix.csv)
- **Analysis**: Correctly instantiated `DESeqDataSet` directly from the `SummarizedExperiment` object, retaining `avgTxLength` offsets. Results match the reference to machine precision ($\max \Delta \approx 4.26 \times 10^{-14}$).

### 3.2 [Gemini-3.7-Flash](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Gemini-3.7-Flash)
- **Verdict**: **PASS**
- **Artifacts**: [`solution.R`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Gemini-3.7-Flash/solution.R), [`sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/Gemini-3.7-Flash/sample_dist_matrix.csv)
- **Analysis**: Re-generated solution properly handled metadata factor mapping, preserved transcript-length offsets via `DESeqDataSet(gse, ...)`, and matched the gold standard within numerical tolerance ($\max \Delta \approx 4.26 \times 10^{-14}$).

### 3.3 [gpt-5](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/gpt-5)
- **Verdict**: **PASS**
- **Artifacts**: [`sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/gpt-5/sample_dist_matrix.csv)
- **Analysis**: Matrix calculations match gold standard to machine precision ($\max \Delta \approx 4.26 \times 10^{-14}$). The output strictly omitted the column header row to satisfy `colnames set to NULL`.

### 3.4 [MAI-Code-1.1-Flash](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/MAI-Code-1.1-Flash)
- **Verdict**: **FAIL**
- **Artifacts**: [`sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/MAI-Code-1.1-Flash/sample_dist_matrix.csv)
- **Root Cause**: Extracted a raw/rounded count matrix (`DESeqDataSetFromMatrix(round(assay(gse)), ...)`) rather than constructing `dds` directly from `gse`. This dropped `tximeta`'s `avgTxLength` assay, causing `vst(dds, blind = FALSE)` to calculate standard library size factors instead of transcript length corrections ($\max \Delta = 1.068174 > 10^{-3}$).

### 3.5 [STELLA_gemini_3_flash](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/STELLA_gemini_3_flash)
- **Verdict**: **PASS**
- **Artifacts**: [`solution.R`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/STELLA_gemini_3_flash/solution.R), [`sample_dist_matrix.csv`](file:///home/mramos/gh/LLM_BioBenchmarking/tasks/bioc-1-a/answer/STELLA_gemini_3_flash/sample_dist_matrix.csv)
- **Analysis**: Correctly created `DESeqDataSet` directly from `gse` with formula `~ cell + dex`, mapped conditions to `'untrt'` (reference) and `'trt'`, filtered with `rowSums(counts(dds) >= 10) >= 4`, computed Euclidean distances on VST assay, and saved matrix without column headers. Matches the reference within tolerance ($\max \Delta \approx 7.82 \times 10^{-14} \le 10^{-3}$).

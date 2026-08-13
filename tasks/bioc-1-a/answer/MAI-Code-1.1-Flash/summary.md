# Evaluation Summary: bioc-1-a (MAI-Code-1.1-Flash)

- **Task ID**: `bioc-1-a`
- **Model / Agent**: `MAI-Code-1.1-Flash`
- **Evaluation Criteria**: `eval.json`
- **Gold Standard Reference**: `ref_answer/sample_dist_matrix.csv`
- **Agent Output File**: `answer/MAI-Code-1.1-Flash/sample_dist_matrix.csv`

---

## 1. Executive Summary

| Criterion | Status | Details |
| :--- | :---: | :--- |
| **Output File Presence** | **PASS** | Expected file `sample_dist_matrix.csv` is present. |
| **Matrix Dimensions** | **PASS** | 8 samples × 8 samples Euclidean distance matrix. |
| **Row Names Format & Order** | **PASS** | Matches `<dex> - <cell>` format and exact sample ordering. |
| **Column Names / Formatting** | **PASS** | CSV saved without column header (8 data rows). |
| **Numerical Accuracy** | **FAIL** | Max absolute error: $1.068174 > 10^{-3}$ tolerance. |
| **Overall Verdict** | **FAIL** | **Numerical tolerance exceeded.** |

---

## 2. Detailed Criteria Evaluation

### 2.1 File Presence & Output
- **Target File**: `answer/MAI-Code-1.1-Flash/sample_dist_matrix.csv` (Found)

### 2.2 Row Names & Formatting
- **Specification**: Format `<dex> - <cell>` with factor levels `untrt` and `trt` (`untrt` as reference).
- **Observed Row Names**:
  1. `untrt - N61311`
  2. `trt - N61311`
  3. `untrt - N052611`
  4. `trt - N052611`
  5. `untrt - N080611`
  6. `trt - N080611`
  7. `untrt - N061011`
  8. `trt - N061011`
- **Result**: **PASS** (Exact match in format and sequence).

### 2.3 Numerical Accuracy & Tolerance
- **Guideline**: Euclidean distances computed on VST-transformed counts with numerical tolerance $\le 10^{-3}$.
- **Max Absolute Error**: $1.068174$
- **Mean Absolute Error**: $0.376443$
- **Median Absolute Error**: $0.408005$
- **Tolerance Threshold**: $0.001$ ($10^{-3}$)
- **Result**: **FAIL** (Differences exceed threshold by up to ~3 orders of magnitude).

---

## 3. Root Cause Analysis

### Why did the numerical values diverge from the reference?

1. **SummarizedExperiment Object vs. Count Matrix Extraction**:
   - The input `gse.rds` is a `tximeta`-generated `SummarizedExperiment` containing both `counts` and `avgTxLength` assays.
   - In the reference workflow (`ref_script/sample_dist_matrix.R`), the `DESeqDataSet` is created directly from `gse`:
     ```r
     dds <- DESeqDataSet(gse, design = ~ cell + dex)
     ```
     This instructs `DESeq2` to use `avgTxLength` to incorporate transcript-length normalization offsets.

2. **Agent Coercion**:
   - `MAI-Code-1.1-Flash` converted the assay to a raw integer/count matrix (e.g., via `DESeqDataSetFromMatrix(round(assay(gse)), colData = colData(gse), ...)`).
   - Dropping the `avgTxLength` assay caused `vst(dds, blind = FALSE)` to compute standard library size factors instead of length-adjusted normalization offsets.

3. **Empirical Verification**:
   - Re-running the pipeline using `DESeqDataSetFromMatrix(countData = round(assay(gse)), ...)` reproduces `MAI-Code-1.1-Flash`'s distance matrix to machine precision (max difference $< 5 \times 10^{-14}$).

---

## 4. Absolute Difference Matrix ($|\text{Model} - \text{Reference}|$)

| Sample | untrt - N61311 | trt - N61311 | untrt - N052611 | trt - N052611 | untrt - N080611 | trt - N080611 | untrt - N061011 | trt - N061011 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **untrt - N61311** | 0.000000 | 0.201700 | 0.512668 | 1.068174 | 0.020034 | 0.519793 | 0.538292 | 0.530049 |
| **trt - N61311**   | 0.201700 | 0.000000 | 0.158573 | 0.425968 | 0.438987 | 0.322405 | 0.122460 | 0.513773 |
| **untrt - N052611** | 0.512668 | 0.158573 | 0.000000 | 0.384431 | 0.114939 | 0.582899 | 0.615193 | 0.509342 |
| **trt - N052611**   | 1.068174 | 0.425968 | 0.384431 | 0.000000 | 0.770783 | 0.012411 | 0.776464 | 0.765565 |
| **untrt - N080611** | 0.020034 | 0.438987 | 0.114939 | 0.770783 | 0.000000 | 0.052457 | 0.053751 | 0.897021 |
| **trt - N080611**   | 0.519793 | 0.322405 | 0.582899 | 0.012411 | 0.052457 | 0.000000 | 0.635209 | 0.390041 |
| **untrt - N061011** | 0.538292 | 0.122460 | 0.615193 | 0.776464 | 0.053751 | 0.635209 | 0.000000 | 0.112779 |
| **trt - N061011**   | 0.530049 | 0.513773 | 0.509342 | 0.765565 | 0.897021 | 0.390041 | 0.112779 | 0.000000 |

---

## 5. Recommendation / Correction

To achieve values within the $\le 10^{-3}$ tolerance, supply the `SummarizedExperiment` directly to `DESeqDataSet`:

```r
gse <- readRDS("tasks/bioc-1-a/data/gse.rds")
colData(gse)$cell <- colData(gse)$donor
colData(gse)$dex <- factor(colData(gse)$condition,
                           levels = c("Untreated", "Dexamethasone"),
                           labels = c("untrt", "trt"))
colData(gse)$dex <- relevel(colData(gse)$dex, ref = "untrt")

dds <- DESeqDataSet(gse, design = ~ cell + dex)
dds <- dds[rowSums(counts(dds) >= 10) >= 4, ]
vsd <- vst(dds, blind = FALSE)

sample_dists <- dist(t(assay(vsd)))
sample_dist_matrix <- as.matrix(sample_dists)
rownames(sample_dist_matrix) <- paste(vsd$dex, vsd$cell, sep = " - ")
colnames(sample_dist_matrix) <- NULL
```

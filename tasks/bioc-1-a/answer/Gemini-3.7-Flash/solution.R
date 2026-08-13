# Solution for bioc-1-a using Gemini 3.7 Flash
suppressPackageStartupMessages({
  library(SummarizedExperiment)
  library(DESeq2)
})

# Load the SummarizedExperiment dataset
gse_path <- "tasks/bioc-1-a/data/gse.rds"
gse <- readRDS(gse_path)

# Prepare colData: rename donor to cell, condition to dex, and ensure factor levels
if ("donor" %in% colnames(colData(gse))) {
  gse$cell <- gse$donor
}
if ("condition" %in% colnames(colData(gse))) {
  # Map or ensure dex factor levels 'untrt' and 'trt' with 'untrt' as reference
  if (!"dex" %in% colnames(colData(gse))) {
    levels_map <- c("Untreated" = "untrt", "Dexamethasone" = "trt")
    gse$dex <- factor(levels_map[as.character(gse$condition)], levels = c("untrt", "trt"))
  } else {
    gse$dex <- factor(gse$dex, levels = c("untrt", "trt"))
  }
}

# Construct DESeqDataSet
dds <- DESeqDataSet(gse, design = ~ cell + dex)

# Pre-filter to retain genes with counts >= 10 in at least 4 samples
keep <- rowSums(counts(dds) >= 10) >= 4
dds <- dds[keep, ]

# Apply variance stabilizing transformation with blind = FALSE
vsd <- vst(dds, blind = FALSE)

# Compute Euclidean sample-to-sample distance matrix
sampleDists <- dist(t(assay(vsd)))
sampleDistMatrix <- as.matrix(sampleDists)

# Format row names as '<dex> - <cell>' and set column names to NULL
rownames(sampleDistMatrix) <- paste(vsd$dex, vsd$cell, sep = " - ")
colnames(sampleDistMatrix) <- NULL

# Save distance matrix to CSV
output_dir <- "tasks/bioc-1-a/answer/Gemini-3.7-Flash"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}
output_file <- file.path(output_dir, "sample_dist_matrix.csv")
write.csv(sampleDistMatrix, file = output_file)

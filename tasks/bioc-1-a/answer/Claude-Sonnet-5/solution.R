suppressMessages({
  library(SummarizedExperiment)
  library(DESeq2)
})

gse <- readRDS("tasks/bioc-1-a/data/gse.rds")

# rename donor -> cell, condition -> dex, set dex reference level to "untrt"
colData(gse)$cell <- colData(gse)$donor
colData(gse)$dex <- factor(colData(gse)$condition,
                            levels = c("Untreated", "Dexamethasone"),
                            labels = c("untrt", "trt"))
colData(gse)$dex <- relevel(colData(gse)$dex, ref = "untrt")

dds <- DESeqDataSet(gse, design = ~ cell + dex)

# pre-filter: keep genes with counts >= 10 in at least 4 samples
keep <- rowSums(counts(dds) >= 10) >= 4
dds <- dds[keep, ]

vsd <- vst(dds, blind = FALSE)

sample_dists <- dist(t(assay(vsd)))
sample_dist_matrix <- as.matrix(sample_dists)

rownames(sample_dist_matrix) <- paste(vsd$dex, vsd$cell, sep = " - ")
colnames(sample_dist_matrix) <- NULL

write.csv(sample_dist_matrix, "tasks/bioc-1-a/answer/Claude-Sonnet-5/sample_dist_matrix.csv")

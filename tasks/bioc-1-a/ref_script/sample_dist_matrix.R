library("airway")
library("magrittr")
library("DESeq2")

# Load full gse data from airway package
data(gse)

# Rename colData variables
gse$cell <- gse$donor
gse$dex <- gse$condition

# Rename factor levels and set reference level
levels(gse$dex) <- c("untrt", "trt")
gse$dex %<>% relevel("untrt")

### save RDS object
saveRDS(gse, file = "tasks/bioc-1-a/data/gse.rds")

# Construct DESeqDataSet object
dds <- DESeqDataSet(gse, design = ~ cell + dex)

# Pre-filtering the dataset
smallestGroupSize <- 4
keep <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[keep, ]

# Variance stabilizing transformation
vsd <- vst(dds, blind = FALSE)

# Compute sample distances and construct distance matrix
sampleDists <- dist(t(assay(vsd)))
sampleDistMatrix <- as.matrix(sampleDists)
rownames(sampleDistMatrix) <- paste(vsd$dex, vsd$cell, sep = " - ")
colnames(sampleDistMatrix) <- NULL

## Save sample distance matrix as CSV
readr::write_csv(as.data.frame(sampleDistMatrix), "tasks/bioc-1-a/data/sample_dist_matrix.csv")

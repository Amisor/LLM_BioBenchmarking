library(DESeq2)
library(SummarizedExperiment)

# Load the data
gse <- readRDS("tasks/bioc-1-a/data/gse.rds")

# Rename columns in colData
colData(gse)$cell <- colData(gse)$donor
colData(gse)$dex <- colData(gse)$condition

# Map original condition levels to required levels
# Original levels: 'Untreated', 'Dexamethasone'
# Target levels: 'untrt', 'trt'
colData(gse)$dex <- ifelse(colData(gse)$dex == "Untreated", "untrt", "trt")
colData(gse)$dex <- factor(colData(gse)$dex, levels = c("untrt", "trt"))

# Construct DESeqDataSet
dds <- DESeqDataSet(gse, design = ~ cell + dex)

# Pre-filter: counts >= 10 in at least 4 samples
keep <- rowSums(counts(dds) >= 10) >= 4
dds <- dds[keep,]

# VST transformation
vsd <- vst(dds, blind = FALSE)

# Compute Euclidean distance matrix
sampleDists <- dist(t(assay(vsd)))
sampleDistMatrix <- as.matrix(sampleDists)

# Format row names: <dex> - <cell>
rownames(sampleDistMatrix) <- paste(vsd$dex, "-", vsd$cell)
colnames(sampleDistMatrix) <- NULL

# Create output directory
dir.create("tasks/bioc-1-a/answer/STELLA_gemini_3_flash", recursive = TRUE, showWarnings = FALSE)

# Save to CSV
write.table(sampleDistMatrix, "tasks/bioc-1-a/answer/STELLA_gemini_3_flash/sample_dist_matrix.csv", 
            sep = ",", col.names = FALSE, row.names = TRUE, quote = FALSE)

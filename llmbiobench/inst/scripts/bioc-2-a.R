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
## saveRDS(gse, file = "tasks/bioc-1-a/data/gse.rds")

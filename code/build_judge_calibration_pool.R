# Build a seed pool for the LLM-judge calibration brainstorm (see documents/ideas.md,
# "LLM-Judge Calibration (Brainstorm)"). Instead of hand-authoring a synthetic gold set,
# this pulls real PromptBio-Bench task/reference material for the output types that
# actually need a judge (image, genuine free text), per the paper's own Supplementary
# Note (csv/tsv/numeric outputs are scored deterministically and don't need one).
#
# Run from the repo root: Rscript code/build_judge_calibration_pool.R

source("code/read_promptbio_huggingface.R")

LOCAL_CACHE_DIR  <- "data/promptbio-bench"
POOL_DIR         <- "data/judge_calibration"
IMAGE_TYPES      <- c("png", "jpg", "jpeg", "svg", "pdf")

# A first pass tried to exclude only the obviously numeric-disguised "txt" outputs
# (a single scalar, "must match within +/-"). Auditing the full guideline text for
# every txt output across BOTH tracks (27 total) found that is not enough: several
# more are structured multi-field records serialized as .txt (BLAST outfmt6, HOMER
# annotatePeaks, MEME motifs, rMATS splicing events, plasmid maps, clonotype tables),
# scored by field-level match/tolerance, the same shape as a VCF/BED handler, not by
# narrative judgment. In fact NONE of the 27 txt outputs in this dataset are genuine
# narrative prose; every one is a scalar or structured record in a .txt wrapper. So
# rather than deny-list every structured shape we happen to find (whack-a-mole), a
# "txt" only qualifies as a judge candidate if its guideline explicitly asks for
# narrative/semantic comparison, an allow-list, not a deny-list.
NARRATIVE_SIGNAL <- paste(
  "narrative", "explain", "summar(y|ize)", "describe", "prose", "in words",
  "\\breport\\b", "interpretation", "conclusion", "semantic", "key finding",
  "key information", "discussion",
  sep = "|"
)

is_narrative_txt <- function(type, guideline) {
  type == "txt" && grepl(NARRATIVE_SIGNAL, guideline, ignore.case = TRUE)
}

# Prefer the already-downloaded local cache (data/promptbio-bench/tasks/<id>/*.json);
# fall back to a live HuggingFace fetch for anything missing locally.
read_task_cached <- function(task_id, cache_dir = LOCAL_CACHE_DIR) {
  local_task <- file.path(cache_dir, "tasks", task_id, "task.json")
  local_eval <- file.path(cache_dir, "tasks", task_id, "eval.json")

  if (file.exists(local_task) && file.exists(local_eval)) {
    return(list(
      task = jsonlite::fromJSON(local_task, simplifyVector = FALSE),
      eval = jsonlite::fromJSON(local_eval, simplifyVector = FALSE)
    ))
  }

  read_promptbio_task(task_id)
}

# One row per (track, task_id, expected_output entry), with the judge-candidacy
# decision and its reason recorded, not just filtered away silently.
inventory_row <- function(track, task_id, t) {
  eo <- t$task$expected_output
  guidelines <- t$eval$scoring$expected_output

  type <- vapply(eo, function(x) x$type, character(1))
  guideline <- vapply(seq_along(eo), function(i) {
    g <- guidelines[[i]]$guidelines
    if (is.null(g)) "" else g
  }, character(1))

  narrative_txt <- mapply(is_narrative_txt, type, guideline)
  judge_candidate <- (type %in% IMAGE_TYPES) | narrative_txt

  reason <- ifelse(
    type %in% IMAGE_TYPES, "image: always needs scientific-content judging",
    ifelse(type != "txt", "type is deterministically scored (not image/text)",
      ifelse(narrative_txt, "txt guideline explicitly asks for semantic/narrative comparison",
        "txt output is a scalar or structured record, not narrative free text"))
  )

  data.frame(
    track           = track,
    task_id         = task_id,
    file            = vapply(eo, function(x) x$file, character(1)),
    type            = type,
    description     = vapply(eo, function(x) x$description %||% "", character(1)),
    guidelines      = guideline,
    judge_candidate = judge_candidate,
    reason          = reason,
    question        = t$task$question,
    stringsAsFactors = FALSE
  )
}

build_inventory <- function(track) {
  ids <- list_promptbio_task_ids(track)
  message("Scanning ", length(ids), " ", track, "-track tasks...")

  rows <- lapply(ids, function(id) {
    t <- tryCatch(read_task_cached(id), error = function(e) NULL)
    if (is.null(t)) {
      message("  skipped ", id, " (fetch failed)")
      return(NULL)
    }
    tryCatch(inventory_row(track, id, t), error = function(e) {
      message("  skipped ", id, " (unexpected schema: ", conditionMessage(e), ")")
      NULL
    })
  })

  do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
}

inventory <- do.call(rbind, lapply(c("a", "b"), build_inventory))

dir.create(POOL_DIR, recursive = TRUE, showWarnings = FALSE)
write.csv(inventory, file.path(POOL_DIR, "output_inventory.csv"), row.names = FALSE)

judge_pool <- inventory[inventory$judge_candidate, ]
write.csv(judge_pool, file.path(POOL_DIR, "judge_calibration_pool.csv"), row.names = FALSE)

excluded_txt <- inventory[inventory$type == "txt" & !inventory$judge_candidate, ]

message(
  "\n", nrow(inventory), " outputs scanned across ", length(unique(inventory$task_id)),
  " tasks (both tracks); ", nrow(judge_pool), " outputs across ",
  length(unique(judge_pool$task_id)), " tasks are real judge candidates."
)
message(
  nrow(excluded_txt), " of ", sum(inventory$type == "txt"), " txt outputs excluded as ",
  "scalar/structured-record checks in disguise, no narrative-comparison language in ",
  "their guideline (see reason column in output_inventory.csv)."
)
print(table(inventory$track, inventory$type))
print(table(judge_pool$track, judge_pool$type))

# Download the real reference answer for each judge-candidate task, so we have a
# genuine "should score ~1.0" artifact to build calibration items around.
for (task_id in unique(judge_pool$task_id)) {
  eval_json <- tryCatch(read_task_cached(task_id)$eval, error = function(e) NULL)
  if (is.null(eval_json)) next
  for (rel_path in unlist(eval_json$ref_answer)) {
    dest <- file.path(POOL_DIR, "tasks", task_id, rel_path)
    if (file.exists(dest)) next
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    tryCatch({
      file_bytes_url <- promptbio_task_url(task_id, rel_path)
      download.file(file_bytes_url, dest, mode = "wb", quiet = TRUE)
    }, error = function(e) message("  ref_answer download failed for ", task_id, ": ", conditionMessage(e)))
  }
}

message("\nPool written to ", POOL_DIR, "/ (inventory CSV, judge-candidate CSV, reference answers).")

# --- Next steps (not automated here, see ideas.md "Candidate protocol") ---
# 1. For each task in judge_calibration_pool.csv, construct 2-3 candidate answers:
#    the real reference (expect ~1.0), a deliberately wrong/corrupted variant
#    (expect low), and, once code/biomni_query.py's syntax bug is fixed, a live
#    agent output (unknown, the actual case we care about).
# 2. Have 2+ humans score each (question, reference, candidate, guidelines) tuple.
# 3. Run an LLM judge over the same tuples (reuse Guo_2026's judge shape: task
#    description + reference + candidate + guidelines -> score/confidence/verdict).
# 4. Compute weighted Cohen's Kappa or ICC between humans, and between humans and
#    the judge; report both, not just raw percent agreement.

# Build a small, tractable pilot from the 63-item judge_calibration_pool.csv (see
# code/build_judge_calibration_pool.R and documents/ideas.md's "Candidate protocol").
# For each sampled task, produces two candidates against the same reference:
#   - candidate_correct: the real reference answer (should score ~1.0)
#   - candidate_wrong:   another task's reference of the same file type (should
#     score low; a mismatched-pair negative control, cheap and deterministic, no
#     image/text editing required)
# A live agent candidate (the actual unknown case) is deferred until
# code/biomni_query.py's syntax bug is fixed upstream.
#
# Outputs: data/judge_calibration/pilot/<task_id>/candidate_{correct,wrong}.<ext>,
# pilot_manifest.csv (with ground truth, for scoring/analysis), and
# pilot_manifest_blind.csv (candidate order shuffled per item, no ground truth,
# for human labelers).
#
# Run from the repo root: Rscript code/build_calibration_pilot.R

POOL_CSV  <- "data/judge_calibration/judge_calibration_pool.csv"
POOL_DIR  <- "data/judge_calibration"
PILOT_DIR <- file.path(POOL_DIR, "pilot")
N_PILOT   <- 9

set.seed(42)

pool <- read.csv(POOL_CSV, stringsAsFactors = FALSE)

# Stratify: take the one genuine narrative/semantic txt case for sure, fill the
# rest with a random sample of the image candidates so the pilot isn't all one type.
txt_rows   <- pool[pool$type == "txt", ]
image_rows <- pool[pool$type != "txt", ]
n_images   <- N_PILOT - nrow(txt_rows)
pilot <- rbind(txt_rows, image_rows[sample(nrow(image_rows), n_images), ])

# For each pilot row, pick a "wrong" reference: another task's reference of the
# same type, excluding the pilot task itself.
pick_wrong_donor <- function(task_id, type) {
  donors <- pool[pool$type == type & pool$task_id != task_id, ]
  if (nrow(donors) == 0) {
    # Singleton type (e.g. the one txt case): fall back to any other candidate.
    donors <- pool[pool$task_id != task_id, ]
  }
  donors[sample(nrow(donors), 1), ]
}

dir.create(PILOT_DIR, recursive = TRUE, showWarnings = FALSE)

manifest_rows <- list()
for (i in seq_len(nrow(pilot))) {
  row   <- pilot[i, ]
  donor <- pick_wrong_donor(row$task_id, row$type)

  item_dir <- file.path(PILOT_DIR, row$task_id)
  dir.create(item_dir, recursive = TRUE, showWarnings = FALSE)

  correct_src <- file.path(POOL_DIR, "tasks", row$task_id, "ref_answer", row$file)
  wrong_src   <- file.path(POOL_DIR, "tasks", donor$task_id, "ref_answer", donor$file)

  # Use each file's own extension, the "wrong" donor may be a different type
  # (only happens for a singleton type with no same-type donor, see fallback above).
  correct_dest <- file.path(item_dir, paste0("candidate_correct.", tools::file_ext(row$file)))
  wrong_dest   <- file.path(item_dir, paste0("candidate_wrong.", tools::file_ext(donor$file)))

  if (!file.exists(correct_src) || !file.exists(wrong_src)) {
    message("skipping ", row$task_id, ": reference file missing on disk")
    next
  }
  file.copy(correct_src, correct_dest, overwrite = TRUE)
  file.copy(wrong_src, wrong_dest, overwrite = TRUE)

  # Shuffle display order per item so a human labeler doesn't learn "A is always
  # correct" across items.
  order <- sample(c("correct", "wrong"))
  for (slot in seq_along(order)) {
    label <- c("A", "B")[slot]
    is_correct <- order[slot] == "correct"
    manifest_rows[[length(manifest_rows) + 1]] <- data.frame(
      task_id       = row$task_id,
      candidate     = label,
      is_correct    = is_correct,
      wrong_donor   = if (is_correct) NA_character_ else donor$task_id,
      path          = if (is_correct) correct_dest else wrong_dest,
      type          = row$type,
      question      = row$question,
      description   = row$description,
      guidelines    = row$guidelines,
      stringsAsFactors = FALSE
    )
  }
}

manifest <- do.call(rbind, manifest_rows)
write.csv(manifest, file.path(PILOT_DIR, "pilot_manifest.csv"), row.names = FALSE)

blind <- manifest[, setdiff(names(manifest), c("is_correct", "wrong_donor"))]
write.csv(blind, file.path(PILOT_DIR, "pilot_manifest_blind.csv"), row.names = FALSE)

message(
  "\nPilot built: ", length(unique(manifest$task_id)), " tasks, ",
  nrow(manifest), " candidates (2 per task) in ", PILOT_DIR, "/"
)
message("Ground-truth manifest: pilot_manifest.csv (for scoring/analysis, don't hand to labelers)")
message("Blinded manifest for humans: pilot_manifest_blind.csv")

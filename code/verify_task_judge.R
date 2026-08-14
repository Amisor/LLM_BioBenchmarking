# Generalized version of verify_bioc_1_a_judge.R: independently recompute numeric
# verdicts for ANY task under tasks/*/ that has a ref_answer/ CSV/TSV and one or
# more answer/<model>/ candidate files of the same name, and compare against
# whatever an LLM judge claimed (e.g. results.md), without needing a judge for
# tasks whose ground truth is already numeric (per Guo_2026's own format-handler
# taxonomy: csv/tsv outputs are exact/approximate/numeric, not semantic/judge).
#
# Usage:
#   Rscript code/verify_task_judge.R                 # scan every task under tasks/
#   Rscript code/verify_task_judge.R tasks/bioc-1-a   # just one task
#
# This does not parse results.md prose (too task/author-specific to do reliably);
# it prints its own independently-derived table for you to compare by eye.

DEFAULT_TOLERANCE <- 1e-3
TABULAR_EXTENSIONS <- c("csv", "tsv")

# Read a numeric matrix from a csv/tsv, detecting whether the first line is a
# header by checking directly: a real header's non-label fields are names like
# "V1" (not numeric); a data row's non-label fields all parse as numbers. This
# is more reliable than "try header=TRUE, check for NAs", which silently
# misreads a headerless file by consuming its first data row as column names
# without ever producing an NA to catch.
read_numeric_matrix <- function(path) {
  sep <- if (tools::file_ext(path) == "tsv") "\t" else ","

  first_line <- readLines(path, n = 1)
  fields <- strsplit(gsub('"', "", first_line), sep, fixed = TRUE)[[1]]
  non_label_fields <- fields[-1]
  has_header <- length(non_label_fields) == 0 ||
    any(is.na(suppressWarnings(as.numeric(non_label_fields))))

  df <- tryCatch(
    read.csv(path, header = has_header, row.names = 1, check.names = FALSE, sep = sep),
    error = function(e) NULL
  )
  if (is.null(df)) return(NULL)
  m <- suppressWarnings(as.matrix(df))
  storage.mode(m) <- "double"
  if (any(is.na(m))) return(NULL)
  m
}

# Pull a numeric tolerance out of a guideline string if one is stated
# (e.g. "within 1e-3", "within +/-0.001", "within 1%"); falls back to the
# task-suite default otherwise.
extract_tolerance <- function(guideline, default = DEFAULT_TOLERANCE) {
  m <- regmatches(guideline, regexpr("(\\+/-|within)\\s*([0-9.]+e?-?[0-9]*)", guideline, perl = TRUE))
  if (length(m) == 0 || m == "") return(default)
  num <- regmatches(m, regexpr("[0-9.]+e?-?[0-9]*$", m))
  suppressWarnings(as.numeric(num)) %||% default
}
`%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

verify_task <- function(task_dir) {
  eval_path <- file.path(task_dir, "eval.json")
  if (!file.exists(eval_path)) {
    message(task_dir, ": no eval.json, skipping")
    return(invisible(NULL))
  }
  eval_json <- jsonlite::fromJSON(eval_path, simplifyVector = FALSE)
  answer_dirs <- list.dirs(file.path(task_dir, "answer"), recursive = FALSE)
  if (length(answer_dirs) == 0) {
    message(task_dir, ": no answer/ submissions yet, skipping")
    return(invisible(NULL))
  }

  cat("\n==", task_dir, "==\n")

  for (output_spec in eval_json$scoring$expected_output) {
    fname <- output_spec$file
    ext <- tolower(tools::file_ext(fname))
    if (!(ext %in% TABULAR_EXTENSIONS)) {
      cat("  ", fname, ": type '", ext, "' is not tabular, needs its own handler ",
          "(image/text -> judge; sequence/alignment formats -> a format-specific ",
          "comparator), not scored here.\n", sep = "")
      next
    }

    ref_path <- file.path(task_dir, "ref_answer", fname)
    if (!file.exists(ref_path)) {
      message("  ", fname, ": no reference file at ", ref_path, ", skipping")
      next
    }
    ref <- read_numeric_matrix(ref_path)
    if (is.null(ref)) {
      message("  ", fname, ": couldn't parse reference as numeric, skipping")
      next
    }
    tol <- extract_tolerance(output_spec$guidelines %||% "")

    rows <- list()
    for (dir in answer_dirs) {
      model <- basename(dir)
      cand_path <- file.path(dir, fname)
      if (!file.exists(cand_path)) next
      cand <- read_numeric_matrix(cand_path)
      if (is.null(cand)) {
        rows[[length(rows) + 1]] <- data.frame(model = model, max_abs_error = NA,
                                                mean_abs_error = NA, verdict = "UNPARSEABLE")
        next
      }
      if (!identical(dim(cand), dim(ref))) {
        rows[[length(rows) + 1]] <- data.frame(model = model, max_abs_error = NA,
                                                mean_abs_error = NA,
                                                verdict = paste0("DIM_MISMATCH(", paste(dim(cand), collapse = "x"), ")"))
        next
      }
      if (!is.null(rownames(cand)) && !is.null(rownames(ref)) && all(rownames(cand) %in% rownames(ref))) {
        cand <- cand[rownames(ref), , drop = FALSE]
      }
      diff <- abs(cand - ref)
      max_err <- max(diff)
      rows[[length(rows) + 1]] <- data.frame(
        model = model, max_abs_error = max_err, mean_abs_error = mean(diff),
        verdict = if (max_err <= tol) "PASS" else "FAIL"
      )
    }

    if (length(rows) == 0) next
    cat("  ", fname, " (tolerance <= ", tol, "):\n", sep = "")
    print(do.call(rbind, rows), row.names = FALSE)
  }
}

args <- commandArgs(trailingOnly = TRUE)
task_dirs <- if (length(args) >= 1) args else list.dirs("tasks", recursive = FALSE)
invisible(lapply(task_dirs, verify_task))

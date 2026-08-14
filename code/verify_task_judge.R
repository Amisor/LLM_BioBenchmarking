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

# --- Mechanical rubric pre-checks (eval_v2.json style: scoring$rubric[]) ---
#
# Not every rubric criterion needs an LLM judge. A handful are checkable by
# plain file/text inspection: is the output present, does it parse to the
# right shape, does it match the reference within tolerance, does the script
# avoid reading the answer key, does it avoid hardcoded absolute paths, is a
# script even present. Everything else (correct formula, correct filtering
# logic, "avoids unnecessary steps", etc.) genuinely requires reading and
# understanding the code, that's real judge territory, not a mechanical check.
# Criteria are matched by keyword in their id/text, not by exact id, so this
# keeps working if a future task's eval_v2.json phrases things slightly
# differently.

find_script_files <- function(dir) {
  list.files(dir, pattern = "\\.(R|r|py|sh|jl)$", full.names = TRUE)
}

read_lines_safe <- function(path) {
  tryCatch(readLines(path, warn = FALSE), error = function(e) character(0))
}

check_reference_leakage <- function(scripts) {
  if (length(scripts) == 0) return(NA)
  # Deliberately narrow: every valid submission legitimately WRITES its own
  # output under answer/<model>/, per evalprompt.txt's own instructions, so a
  # broad "/answer/" pattern would flag every correct script as a false
  # positive (confirmed against a real submission before narrowing this).
  # Only match substrings that indicate READING the answer key specifically.
  leak_pattern <- "ref_answer|ref_script|eval\\.json|eval_v2\\.json"
  hits <- unlist(lapply(scripts, function(f) grep(leak_pattern, read_lines_safe(f), value = TRUE)))
  length(hits) == 0
}

check_relative_paths <- function(scripts) {
  if (length(scripts) == 0) return(NA)
  abs_pattern <- "[\"'](/Users/|/home/|[A-Za-z]:\\\\\\\\)"
  hits <- unlist(lapply(scripts, function(f) grep(abs_pattern, read_lines_safe(f), value = TRUE)))
  length(hits) == 0
}

check_output_present <- function(answer_dir, expected_files) {
  length(expected_files) > 0 && all(file.exists(file.path(answer_dir, expected_files)))
}

check_script_present <- function(scripts) {
  length(scripts) > 0
}

# Dispatch a single rubric criterion to a mechanical check, or flag it as
# needing an LLM judge. Matches on the criterion `id` only, not the free-text
# `criterion` prose: matching against prose risks accidental hits (e.g. a
# criterion about row-name formatting happens to contain both "required" and
# "output" as unrelated words, which a loose "required.*output" pattern would
# mis-dispatch as an output-presence check). An id is a deliberate label, so
# it is the safer, more precise thing to pattern-match against.
#
# `numeric_status`/`rowname_status` are this model's already-computed
# tabular-output verdicts for the task (NULL if none applies).
mechanical_check <- function(criterion, answer_dir, scripts, expected_files, numeric_status, rowname_status) {
  id <- tolower(criterion$id %||% "")

  if (grepl("leak", id)) {
    return(list(checkable = TRUE, result = check_reference_leakage(scripts)))
  }
  if (grepl("relative_path|hardcod", id)) {
    return(list(checkable = TRUE, result = check_relative_paths(scripts)))
  }
  if (grepl("^script_present$", id)) {
    return(list(checkable = TRUE, result = check_script_present(scripts)))
  }
  if (grepl("^required_output_present$|^output_present$", id)) {
    return(list(checkable = TRUE, result = check_output_present(answer_dir, expected_files)))
  }
  if (grepl("parseable|numeric.*matrix|correct_shape|correct_dimension", id)) {
    if (is.null(numeric_status)) return(list(checkable = FALSE, result = NA))
    return(list(checkable = TRUE, result = !(numeric_status %in% c("UNPARSEABLE") | grepl("DIM_MISMATCH", numeric_status))))
  }
  if (grepl("matches_reference_values", id)) {
    if (is.null(numeric_status)) return(list(checkable = FALSE, result = NA))
    return(list(checkable = TRUE, result = identical(numeric_status, "PASS")))
  }
  if (grepl("row_name|rowname", id)) {
    if (is.null(rowname_status)) return(list(checkable = FALSE, result = NA))
    return(list(checkable = TRUE, result = rowname_status))
  }

  list(checkable = FALSE, result = NA)
}

run_mechanical_rubric <- function(task_dir, answer_dirs, numeric_status_by_model, rowname_status_by_model) {
  eval_v2_path <- file.path(task_dir, "eval_v2.json")
  if (!file.exists(eval_v2_path)) return(invisible(NULL))

  eval_v2 <- jsonlite::fromJSON(eval_v2_path, simplifyVector = FALSE)
  rubric <- eval_v2$scoring$rubric
  if (is.null(rubric) || length(rubric) == 0) return(invisible(NULL))

  expected_files <- vapply(eval_v2$scoring$expected_output, function(x) x$file, character(1))

  cat("\n  Rubric pre-check (eval_v2.json,", length(rubric), "criteria):\n")

  n_checkable <- 0
  weight_checkable <- 0
  total_weight <- 0

  for (criterion in rubric) {
    weight <- criterion$weight %||% 1
    total_weight <- total_weight + weight
    dispatch <- mechanical_check(criterion, answer_dirs[1], find_script_files(answer_dirs[1]),
                                  expected_files, numeric_status_by_model[[basename(answer_dirs[1])]],
                                  rowname_status_by_model[[basename(answer_dirs[1])]])
    if (dispatch$checkable) {
      n_checkable <- n_checkable + 1
      weight_checkable <- weight_checkable + weight
    }
  }

  cat("  ", n_checkable, "of", length(rubric), "criteria (", weight_checkable, "of", total_weight,
      "total weight) are mechanically checkable, no judge needed for those.\n\n")

  for (dir in answer_dirs) {
    model <- basename(dir)
    scripts <- find_script_files(dir)
    rows <- lapply(rubric, function(criterion) {
      dispatch <- mechanical_check(criterion, dir, scripts, expected_files, numeric_status_by_model[[model]],
                                    rowname_status_by_model[[model]])
      data.frame(
        criterion = criterion$id %||% "?",
        weight = criterion$weight %||% 1,
        checkable = dispatch$checkable,
        result = if (!dispatch$checkable) "NEEDS_JUDGE" else if (is.na(dispatch$result)) "N/A" else if (dispatch$result) "PASS" else "FAIL"
      )
    })
    cat("  --", model, "--\n")
    print(do.call(rbind, rows), row.names = FALSE)
    cat("\n")
  }
}

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

  numeric_status_by_model <- list()
  rowname_status_by_model <- list()

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
        numeric_status_by_model[[model]] <- "UNPARSEABLE"
        next
      }
      if (!identical(dim(cand), dim(ref))) {
        verdict <- paste0("DIM_MISMATCH(", paste(dim(cand), collapse = "x"), ")")
        rows[[length(rows) + 1]] <- data.frame(model = model, max_abs_error = NA,
                                                mean_abs_error = NA, verdict = verdict)
        numeric_status_by_model[[model]] <- verdict
        next
      }
      rownames_match <- !is.null(rownames(cand)) && !is.null(rownames(ref)) &&
        setequal(rownames(cand), rownames(ref))
      rowname_status_by_model[[model]] <- rownames_match
      if (rownames_match) {
        cand <- cand[rownames(ref), , drop = FALSE]
      }
      diff <- abs(cand - ref)
      max_err <- max(diff)
      verdict <- if (max_err <= tol) "PASS" else "FAIL"
      rows[[length(rows) + 1]] <- data.frame(
        model = model, max_abs_error = max_err, mean_abs_error = mean(diff), verdict = verdict
      )
      numeric_status_by_model[[model]] <- verdict
    }

    if (length(rows) == 0) next
    cat("  ", fname, " (tolerance <= ", tol, "):\n", sep = "")
    print(do.call(rbind, rows), row.names = FALSE)
  }

  run_mechanical_rubric(task_dir, answer_dirs, numeric_status_by_model, rowname_status_by_model)
}

args <- commandArgs(trailingOnly = TRUE)
task_dirs <- if (length(args) >= 1) args else list.dirs("tasks", recursive = FALSE)
invisible(lapply(task_dirs, verify_task))

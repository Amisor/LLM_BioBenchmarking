#' @importFrom tools file_ext
#' @importFrom jsonlite fromJSON
#' @importFrom utils read.csv write.csv
NULL

# Ported from code/verify_task_judge.R (repository root), which remains the
# standalone, multi-task CLI entry point; this file exposes the same,
# already-tested logic as callable package functions operating on a single
# test directory, so it can run right after bench_rubric()/bench_task()
# rather than only as an after-the-fact script.

.read_numeric_matrix <- function(path) {
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
    suppressWarnings(storage.mode(m) <- "double")
    if (any(is.na(m))) return(NULL)
    m
}

.extract_tolerance <- function(guideline, default = 1e-3) {
    m <- regmatches(guideline, regexpr("(\\+/-|within)\\s*([0-9.]+e?-?[0-9]*)", guideline, perl = TRUE))
    if (length(m) == 0 || m == "") return(default)
    num <- regmatches(m, regexpr("[0-9.]+e?-?[0-9]*$", m))
    val <- suppressWarnings(as.numeric(num))
    if (length(val) == 0 || is.na(val)) default else val
}

.find_script_files <- function(dir) {
    list.files(dir, pattern = "\\.(R|r|py|sh|jl)$", full.names = TRUE)
}

.read_lines_safe <- function(path) {
    tryCatch(readLines(path, warn = FALSE), error = function(e) character(0))
}

.check_reference_leakage <- function(scripts) {
    if (length(scripts) == 0) return(NA)
    leak_pattern <- "ref_answer|ref_script|eval\\.json|eval_v2\\.json"
    hits <- unlist(lapply(scripts, function(f) grep(leak_pattern, .read_lines_safe(f), value = TRUE)))
    length(hits) == 0
}

.check_relative_paths <- function(scripts) {
    if (length(scripts) == 0) return(NA)
    abs_pattern <- "[\"'](/Users/|/home/|[A-Za-z]:\\\\\\\\)"
    hits <- unlist(lapply(scripts, function(f) grep(abs_pattern, .read_lines_safe(f), value = TRUE)))
    length(hits) == 0
}

.read_fasta <- function(path) {
    lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) NULL)
    if (is.null(lines)) return(NULL)
    lines <- lines[nzchar(trimws(lines))]
    if (length(lines) == 0 || !startsWith(lines[1], ">")) return(NULL)

    header_idx <- grep("^>", lines)
    if (length(header_idx) == 0) return(NULL)
    headers <- sub("^>\\s*", "", lines[header_idx])
    starts <- header_idx + 1
    ends <- c(header_idx[-1] - 1, length(lines))

    # Sequence content, upper-cased and with all whitespace/line-wrapping
    # removed, per the corpus's own guideline wording ("case and line-wrap
    # may differ").
    seqs <- unlist(Map(function(s, e) {
        if (s > e) return("")
        toupper(paste(trimws(lines[s:e]), collapse = ""))
    }, starts, ends), use.names = FALSE)
    names(seqs) <- headers
    seqs
}

.compare_fasta <- function(ref, cand) {
    if (is.null(cand))
        return(list(verdict = "UNPARSEABLE", max_abs_error = NA, mean_abs_error = NA))
    # Compared as a multiset of sequences, not matched by header: headers are
    # descriptive text the corpus doesn't require to match verbatim, only
    # the sequence content and record count do (see e.g. a-1-12's guideline,
    # "All Paenibacillus sequence records must match the reference"). Case
    # is normalized here too (not just in .read_fasta()), so this function
    # is correct on its own rather than relying on the caller having already
    # normalized -- "case ... may differ" per the corpus's own guidelines.
    ref_seqs <- sort(toupper(unname(ref)))
    cand_seqs <- sort(toupper(unname(cand)))
    verdict <- if (identical(ref_seqs, cand_seqs)) "PASS" else "FAIL"
    list(verdict = verdict, max_abs_error = NA, mean_abs_error = NA)
}

.read_generic_table <- function(path) {
    sep <- if (tools::file_ext(path) == "tsv") "\t" else ","
    df <- tryCatch(
        read.csv(path, header = TRUE, check.names = FALSE, sep = sep, stringsAsFactors = FALSE),
        error = function(e) NULL
    )
    if (is.null(df) || ncol(df) < 1) return(NULL)
    df
}

# A relaxed alternative to .read_numeric_matrix()'s all-numeric requirement:
# matches rows by the first column as a string key, then compares each
# shared column numerically (within tolerance) if the reference column
# parses as numeric, else as a trimmed, case-insensitive string.
.compare_tables <- function(ref, cand, tol) {
    if (is.null(cand) || ncol(ref) == 0 || ncol(cand) == 0)
        return(list(verdict = "UNPARSEABLE", max_abs_error = NA, mean_abs_error = NA))

    key_col_ref <- names(ref)[1]
    ref_keys <- as.character(ref[[key_col_ref]])
    cand_keys <- as.character(cand[[names(cand)[1]]])

    if (anyDuplicated(ref_keys) || anyDuplicated(cand_keys) || !setequal(ref_keys, cand_keys))
        return(list(verdict = "FAIL", max_abs_error = NA, mean_abs_error = NA))

    cand_ord <- cand[match(ref_keys, cand_keys), , drop = FALSE]
    shared_cols <- setdiff(intersect(names(ref), names(cand)), key_col_ref)
    missing_cols <- setdiff(names(ref), names(cand))

    all_ok <- length(missing_cols) == 0
    max_err <- NA_real_
    for (col in shared_cols) {
        ref_num <- suppressWarnings(as.numeric(ref[[col]]))
        if (!anyNA(ref_num)) {
            cand_num <- suppressWarnings(as.numeric(cand_ord[[col]]))
            if (anyNA(cand_num)) { all_ok <- FALSE; next }
            diff <- abs(ref_num - cand_num)
            max_err <- max(c(max_err, diff), na.rm = TRUE)
            if (any(diff > tol)) all_ok <- FALSE
        } else if (!identical(
            trimws(tolower(as.character(ref[[col]]))),
            trimws(tolower(as.character(cand_ord[[col]])))
        )) {
            all_ok <- FALSE
        }
    }

    list(
        verdict = if (all_ok) "PASS" else "FAIL",
        max_abs_error = max_err, mean_abs_error = NA
    )
}

# Numeric-scalar comparison when the reference is a bare number; otherwise
# free text is not a good candidate for exact-string comparison and is
# flagged as needing a judge instead (Guo_2026's own design principle: text
# outputs beyond a scalar need semantic, not exact, comparison).
.compare_txt <- function(ref_path, cand_path, tol) {
    if (!file.exists(cand_path))
        return(list(verdict = "UNPARSEABLE", max_abs_error = NA, mean_abs_error = NA))

    ref_content <- trimws(paste(readLines(ref_path, warn = FALSE), collapse = " "))
    ref_num <- suppressWarnings(as.numeric(ref_content))
    if (is.na(ref_num))
        return(list(verdict = "NEEDS_JUDGE", max_abs_error = NA, mean_abs_error = NA))

    cand_content <- trimws(paste(readLines(cand_path, warn = FALSE), collapse = " "))
    cand_num <- suppressWarnings(as.numeric(cand_content))
    if (is.na(cand_num))
        return(list(verdict = "UNPARSEABLE", max_abs_error = NA, mean_abs_error = NA))

    err <- abs(ref_num - cand_num)
    list(
        verdict = if (err <= tol) "PASS" else "FAIL",
        max_abs_error = err, mean_abs_error = err
    )
}

# Dispatches on file extension, returning a closure `function(cand_path)`
# that compares one candidate against the already-parsed reference, or NULL
# if the reference itself can't be parsed by any comparator for this
# extension (mirrors the historical "skip this output file entirely"
# behavior when the reference is unusable).
.dispatch_comparator <- function(ext, ref_path, tol) {
    if (ext %in% c("csv", "tsv")) {
        ref_numeric <- .read_numeric_matrix(ref_path)
        if (!is.null(ref_numeric)) {
            return(function(cand_path) {
                .compare_matrix_output(ref_numeric, .read_numeric_matrix(cand_path), tol)
            })
        }
        ref_table <- .read_generic_table(ref_path)
        if (!is.null(ref_table)) {
            return(function(cand_path) {
                .compare_tables(ref_table, .read_generic_table(cand_path), tol)
            })
        }
        return(NULL)
    }
    if (ext %in% c("fasta", "fa", "fna")) {
        ref_fasta <- .read_fasta(ref_path)
        if (is.null(ref_fasta)) return(NULL)
        return(function(cand_path) .compare_fasta(ref_fasta, .read_fasta(cand_path)))
    }
    if (identical(ext, "txt")) {
        return(function(cand_path) .compare_txt(ref_path, cand_path, tol))
    }
    # Any other extension (png, vcf, bam, sam, ...): no mechanical comparator
    # exists, so flag explicitly rather than silently skip.
    function(cand_path) list(verdict = "NEEDS_JUDGE", max_abs_error = NA, mean_abs_error = NA)
}

.compare_matrix_output <- function(ref, cand, tol) {
    if (is.null(cand))
        return(list(verdict = "UNPARSEABLE", max_abs_error = NA, mean_abs_error = NA, rownames_match = NA))
    if (!identical(dim(cand), dim(ref))) {
        return(list(
            verdict = paste0("DIM_MISMATCH(", paste(dim(cand), collapse = "x"), ")"),
            max_abs_error = NA, mean_abs_error = NA, rownames_match = NA
        ))
    }
    rownames_match <- !is.null(rownames(cand)) && !is.null(rownames(ref)) &&
        setequal(rownames(cand), rownames(ref))
    if (rownames_match) cand <- cand[rownames(ref), , drop = FALSE]

    diff <- abs(cand - ref)
    max_err <- max(diff)
    list(
        verdict = if (max_err <= tol) "PASS" else "FAIL",
        max_abs_error = max_err, mean_abs_error = mean(diff),
        rownames_match = rownames_match
    )
}

.check_output_present <- function(answer_dir, expected_files) {
    length(expected_files) > 0 && all(file.exists(file.path(answer_dir, expected_files)))
}

.check_script_present <- function(scripts) length(scripts) > 0

.mechanical_check <- function(criterion, answer_dir, scripts, expected_files, numeric_status, rowname_status) {
    id <- tolower(criterion$id %||% "")

    if (grepl("leak", id)) return(list(checkable = TRUE, result = .check_reference_leakage(scripts)))
    if (grepl("relative_path|hardcod", id)) return(list(checkable = TRUE, result = .check_relative_paths(scripts)))
    if (grepl("^script_present$", id)) return(list(checkable = TRUE, result = .check_script_present(scripts)))
    if (grepl("^required_output_present$|^output_present$", id))
        return(list(checkable = TRUE, result = .check_output_present(answer_dir, expected_files)))
    if (grepl("parseable|numeric.*matrix|correct_shape|correct_dimension", id)) {
        if (is.null(numeric_status) || identical(numeric_status, "NEEDS_JUDGE"))
            return(list(checkable = FALSE, result = NA))
        return(list(checkable = TRUE, result = !(numeric_status %in% "UNPARSEABLE" | grepl("DIM_MISMATCH", numeric_status))))
    }
    if (grepl("matches_reference_values", id)) {
        if (is.null(numeric_status) || identical(numeric_status, "NEEDS_JUDGE"))
            return(list(checkable = FALSE, result = NA))
        return(list(checkable = TRUE, result = identical(numeric_status, "PASS")))
    }
    if (grepl("row_name|rowname", id)) {
        if (is.null(rowname_status)) return(list(checkable = FALSE, result = NA))
        return(list(checkable = TRUE, result = rowname_status))
    }

    list(checkable = FALSE, result = NA)
}

#' Independently verify one benchmark test's answer submissions
#'
#' Recomputes ground truth for a test's expected output(s) against every
#' model's submission in its `answer/` folder: strict numeric-matrix
#' comparison for csv/tsv where the reference parses fully numeric, a
#' relaxed mixed string/numeric table comparison otherwise, sequence-set
#' comparison for fasta, scalar comparison for txt, and an explicit
#' `NEEDS_JUDGE` verdict (rather than a silent skip) for any other
#' extension with no mechanical comparator (png, vcf, bam, ...). If an
#' `eval_v2.json` rubric is present, mechanically pre-checks whichever
#' rubric criteria don't require an LLM judge (see
#' [mechanical_rubric_criteria()]), reporting which fraction of the rubric's
#' weight is judge-free.
#'
#' This is the same, already-tested logic as the standalone
#' `code/verify_task_judge.R` script, exposed as a package function
#' operating on a single test directory, so it can run immediately after
#' [bench_rubric()]/[bench_task()] rather than only as a separate,
#' after-the-fact script over the whole `tasks/` tree.
#'
#' @param test_dir `character(1)` path to a single benchmark test directory
#'   (e.g. `"tasks/bioc-1-a"`), containing `eval.json`, `ref_answer/`, and
#'   `answer/<model>/` submissions.
#'
#' @return `list` with elements `numeric` (a `data.frame` of per-file,
#'   per-model numeric verdicts) and `rubric` (a named `list` of
#'   per-model `data.frame`s of rubric criterion checks, `NULL` if no
#'   `eval_v2.json` is present). Both are also printed for convenience.
#'
#' @export
bench_verify <- function(test_dir) {
    eval_path <- file.path(test_dir, "eval.json")
    if (!file.exists(eval_path)) stop(test_dir, ": no eval.json found.")

    eval_json <- jsonlite::fromJSON(eval_path, simplifyVector = FALSE)
    answer_dirs <- list.dirs(file.path(test_dir, "answer"), recursive = FALSE)
    if (length(answer_dirs) == 0) stop(test_dir, ": no answer/ submissions yet.")

    numeric_status_by_model <- list()
    rowname_status_by_model <- list()
    numeric_rows <- list()

    for (output_spec in eval_json$scoring$expected_output) {
        fname <- output_spec$file
        ext <- tolower(tools::file_ext(fname))

        ref_path <- file.path(test_dir, "ref_answer", fname)
        if (!file.exists(ref_path)) next
        tol <- .extract_tolerance(output_spec$guidelines %||% "")

        # Dispatches by extension: strict numeric matrix or a relaxed mixed
        # -type table for csv/tsv, sequence-set comparison for fasta, scalar
        # comparison for txt, and an explicit NEEDS_JUDGE flag (instead of a
        # silent skip) for any other extension (png, vcf, bam, ...), which
        # has no mechanical comparator.
        comparator <- .dispatch_comparator(ext, ref_path, tol)
        if (is.null(comparator)) next

        for (dir in answer_dirs) {
            model <- basename(dir)
            cand_path <- file.path(dir, fname)
            if (!file.exists(cand_path)) next

            result <- comparator(cand_path)
            numeric_rows[[length(numeric_rows) + 1]] <- data.frame(
                model = model, file = fname,
                max_abs_error = if (is.null(result$max_abs_error)) NA else result$max_abs_error,
                mean_abs_error = if (is.null(result$mean_abs_error)) NA else result$mean_abs_error,
                verdict = result$verdict
            )
            numeric_status_by_model[[model]] <- result$verdict
            if (!is.null(result$rownames_match))
                rowname_status_by_model[[model]] <- result$rownames_match
        }
    }

    numeric_df <- if (length(numeric_rows) > 0) do.call(rbind, numeric_rows) else NULL
    if (!is.null(numeric_df)) {
        cat("Numeric verification:\n")
        print(numeric_df, row.names = FALSE)
    }

    rubric_result <- NULL
    eval_v2_path <- file.path(test_dir, "eval_v2.json")
    if (file.exists(eval_v2_path)) {
        eval_v2 <- jsonlite::fromJSON(eval_v2_path, simplifyVector = FALSE)
        rubric <- eval_v2$scoring$rubric
        if (!is.null(rubric) && length(rubric) > 0) {
            expected_files <- vapply(eval_v2$scoring$expected_output, function(x) x$file, character(1))
            n_checkable <- 0
            weight_checkable <- 0
            total_weight <- 0
            for (criterion in rubric) {
                w <- criterion$weight %||% 1
                total_weight <- total_weight + w
                d <- .mechanical_check(criterion, answer_dirs[1], .find_script_files(answer_dirs[1]),
                                        expected_files, numeric_status_by_model[[basename(answer_dirs[1])]],
                                        rowname_status_by_model[[basename(answer_dirs[1])]])
                if (d$checkable) { n_checkable <- n_checkable + 1; weight_checkable <- weight_checkable + w }
            }
            cat("\nRubric pre-check (", length(rubric), "criteria):", n_checkable, "of", length(rubric),
                "criteria (", weight_checkable, "of", total_weight, "total weight) need no judge.\n\n")

            rubric_result <- list()
            for (dir in answer_dirs) {
                model <- basename(dir)
                scripts <- .find_script_files(dir)
                rows <- lapply(rubric, function(criterion) {
                    d <- .mechanical_check(criterion, dir, scripts, expected_files,
                                            numeric_status_by_model[[model]], rowname_status_by_model[[model]])
                    data.frame(
                        criterion = criterion$id %||% "?", weight = criterion$weight %||% 1,
                        checkable = d$checkable,
                        result = if (!d$checkable) "NEEDS_JUDGE" else if (is.na(d$result)) "N/A" else if (d$result) "PASS" else "FAIL"
                    )
                })
                model_df <- do.call(rbind, rows)
                rubric_result[[model]] <- model_df
                cat("--", model, "--\n")
                print(model_df, row.names = FALSE)
                cat("\n")
            }
        }
    }

    invisible(list(numeric = numeric_df, rubric = rubric_result))
}

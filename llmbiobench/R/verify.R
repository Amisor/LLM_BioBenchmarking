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
    storage.mode(m) <- "double"
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
        if (is.null(numeric_status)) return(list(checkable = FALSE, result = NA))
        return(list(checkable = TRUE, result = !(numeric_status %in% "UNPARSEABLE" | grepl("DIM_MISMATCH", numeric_status))))
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

#' Independently verify one benchmark test's answer submissions
#'
#' Recomputes numeric ground truth for a test's tabular expected output(s)
#' against every model's submission in its `answer/` folder, and, if an
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
        if (!(ext %in% c("csv", "tsv"))) next

        ref_path <- file.path(test_dir, "ref_answer", fname)
        if (!file.exists(ref_path)) next
        ref <- .read_numeric_matrix(ref_path)
        if (is.null(ref)) next
        tol <- .extract_tolerance(output_spec$guidelines %||% "")

        for (dir in answer_dirs) {
            model <- basename(dir)
            cand_path <- file.path(dir, fname)
            if (!file.exists(cand_path)) next
            cand <- .read_numeric_matrix(cand_path)
            if (is.null(cand)) {
                numeric_rows[[length(numeric_rows) + 1]] <- data.frame(
                    model = model, file = fname, max_abs_error = NA,
                    mean_abs_error = NA, verdict = "UNPARSEABLE"
                )
                numeric_status_by_model[[model]] <- "UNPARSEABLE"
                next
            }
            if (!identical(dim(cand), dim(ref))) {
                verdict <- paste0("DIM_MISMATCH(", paste(dim(cand), collapse = "x"), ")")
                numeric_rows[[length(numeric_rows) + 1]] <- data.frame(
                    model = model, file = fname, max_abs_error = NA,
                    mean_abs_error = NA, verdict = verdict
                )
                numeric_status_by_model[[model]] <- verdict
                next
            }
            rownames_match <- !is.null(rownames(cand)) && !is.null(rownames(ref)) &&
                setequal(rownames(cand), rownames(ref))
            rowname_status_by_model[[model]] <- rownames_match
            if (rownames_match) cand <- cand[rownames(ref), , drop = FALSE]

            diff <- abs(cand - ref)
            max_err <- max(diff)
            verdict <- if (max_err <= tol) "PASS" else "FAIL"
            numeric_rows[[length(numeric_rows) + 1]] <- data.frame(
                model = model, file = fname, max_abs_error = max_err,
                mean_abs_error = mean(diff), verdict = verdict
            )
            numeric_status_by_model[[model]] <- verdict
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

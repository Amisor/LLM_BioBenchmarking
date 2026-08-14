#' Build the standard mechanically-checkable rubric criteria
#'
#' Generates the rubric criteria that are checkable by plain file/text
#' inspection, no LLM judge required, for any task whose expected output is
#' a numeric table compared against a reference file: is the output present,
#' does it parse to a numeric matrix, does it match the reference within
#' tolerance, does the submitted script avoid reading the answer key, does
#' it avoid hardcoded absolute paths, and (optionally) do the output's row
#' names match the reference's. These use the exact criterion `id`s that
#' [bench_verify()] (and the standalone `code/verify_task_judge.R` script)
#' dispatch on mechanically; keep custom criteria's `id`s distinct from
#' these to avoid an accidental mechanical match.
#'
#' @param has_row_names `logical(1)` whether the task's expected output has
#'   meaningful row names that should be checked against the reference.
#'   Defaults to `FALSE`.
#'
#' @return `list` of rubric criterion objects (`id`, `criterion`, `weight`,
#'   `score_type`, `evidence`).
#'
#' @export
mechanical_rubric_criteria <- function(has_row_names = FALSE) {
    criteria <- list(
        list(
            id = "required_output_present",
            criterion = "The answer folder contains the required expected output file.",
            weight = 1,
            score_type = "binary",
            evidence = "Inspect the answer folder."
        ),
        list(
            id = "output_is_parseable",
            criterion = "The output file is parseable as a numeric table of the expected shape.",
            weight = 2,
            score_type = "binary",
            evidence = "Read the submitted output file."
        ),
        list(
            id = "output_matches_reference_values",
            criterion = "The numeric values match the reference output within the stated tolerance.",
            weight = 5,
            score_type = "binary",
            evidence = "Compare the submitted output against the reference output."
        ),
        list(
            id = "script_present",
            criterion = "The answer folder contains a submitted script that can be inspected to understand how the output was generated.",
            weight = 1,
            score_type = "binary",
            evidence = "Inspect the answer folder."
        ),
        list(
            id = "uses_relative_paths",
            criterion = "The submitted script uses repository-relative or task-relative paths and does not hardcode user-specific absolute paths.",
            weight = 2,
            score_type = "binary",
            evidence = "Inspect the submitted script."
        ),
        list(
            id = "avoids_reference_leakage",
            criterion = "The submitted script does not read eval.json, eval_v2.json, ref_answer, or ref_script.",
            weight = 5,
            score_type = "binary",
            evidence = "Inspect the submitted script."
        )
    )

    if (has_row_names) {
        criteria[[length(criteria) + 1]] <- list(
            id = "row_names_follow_required_format",
            criterion = "The output's row names match the reference output's row names.",
            weight = 2,
            score_type = "binary",
            evidence = "Compare the submitted output's row names against the reference output's."
        )
    }

    criteria
}

#' Create an `eval_v2.json` rubric-scored eval file for a benchmark test
#'
#' Extends [bench_eval()]'s simple `eval.json` with a weighted rubric: the
#' mechanically-checkable criteria from [mechanical_rubric_criteria()] (no
#' judge needed for those, see [bench_verify()]) plus any task-specific
#' criteria supplied by the caller, which genuinely require an LLM judge to
#' read and evaluate the submitted code (e.g. "uses the correct statistical
#' method", "avoids unnecessary steps").
#'
#' @param test_id `character(1)` identifier for the test. The corresponding
#'   test directory (created by [bench_folders()]) must already exist, and
#'   should contain populated `ref_answer` and `ref_script` subfolders.
#' @param output_dir `character(1)` path to the parent directory containing
#'   the test folder. Defaults to the current working directory.
#' @param evalfile `character(1)` name of the JSON file to write within the
#'   test directory. Defaults to `"eval_v2.json"`.
#' @param question `character(1)` optional task description. If `NULL`
#'   (the default), the user is prompted interactively.
#' @param guidelines `character(1)` optional scoring guidelines applied to
#'   each expected output file that the user names interactively. If `NULL`
#'   (the default), the user is prompted for guidelines separately for each
#'   output file.
#' @param has_row_names `logical(1)` passed to [mechanical_rubric_criteria()].
#' @param custom_criteria `list` of additional, task-specific rubric
#'   criterion objects (each with `id`, `criterion`, `weight`, `score_type`,
#'   `evidence`) that require an LLM judge to evaluate, e.g. whether the
#'   submitted script used the correct statistical method. Defaults to
#'   `list()` (no task-specific criteria beyond the mechanical ones).
#'
#' @return `list` the eval object that was written to `evalfile`, returned
#'   invisibly.
#'
#' @examples
#' \dontrun{
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' bench_rubric(
#'     "bioc-1-a",
#'     output_dir = tempdir(),
#'     question = "Compute the mean of each column.",
#'     guidelines = "Values must match the reference within 1e-3.",
#'     custom_criteria = list(list(
#'         id = "uses_correct_input_file",
#'         criterion = "The submitted script reads the provided input file.",
#'         weight = 3, score_type = "binary",
#'         evidence = "Inspect the submitted script."
#'     ))
#' )
#' }
#'
#' @export
bench_rubric <- function(
    test_id, output_dir = getwd(), evalfile = "eval_v2.json",
    question = NULL, guidelines = NULL, has_row_names = FALSE,
    custom_criteria = list()
) {
    base_eval <- bench_eval(
        test_id, output_dir = output_dir, evalfile = "__bench_rubric_tmp.json",
        question = question, guidelines = guidelines
    )
    # bench_eval() already wrote a throwaway file for its own bookkeeping;
    # remove it, this function writes the real rubric-bearing eval file.
    tmp_path <- file.path(output_dir, test_id, "__bench_rubric_tmp.json")
    if (file.exists(tmp_path)) file.remove(tmp_path)

    rubric <- c(mechanical_rubric_criteria(has_row_names = has_row_names), custom_criteria)

    eval_v2 <- base_eval
    eval_v2$scoring$rubric_scoring <- list(
        score_type = "weighted_binary",
        criterion_grade = "pass_fail",
        criterion_score = "pass earns the criterion weight; fail earns 0",
        overall_score = "sum of criterion scores divided by sum of criterion weights"
    )
    eval_v2$scoring$rubric <- rubric

    test_dir <- file.path(output_dir, test_id)
    jsonlite::write_json(
        eval_v2,
        path = file.path(test_dir, evalfile),
        auto_unbox = TRUE,
        pretty = TRUE
    )

    invisible(eval_v2)
}

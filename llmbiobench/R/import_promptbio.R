#' @importFrom jsonlite fromJSON write_json
NULL

.copy_subfolder_contents <- function(src_task_dir, dest_task_dir, subfolder) {
    src <- file.path(src_task_dir, subfolder)
    if (!dir.exists(src)) return(invisible(character(0)))
    dest <- file.path(dest_task_dir, subfolder)
    files <- list.files(src, full.names = TRUE)
    if (length(files) == 0) return(invisible(character(0)))
    file.copy(files, dest, overwrite = TRUE, recursive = TRUE)
}

#' Import a PromptBio-Bench task into the local `tasks/` benchmark tree
#'
#' Materializes a task already fetched from Hugging Face (via
#' `code/read_promptbio_huggingface.R`'s `download_promptbio_task_files()`)
#' into the standard [bench_folders()] layout under `output_dir`, so it can
#' be run through [bench_llm()]/[bench_verify()] like any hand-authored
#' task. PromptBio-Bench's `task.json`/`eval.json` field names already match
#' [bench_task()]/[bench_eval()]'s schema exactly (`id`, `question`,
#' `input_files`, `expected_output`, `timeout_seconds` for `task.json`;
#' `id`, `question`, `ref_answer`, `ref_script`, `scoring.expected_output`
#' for `eval.json`), so this is a straight materializer, folder creation
#' plus file copy, not a schema translation.
#'
#' @param task_id `character(1)` PromptBio-Bench task identifier, e.g.
#'   `"a-1-1"`.
#' @param source_dir `character(1)` path to the local PromptBio-Bench
#'   mirror (as populated by `download_promptbio_task_files()` in
#'   `code/read_promptbio_huggingface.R`), containing
#'   `<source_dir>/<task_id>/{task.json,eval.json,data/,ref_answer/,ref_script/}`.
#'   Defaults to `"data/promptbio-bench/tasks"`.
#' @param output_dir `character(1)` path to the parent directory in which
#'   the task folder should be created, matching [bench_folders()]'s
#'   `output_dir`. Defaults to `"tasks"`.
#' @param prompt_version `character(1)` which prompt template set to copy
#'   in via [add_prompts()], either `""` or `"_v2"`. Defaults to `"_v2"`.
#'
#' @return `character(1)` the `task_id`, invisibly returned.
#'
#' @examples
#' \dontrun{
#' import_promptbio_task("a-1-1")
#' }
#'
#' @export
import_promptbio_task <- function(
    task_id, source_dir = "data/promptbio-bench/tasks",
    output_dir = "tasks", prompt_version = "_v2"
) {
    src_task_dir <- file.path(source_dir, task_id)
    task_path <- file.path(src_task_dir, "task.json")
    eval_path <- file.path(src_task_dir, "eval.json")
    if (!file.exists(task_path) || !file.exists(eval_path))
        stop(
            "'", task_path, "' and/or '", eval_path, "' not found. ",
            "Run download_promptbio_task_files('", task_id, "') first ",
            "(see code/read_promptbio_huggingface.R)."
        )

    bench_folders(task_id, output_dir = output_dir)
    dest_task_dir <- file.path(output_dir, task_id)

    .copy_subfolder_contents(src_task_dir, dest_task_dir, "data")
    .copy_subfolder_contents(src_task_dir, dest_task_dir, "ref_answer")
    .copy_subfolder_contents(src_task_dir, dest_task_dir, "ref_script")

    task_json <- jsonlite::fromJSON(task_path, simplifyVector = FALSE)
    eval_json <- jsonlite::fromJSON(eval_path, simplifyVector = FALSE)
    jsonlite::write_json(
        task_json, path = file.path(dest_task_dir, "task.json"),
        auto_unbox = TRUE, pretty = TRUE
    )
    jsonlite::write_json(
        eval_json, path = file.path(dest_task_dir, "eval.json"),
        auto_unbox = TRUE, pretty = TRUE
    )

    add_prompts(task_id, output_dir = output_dir, version = prompt_version)

    invisible(task_id)
}

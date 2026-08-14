#' Create benchmark test folder structure
#'
#' Creates a subdirectory for a given `test_id` under `output_dir`, along with
#' the standard set of subfolders used to organize a single benchmarking
#' test: `data`, `prompt`, `ref_answer`, `ref_script`, and `answer`.
#'
#' @param test_id `character(1)` identifier for the test. Must not contain
#'   whitespace.
#' @param output_dir `character(1)` path to the parent directory in which the
#'   test folder should be created. Defaults to the current working
#'   directory.
#'
#' @return `character(1)` the `test_id`, invisibly returned for convenience.
#'
#' @examples
#' \dontrun{
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' }
#'
#' @export
bench_folders <- function(test_id, output_dir = getwd()) {
    # Create the main output directory if it doesn't exist
    if (!dir.exists(output_dir))
        dir.create(output_dir, recursive = TRUE)
    
    # Check there are no spaces in the test_id
    if (grepl("\\s", test_id))
        stop("test_id should not contain spaces.")

    # Create a subdirectory for the specific test_id
    test_dir <- file.path(output_dir, test_id)
    if (!dir.exists(test_dir))
        dir.create(test_dir)
    
    folders <-
        c("data", "prompt", "ref_answer", "ref_script", "data", "answer")

    # Create the subdirectories for each folder
    for (folder in folders) {
        folder_path <- file.path(test_dir, folder)
        if (!dir.exists(folder_path))
            dir.create(folder_path)
    }

    return(test_id)
}

#' Create a `task.json` file for a benchmark test
#'
#' Builds and writes a `task.json` file describing a benchmark task,
#' including the task question, the list of input data files, and a
#' description of the expected output. Prompts the user interactively for
#' the question, the expected output file name, and the output description
#' unless supplied directly.
#'
#' @param test_id `character(1)` identifier for the test. The corresponding
#'   test directory (created by [bench_folders()]) must already exist.
#' @param output_dir `character(1)` path to the parent directory containing
#'   the test folder. Defaults to the current working directory.
#' @param taskfile `character(1)` name of the JSON file to write within the
#'   test directory. Defaults to `"task.json"`.
#' @param timeout `numeric(1)` timeout, in seconds, to record for the task.
#'   Defaults to `3600`.
#' @param question `character(1)` optional task description. If `NULL`
#'   (the default), the user is prompted interactively.
#' @param output_file `character(1)` optional name of the expected output
#'   file (e.g. `"sample_dist_matrix.csv"`). If `NULL` (the default), the
#'   user is prompted interactively. Its extension is recorded as the
#'   output `type`.
#' @param output_description `character(1)` optional description of the
#'   expected task output. If `NULL` (the default), the user is prompted
#'   interactively.
#'
#' @return `list` the task object that was written to `taskfile`, returned
#'   invisibly.
#'
#' @examples
#' \dontrun{
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' bench_task(
#'     "bioc-1-a",
#'     output_dir = tempdir(),
#'     question = "Compute the mean of each column.",
#'     output_file = "column_means.csv",
#'     output_description = "A CSV file with one row per column mean."
#' )
#' }
#'
#' @export
bench_task <- function(
    test_id, output_dir = getwd(), taskfile = "task.json", timeout = 3600,
    question = NULL, output_file = NULL, output_description = NULL
) {
    test_dir <- file.path(output_dir, test_id)
    if (!dir.exists(test_dir))
        stop("Test directory does not exist. Run bench_folders() first.")

    quest <- if (is.null(question)) {
        readline(
            prompt = paste(
                "Provide the task description for the task",
                "you want to benchmark:"
            )
        )
    } else {
        question
    }
    datafiles <- list.files(
        path = file.path(output_dir, test_id, "data")
    )
    out_file <- if (is.null(output_file)) {
        readline(
            prompt = "Provide the name of the expected output file: "
        )
    } else {
        output_file
    }
    desc <- if (is.null(output_description)) {
        readline(
            prompt = paste(
                "Provide a description of the expected task output: "
            )
        )
    } else {
        output_description
    }
    task <- list(
        id = test_id,
        question = quest,
        input_files = datafiles,
        expected_output = list(
            list(
                file = out_file,
                type = tools::file_ext(out_file),
                description = desc
            )
        ),
        timeout_seconds = timeout
    )

    jsonlite::write_json(
        task,
        path = file.path(test_dir, taskfile),
        auto_unbox = TRUE,
        pretty = TRUE
    )
    return(task)
}

#' Create an `eval.json` file for a benchmark test
#'
#' Builds and writes an `eval.json` file describing how a benchmark task
#' should be scored, including the task question, the reference answer and
#' script files, and per-file scoring guidelines for each expected output
#' file. Prompts the user interactively for the question, output file names,
#' and scoring guidelines unless supplied directly.
#'
#' @param test_id `character(1)` identifier for the test. The corresponding
#'   test directory (created by [bench_folders()]) must already exist, and
#'   should contain populated `ref_answer` and `ref_script` subfolders.
#' @param output_dir `character(1)` path to the parent directory containing
#'   the test folder. Defaults to the current working directory.
#' @param evalfile `character(1)` name of the JSON file to write within the
#'   test directory. Defaults to `"eval.json"`.
#' @param question `character(1)` optional task description. If `NULL`
#'   (the default), the user is prompted interactively.
#' @param guidelines `character(1)` optional scoring guidelines applied to
#'   each expected output file that the user names interactively. If `NULL`
#'   (the default), the user is prompted for guidelines separately for each
#'   output file.
#'
#' @return `list` the eval object that was written to `evalfile`, returned
#'   invisibly.
#'
#' @examples
#' \dontrun{
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' bench_eval(
#'     "bioc-1-a",
#'     output_dir = tempdir(),
#'     question = "Compute the mean of each column.",
#'     guidelines = "Values must match the reference within 1e-3."
#' )
#' }
#'
#' @export
bench_eval <- function(
    test_id, output_dir = getwd(), evalfile = "eval.json",
    question = NULL, guidelines = NULL
) {
    test_dir <- file.path(output_dir, test_id)
    if (!dir.exists(test_dir))
        stop("Test directory does not exist. Run bench_folders() first.")

    quest <- if (is.null(question)) {
        readline(
            prompt = paste(
                "Provide the task description for the task",
                "you want to benchmark:"
            )
        )
    } else {
        question
    }

    ref_answer_files <- list.files(path = file.path(test_dir, "ref_answer"))
    if (length(ref_answer_files) == 0)
        warning("No files found in 'ref_answer' folder.")

    ref_script_files <- list.files(path = file.path(test_dir, "ref_script"))
    if (length(ref_script_files) == 0)
        warning("No files found in 'ref_script' folder.")

    expected_output <- list()
    repeat {
        file_name <- readline(
            prompt = paste(
                "Provide the name of an expected output file",
                "(leave blank to stop adding files): "
            )
        )
        if (file_name == "")
            break

        file_guidelines <- if (is.null(guidelines)) {
            readline(
                prompt = paste(
                    "Provide scoring guidelines for", file_name, ": "
                )
            )
        } else {
            guidelines
        }

        expected_output[[length(expected_output) + 1]] <- list(
            file = file_name,
            guidelines = file_guidelines
        )
    }

    eval <- list(
        id = test_id,
        question = quest,
        ref_answer = as.list(file.path("ref_answer", ref_answer_files)),
        ref_script = as.list(file.path("ref_script", ref_script_files)),
        scoring = list(
            expected_output = expected_output
        )
    )

    jsonlite::write_json(
        eval,
        path = file.path(test_dir, evalfile),
        auto_unbox = TRUE,
        pretty = TRUE
    )

    return(eval)
}

#' Set up a complete single benchmark test
#'
#' Convenience wrapper that runs the full setup for a single benchmarking
#' test: creates the folder structure with [bench_folders()], then prompts
#' the user once for the task question and expected output description, and
#' reuses those same responses to write both `task.json` (via [bench_task()])
#' and `eval.json` (via [bench_eval()]).
#'
#' @param test_id `character(1)` identifier for the test. Must not contain
#'   whitespace.
#' @param output_dir `character(1)` path to the parent directory in which the
#'   test folder should be created. Defaults to the current working
#'   directory.
#' @param taskfile `character(1)` name of the task JSON file to write.
#'   Defaults to `"task.json"`.
#' @param evalfile `character(1)` name of the eval JSON file to write.
#'   Defaults to `"eval.json"`.
#' @param timeout `numeric(1)` timeout, in seconds, to record for the task.
#'   Defaults to `3600`.
#'
#' @return `list` with elements `task` and `eval`, the objects written to
#'   `taskfile` and `evalfile` respectively.
#'
#' @examples
#' \dontrun{
#' bench_setup("bioc-1-a", output_dir = tempdir())
#' }
#'
#' @export
bench_setup <- function(
    test_id, output_dir = getwd(), taskfile = "task.json",
    evalfile = "eval.json", timeout = 3600
) {
    bench_folders(test_id, output_dir = output_dir)

    quest <- readline(
        prompt = paste(
            "Provide the task description for the task",
            "you want to benchmark:"
        )
    )
    out_file <- readline(
        prompt = "Provide the name of the expected output file: "
    )
    desc <- readline(
        prompt = paste(
            "Provide a description of the expected task output: "
        )
    )

    task <- bench_task(
        test_id,
        output_dir = output_dir,
        taskfile = taskfile,
        timeout = timeout,
        question = quest,
        output_file = out_file,
        output_description = desc
    )

    eval <- bench_eval(
        test_id,
        output_dir = output_dir,
        evalfile = evalfile,
        question = quest,
        guidelines = desc
    )

    list(task = task, eval = eval)
}

#' Add a data object to a benchmark test's data folder
#'
#' Writes an R object (e.g. a reference dataset, or a reference answer) to
#' the `data` subfolder of a benchmark test, as either a CSV or an RDS file.
#'
#' @param data_object the R object to write. Its name (via
#'   [deparse(substitute())][substitute]) is used to name the output file,
#'   unless `file_name` is supplied.
#' @param test_id `character(1)` identifier for the test. The corresponding
#'   test directory (created by [bench_folders()]) must already exist.
#' @param type `character(1)` output format, either `"csv"` or `"rds"`.
#'   Defaults to `"csv"`.
#' @param output_dir `character(1)` path to the parent directory containing
#'   the test folder. Defaults to the current working directory.
#' @param file_name `character(1)` optional file name (without extension)
#'   to use instead of `data_object`'s deparsed name. Useful when
#'   `data_object` is not a simple variable (e.g. the result of a pipeline).
#'
#' @return `character(1)` the path the data file was written to, invisibly.
#'
#' @examples
#' \dontrun{
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' add_data(mtcars, "bioc-1-a", type = "csv", output_dir = tempdir())
#' }
#'
#' @export
add_data <- function(
    data_object, test_id, type = c("csv", "rds"), output_dir = getwd(),
    file_name = NULL
) {
    data_object_name <- if (is.null(file_name)) {
        deparse(substitute(data_object))
    } else {
        file_name
    }
    type <- match.arg(type)
    data_dir <- file.path(output_dir, test_id, "data")
    if (!dir.exists(data_dir))
        stop("'data' directory does not exist. Run bench_folders() first.")

    dest_path <- file.path(data_dir, paste0(data_object_name, ".", type))

    writer <- switch(
        type,
        csv = function(data, path) write.csv(data, path, row.names = TRUE),
        rds = function(data, path) saveRDS(data, path)
    )
    writer(data_object, dest_path)
    invisible(dest_path)
}
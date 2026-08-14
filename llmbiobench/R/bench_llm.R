#' @importFrom jsonlite fromJSON
NULL

# Supported ellmer chat constructors, keyed by provider name. Each entry is
# the name of an `ellmer::chat_*()` function that accepts at least `model`
# as an argument. Extend this list as ellmer adds/renames providers.
.ellmer_providers <- c(
    openai = "chat_openai",
    anthropic = "chat_anthropic",
    google = "chat_google_gemini",
    openrouter = "chat_openrouter",
    azure = "chat_azure_openai",
    bedrock = "chat_aws_bedrock",
    ollama = "chat_ollama",
    databricks = "chat_databricks",
    groq = "chat_groq",
    perplexity = "chat_perplexity",
    deepseek = "chat_deepseek"
)

.require_ellmer <- function() {
    if (!requireNamespace("ellmer", quietly = TRUE))
        stop(
            "The 'ellmer' package is required to run bench_llm(). ",
            "Install it with install.packages('ellmer')."
        )
}

# normalizePath(x, mustWork = FALSE) does NOT reliably collapse ".."
# components when part of the path doesn't exist on disk (confirmed
# directly: it returns the ".." segments untouched rather than resolving
# them) -- so it cannot be used to defend against a "../../etc/passwd"-style
# escape for a path that doesn't yet exist (the common case for write_file,
# and for read_file against a nonexistent traversal target). This collapses
# "." and ".." purely as string manipulation, with no filesystem access, so
# it's reliable regardless of whether the target exists. Assumes `path` is
# already absolute (the sandboxing tools below always build it from an
# already-normalizePath()'d, existing test_dir).
.lexical_normalize <- function(path) {
    parts <- strsplit(path, "/", fixed = TRUE)[[1]]
    stack <- character(0)
    for (part in parts) {
        if (identical(part, "") || identical(part, ".")) next
        if (identical(part, "..")) {
            if (length(stack) > 0) stack <- stack[-length(stack)]
            next
        }
        stack <- c(stack, part)
    }
    paste0("/", paste(stack, collapse = "/"))
}

#' Build a restricted file-access toolset scoped to one test directory
#'
#' Constructs [ellmer::tool()] definitions for reading, writing, and listing
#' files, each of which resolves paths relative to `test_dir` and refuses to
#' operate outside of it. This lets a model read `task.json`/`data/` and
#' write its response under `answer/<model_name>` without being able to
#' touch the rest of the filesystem (in particular, `ref_answer/`,
#' `ref_script/`, and `eval*.json`, which would leak the reference answer).
#'
#' @param test_dir `character(1)` path to a single benchmark test directory.
#' @param allow_write_prefix `character(1)` a path prefix (relative to
#'   `test_dir`) that write/list operations are restricted to, in addition
#'   to read access across the whole test directory. Defaults to `"answer"`.
#'
#' @return `list` of `ellmer::tool()` objects: `read_file`, `write_file`,
#'   `list_files`.
#'
#' @keywords internal
#' @export
bench_llm_tools <- function(test_dir, allow_write_prefix = "answer") {
    .require_ellmer()

    test_dir <- normalizePath(test_dir, mustWork = TRUE)

    .resolve <- function(path) {
        full <- .lexical_normalize(file.path(test_dir, path))
        if (!startsWith(full, test_dir))
            stop("Path '", path, "' escapes the test directory; refusing.")
        full
    }

    .blocked <- function(path) {
        grepl(
            "(^|/)(ref_answer|ref_script|eval\\.json|eval_v2\\.json)(/|$)",
            path
        )
    }

    read_file <- function(path) {
        if (.blocked(path))
            stop("Reading '", path, "' is not permitted (reference leakage).")
        full <- .resolve(path)
        if (!file.exists(full)) stop("File does not exist: ", path)
        paste(readLines(full, warn = FALSE), collapse = "\n")
    }

    write_file <- function(path, content) {
        if (!startsWith(path, allow_write_prefix))
            stop(
                "Writes are only permitted under '", allow_write_prefix,
                "/'; got '", path, "'."
            )
        full <- .resolve(path)
        dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
        writeLines(content, full)
        paste("Wrote", nchar(content), "characters to", path)
    }

    list_files <- function(path = ".") {
        full <- .resolve(path)
        files <- list.files(full, recursive = TRUE)
        paste(files, collapse = "\n")
    }

    list(
        read_file = ellmer::tool(
            read_file,
            "Read the full contents of a text file, given a path relative to the test directory.",
            arguments = list(
                path = ellmer::type_string("Path relative to the test directory, e.g. 'task.json' or 'data/gse.rds'.")
            )
        ),
        write_file = ellmer::tool(
            write_file,
            paste(
                "Write text content to a file, given a path relative to the",
                "test directory. Only paths under '", allow_write_prefix,
                "/' may be written."
            ),
            arguments = list(
                path = ellmer::type_string("Destination path relative to the test directory, e.g. 'answer/gpt-4o/result.csv'."),
                content = ellmer::type_string("The full text content to write to the file.")
            )
        ),
        list_files = ellmer::tool(
            list_files,
            "List files under a directory, given a path relative to the test directory.",
            arguments = list(
                path = ellmer::type_string("Directory path relative to the test directory. Defaults to the test directory root.")
            )
        )
    )
}

#' Run a single LLM against one benchmark test via ellmer
#'
#' Backbone function for driving one benchmarking call at a time to an LLM
#' provider supported by [ellmer](https://ellmer.tidyverse.org/), while
#' allowing the caller to choose from several providers/models across
#' invocations. Loads the test's prompt template (as copied by
#' [add_prompts()]), substitutes in the test id, equips the model with a
#' restricted file toolset scoped to the test directory (see
#' [bench_llm_tools()]) so it can read `task.json`/`data/` and write its
#' answer under `answer/<model_name>`, and runs the chat to completion.
#'
#' Only one provider/model pair is run per call; to benchmark several
#' providers or models, call this function once per combination (e.g. in a
#' loop over a small data frame of `provider`/`model` pairs).
#'
#' @param test_id `character(1)` identifier for the test. The corresponding
#'   test directory (created by [bench_folders()]) must already exist and
#'   contain a `task.json` (from [bench_task()]) and, if `prompt_version` is
#'   used, a copied prompt file (from [add_prompts()]).
#' @param provider `character(1)` which ellmer chat backend to use. One of
#'   `r paste(sQuote(names(.ellmer_providers)), collapse = ", ")`, matching
#'   the constructor names in ellmer's `chat_*()` family.
#' @param model `character(1)` the model name to pass to the chosen
#'   provider's `chat_*()` constructor (e.g. `"gpt-4o"`,
#'   `"claude-opus-4-5"`, `"gemini-2.5-pro"`).
#' @param output_dir `character(1)` path to the parent directory containing
#'   the test folder. Defaults to the current working directory.
#' @param prompt_version `character(1)` which prompt template to send,
#'   matching [add_prompts()]'s `version`: `""` for the original prompt or
#'   `"_v2"` for the second version. Defaults to `""`.
#' @param prompt_file `character(1)` optional explicit prompt file name
#'   (relative to the test's `prompt/` folder) to use instead of deriving
#'   one from `prompt_version`. Defaults to `NULL`.
#' @param system_prompt `character(1)` optional system prompt passed to the
#'   chat constructor's `system_prompt` argument. Defaults to `NULL`.
#' @param tools `list` of `ellmer::tool()` objects to register with the
#'   chat. Defaults to `NULL`, which uses [bench_llm_tools()] scoped to the
#'   test directory.
#' @param echo `character(1)` passed through to the ellmer chat
#'   constructor's `echo` argument, controlling whether the conversation is
#'   streamed to the console. Defaults to `"none"`.
#' @param max_turns `numeric(1)` maximum number of assistant/tool turns to
#'   allow before stopping, passed to `chat$set_turns()`-style limits if
#'   supported by the installed ellmer version; otherwise advisory only.
#'   Defaults to `20`.
#' @param ... additional named arguments forwarded to the provider's
#'   `chat_*()` constructor (e.g. `api_args`, `base_url`, `api_key`).
#'
#' @return `list` with elements `model_name` (the identifier used for the
#'   `answer/<model_name>` folder), `response` (the final assistant text),
#'   and `chat` (the `ellmer::Chat` object, for inspecting the full
#'   transcript with e.g. `chat$get_turns()`). Returned invisibly.
#'
#' @examples
#' \dontrun{
#' bench_folders(test_id = "bioc-2-a", output_dir = "inst/benchmarks/")
#' bench_task(
#'     test_id = "bioc-2-a",
#'     output_dir = "inst/benchmarks/",
#'     question = "Using the provided RNA-seq gene-level SummarizedExperiment dataset (gse.rds), construct a DESeqDataSet object with design formula '~ cell + dex' (renaming donor to cell, condition to dex, setting levels 'untrt' and 'trt' with 'untrt' as reference). Pre-filter to retain genes with counts >= 10 in at least 4 samples, apply variance stabilizing transformation (vst) with blind=FALSE, and compute the Euclidean sample-to-sample distance matrix. Save the distance matrix with row names formatted as '<dex> - <cell>' and column names set to NULL.",
#'     output_file = "sample_dist_matrix.csv",
#'     output_description = "Euclidean sample distance matrix (8x8) computed from VST-transformed counts with rownames formatted as '<dex> - <cell>' (e.g. 'untrt - N61311') and without column names."
#' )
#' add_prompts("bioc-2-a", version = "_v2", output_dir = "inst/benchmarks/")
#' ## run script to generate gse.rds
#' ## source("inst/scripts/bioc-2-a.R")
#' add_data(gse, "bioc-2-a", type = "rds", output_dir = "inst/benchmarks/")
#' ## copy ref_script into the test folder for reference
#' ## file.copy(
#' ##     "inst/scripts/sample_dist_matrix.R",
#' ##     "inst/benchmarks/bioc-2-a/ref_script/sample_dist_matrix.R"
#' ## )
#' ## ## add reference answer for comparison
#' ## file.copy(
#' ##     "inst/scripts/sample_dist_matrix.csv",
#' ##     "inst/benchmarks/bioc-2-a/ref_answer/sample_dist_matrix.csv"
#' ## )
#'
#' bench_llm(
#'     "bioc-2-a",
#'     provider = "openrouter",
#'     model = "google/gemini-3-flash-preview",
#'     output_dir = "inst/benchmarks/"
#' )
#' }
#'
#' @export
bench_llm <- function(
    test_id, provider = names(.ellmer_providers), model, output_dir = getwd(),
    prompt_version = c("", "_v2"), prompt_file = NULL, system_prompt = NULL,
    tools = NULL, echo = "none", max_turns = 20, ...
) {
    .require_ellmer()

    provider <- match.arg(provider)
    prompt_version <- match.arg(prompt_version)

    if (missing(model) || is.null(model) || !nzchar(model))
        stop("'model' must be supplied (e.g. 'gpt-4o', 'claude-opus-4-5').")

    test_dir <- file.path(output_dir, test_id)
    if (!dir.exists(test_dir))
        stop("Test directory does not exist. Run bench_folders() first.")

    task_path <- file.path(test_dir, "task.json")
    if (!file.exists(task_path))
        warning("No task.json found in '", test_dir, "'; run bench_task() first.")

    if (is.null(prompt_file)) {
        prompt_file <- if (prompt_version == "") "evalprompt.txt" else "evalprompt_v2.txt"
    }
    prompt_path <- file.path(test_dir, "prompt", prompt_file)
    if (!file.exists(prompt_path))
        stop(
            "Prompt file '", prompt_file, "' not found under '", test_dir,
            "/prompt'. Run add_prompts() first."
        )

    prompt_text <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
    # The bundled prompt templates use "bioc-1-a" as the example test id;
    # substitute in the actual test id being run.
    prompt_text <- gsub("bioc-1-a", test_id, prompt_text, fixed = TRUE)

    constructor_name <- .ellmer_providers[[provider]]
    if (!exists(constructor_name, where = asNamespace("ellmer"), inherits = FALSE))
        stop(
            "ellmer does not provide a '", constructor_name, "()' constructor ",
            "in the installed version; check ellmer::", constructor_name, "()."
        )
    constructor <- getExportedValue("ellmer", constructor_name)

    chat_args <- list(model = model, echo = echo, ...)
    if (!is.null(system_prompt)) chat_args$system_prompt <- system_prompt
    chat <- do.call(constructor, chat_args)

    if (is.null(tools)) tools <- bench_llm_tools(test_dir)
    for (tool_name in names(tools)) chat$register_tool(tools[[tool_name]])

    response <- tryCatch(
        chat$chat(prompt_text),
        error = function(e) stop("bench_llm() chat failed: ", conditionMessage(e))
    )

    invisible(list(model_name = model, response = response, chat = chat))
}

#' Build a judge-scoped toolset for grading one candidate's submission
#'
#' The inverse of [bench_llm_tools()]: an answering model must not see the
#' reference materials, but a judge model must. Grants read access to the
#' whole test directory (`task.json`, `data/`, `ref_answer/`, `ref_script/`,
#' `eval.json`, `eval_v2.json`) plus the one candidate's own
#' `answer/<candidate_model>/` submission, but hides every *other* model's
#' `answer/` subfolder (from both `read_file` and `list_files`) so grading
#' one candidate can't be contaminated by seeing another candidate's
#' answer. Write access is restricted to a single file,
#' `answer/<candidate_model>/<judge_output_file>`, so the judge cannot
#' modify the candidate's submitted output itself.
#'
#' @param test_dir `character(1)` path to a single benchmark test directory.
#' @param candidate_model `character(1)` name of the `answer/` subfolder
#'   being graded.
#' @param judge_output_file `character(1)` file name (within
#'   `answer/<candidate_model>/`) the judge is permitted to write its
#'   verdict to. Defaults to `"judge_result.json"`.
#'
#' @return `list` of `ellmer::tool()` objects: `read_file`, `write_file`,
#'   `list_files`.
#'
#' @keywords internal
#' @export
bench_judge_tools <- function(
    test_dir, candidate_model, judge_output_file = "judge_result.json"
) {
    .require_ellmer()

    test_dir <- normalizePath(test_dir, mustWork = TRUE)
    allowed_write_path <- file.path("answer", candidate_model, judge_output_file)

    .resolve <- function(path) {
        full <- .lexical_normalize(file.path(test_dir, path))
        if (!startsWith(full, test_dir))
            stop("Path '", path, "' escapes the test directory; refusing.")
        full
    }

    # Any answer/ subfolder is blocked EXCEPT the one candidate being graded.
    # Written to work elementwise on either a scalar or a vector of paths
    # (list_files() below needs the vector form).
    .blocked <- function(path) {
        is_answer <- grepl("^answer(/|$)", path)
        is_candidate <- grepl(paste0("^answer/", candidate_model, "(/|$)"), path)
        is_answer & !is_candidate
    }

    read_file <- function(path) {
        if (.blocked(path))
            stop(
                "Reading '", path, "' is not permitted (the judge may only ",
                "read the candidate's own answer folder, 'answer/",
                candidate_model, "/', not other candidates' submissions)."
            )
        full <- .resolve(path)
        if (!file.exists(full)) stop("File does not exist: ", path)
        paste(readLines(full, warn = FALSE), collapse = "\n")
    }

    write_file <- function(path, content) {
        if (!identical(path, allowed_write_path))
            stop(
                "Writes are only permitted to '", allowed_write_path,
                "'; got '", path, "'."
            )
        full <- .resolve(path)
        dir.create(dirname(full), recursive = TRUE, showWarnings = FALSE)
        writeLines(content, full)
        paste("Wrote", nchar(content), "characters to", path)
    }

    list_files <- function(path = ".") {
        full <- .resolve(path)
        files <- list.files(full, recursive = TRUE)
        rel_prefix <- if (identical(path, ".")) "" else paste0(path, "/")
        rel_paths <- paste0(rel_prefix, files)
        keep <- !.blocked(rel_paths)
        paste(files[keep], collapse = "\n")
    }

    list(
        read_file = ellmer::tool(
            read_file,
            paste(
                "Read the full contents of a text file, given a path relative",
                "to the test directory. Unlike an answering agent, the judge",
                "may read task.json, eval.json, eval_v2.json, data/,",
                "ref_answer/, ref_script/, and the candidate's own answer",
                "folder, but not any other candidate's answer folder."
            ),
            arguments = list(
                path = ellmer::type_string("Path relative to the test directory, e.g. 'eval.json' or 'ref_answer/result.csv'.")
            )
        ),
        write_file = ellmer::tool(
            write_file,
            paste0(
                "Write the judge's verdict, given a path relative to the ",
                "test directory. Only '", allowed_write_path, "' may be written."
            ),
            arguments = list(
                path = ellmer::type_string(paste0("Must be exactly '", allowed_write_path, "'.")),
                content = ellmer::type_string("The full text content (a JSON verdict object) to write to the file.")
            )
        ),
        list_files = ellmer::tool(
            list_files,
            "List files under a directory, given a path relative to the test directory.",
            arguments = list(
                path = ellmer::type_string("Directory path relative to the test directory. Defaults to the test directory root.")
            )
        )
    )
}

#' Run a single LLM judge against one benchmark test's candidate answer
#'
#' Automates the grading step that, until now, has been done by hand (see
#' the `bioc-1-a` calibration data point in `documents/ideas.md`): loads the
#' test's judge prompt template (as copied by [add_prompts()]), equips the
#' model with [bench_judge_tools()] (the inverse of [bench_llm_tools()]:
#' allowed to read the reference materials, restricted to writing only the
#' verdict file), and instructs it to write a structured verdict to
#' `answer/<candidate_model>/judge_result.json`. The verdict fields
#' (`score`, `verdict`, `confidence`, `rationale`) match the columns already
#' used in `data/judge_calibration/pilot/judge_scores.csv`, for continuity
#' with the existing calibration data.
#'
#' @param test_id `character(1)` identifier for the test.
#' @param provider `character(1)` which ellmer chat backend the judge uses;
#'   see [bench_llm()].
#' @param model `character(1)` the judge model name.
#' @param candidate_model `character(1)` the model whose `answer/<model>/`
#'   submission should be graded. If `NULL` (the default), every subfolder
#'   of `answer/` is graded in turn.
#' @param output_dir `character(1)` as in [bench_llm()].
#' @param prompt_version `character(1)` which judge prompt template to send,
#'   `""` for `judgeprompt.txt` or `"_v2"` for `judgeprompt_v2.txt`.
#'   Defaults to `""`.
#' @param prompt_file `character(1)` optional explicit prompt file name,
#'   overriding `prompt_version`. Defaults to `NULL`.
#' @param judge_output_file `character(1)` file name (within
#'   `answer/<candidate_model>/`) the judge is instructed to write its
#'   verdict to. Defaults to `"judge_result.json"`.
#' @param system_prompt,echo,max_turns as in [bench_llm()].
#' @param ... additional named arguments forwarded to the provider's
#'   `chat_*()` constructor.
#'
#' @return If `candidate_model` is supplied, a `list` with elements
#'   `model_name` (the judge model), `candidate_model`, `response`, and
#'   `chat`. If `candidate_model` is `NULL`, a named `list` of such results,
#'   one per `answer/` subfolder. Returned invisibly.
#'
#' @examples
#' \dontrun{
#' bench_judge(
#'     "bioc-1-a",
#'     provider = "anthropic",
#'     model = "claude-opus-4-5",
#'     candidate_model = "gpt-5"
#' )
#' }
#'
#' @export
bench_judge <- function(
    test_id, provider = names(.ellmer_providers), model, candidate_model = NULL,
    output_dir = getwd(), prompt_version = c("", "_v2"), prompt_file = NULL,
    judge_output_file = "judge_result.json", system_prompt = NULL,
    echo = "none", max_turns = 20, ...
) {
    .require_ellmer()

    provider <- match.arg(provider)
    prompt_version <- match.arg(prompt_version)

    if (missing(model) || is.null(model) || !nzchar(model))
        stop("'model' must be supplied (e.g. 'gpt-4o', 'claude-opus-4-5').")

    test_dir <- file.path(output_dir, test_id)
    if (!dir.exists(test_dir))
        stop("Test directory does not exist. Run bench_folders() first.")

    answer_root <- file.path(test_dir, "answer")
    if (is.null(candidate_model)) {
        candidate_models <- basename(list.dirs(answer_root, recursive = FALSE))
        if (length(candidate_models) == 0)
            stop("No answer/ submissions found under '", test_dir, "'.")
        results <- lapply(candidate_models, function(m) {
            bench_judge(
                test_id = test_id, provider = provider, model = model,
                candidate_model = m, output_dir = output_dir,
                prompt_version = prompt_version, prompt_file = prompt_file,
                judge_output_file = judge_output_file,
                system_prompt = system_prompt, echo = echo,
                max_turns = max_turns, ...
            )
        })
        names(results) <- candidate_models
        return(invisible(results))
    }

    candidate_dir <- file.path(answer_root, candidate_model)
    if (!dir.exists(candidate_dir))
        stop(
            "No 'answer/", candidate_model, "' submission found under '",
            test_dir, "'."
        )

    if (is.null(prompt_file)) {
        prompt_file <- if (prompt_version == "") "judgeprompt.txt" else "judgeprompt_v2.txt"
    }
    prompt_path <- file.path(test_dir, "prompt", prompt_file)
    if (!file.exists(prompt_path))
        stop(
            "Prompt file '", prompt_file, "' not found under '", test_dir,
            "/prompt'. Run add_prompts() first."
        )

    prompt_text <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
    prompt_text <- gsub("bioc-1-a", test_id, prompt_text, fixed = TRUE)
    judge_target_path <- file.path("answer", candidate_model, judge_output_file)
    prompt_text <- paste0(
        prompt_text, "\n\nGrade the submission under 'answer/", candidate_model,
        "/'. Compare it against the reference materials (ref_answer/,",
        " ref_script/, eval.json, and eval_v2.json's rubric if present).",
        " Write your verdict as a single JSON object with fields 'score'",
        " (numeric, 0 to 1), 'verdict' (one of 'equivalent',",
        " 'partially_equivalent', 'not_equivalent'), 'confidence' (numeric,",
        " 0 to 1), and 'rationale' (a short explanation), to '",
        judge_target_path, "' using the write_file tool."
    )

    constructor_name <- .ellmer_providers[[provider]]
    if (!exists(constructor_name, where = asNamespace("ellmer"), inherits = FALSE))
        stop(
            "ellmer does not provide a '", constructor_name, "()' constructor ",
            "in the installed version; check ellmer::", constructor_name, "()."
        )
    constructor <- getExportedValue("ellmer", constructor_name)

    chat_args <- list(model = model, echo = echo, ...)
    if (!is.null(system_prompt)) chat_args$system_prompt <- system_prompt
    chat <- do.call(constructor, chat_args)

    tools <- bench_judge_tools(
        test_dir, candidate_model, judge_output_file = judge_output_file
    )
    for (tool_name in names(tools)) chat$register_tool(tools[[tool_name]])

    response <- tryCatch(
        chat$chat(prompt_text),
        error = function(e) stop("bench_judge() chat failed: ", conditionMessage(e))
    )

    invisible(list(
        model_name = model, candidate_model = candidate_model,
        response = response, chat = chat
    ))
}

.read_judge_result <- function(test_dir, candidate_model, judge_output_file = "judge_result.json") {
    path <- file.path(test_dir, "answer", candidate_model, judge_output_file)
    if (!file.exists(path)) return(list(score = NA_real_, verdict = NA_character_))
    parsed <- tryCatch(jsonlite::fromJSON(path, simplifyVector = TRUE), error = function(e) NULL)
    if (is.null(parsed)) return(list(score = NA_real_, verdict = "UNPARSEABLE_JUDGE_RESULT"))
    list(
        score = suppressWarnings(as.numeric(parsed$score %||% NA_real_)),
        verdict = as.character(parsed$verdict %||% NA_character_)
    )
}

.summarize_verify_for_model <- function(verify_result, model) {
    numeric_row <- NULL
    if (!is.null(verify_result$numeric)) {
        model_rows <- verify_result$numeric[verify_result$numeric$model == model, , drop = FALSE]
        if (nrow(model_rows) > 0) numeric_row <- model_rows[1, ]
    }
    rubric_df <- verify_result$rubric[[model]]

    if (!is.null(rubric_df)) {
        checkable <- rubric_df[rubric_df$result %in% c("PASS", "FAIL"), , drop = FALSE]
        pass_rate <- if (nrow(checkable) > 0) mean(checkable$result == "PASS") else NA_real_
        verdict <- if (is.na(pass_rate)) "NO_CHECKABLE_CRITERIA" else if (pass_rate == 1) "PASS" else "FAIL"
        return(list(score = pass_rate, verdict = verdict))
    }
    if (!is.null(numeric_row)) {
        return(list(
            score = if (identical(numeric_row$verdict, "PASS")) 1 else 0,
            verdict = numeric_row$verdict
        ))
    }
    list(score = NA_real_, verdict = "NO_VERIFY_DATA")
}

#' Run a benchmark suite: multiple tasks x multiple models, judged and verified
#'
#' Orchestrates the full answer/judge/verify loop across every combination
#' of `test_ids` and `models`: for each pair, calls [bench_llm()] to
#' produce an answer, [bench_judge()] to grade it, and (when
#' `eval_v2.json` is present) [bench_verify()] to mechanically pre-check the
#' rubric. Each step is wrapped in `tryCatch()` so a single failing
#' task/model combination is recorded as an error row rather than aborting
#' the whole run (matching `code/biomni_query.py`'s per-task
#' try/except pattern), and all results are aggregated into one long-format
#' results table.
#'
#' Token/cost accounting is intentionally out of scope for this function;
#' only wall-clock elapsed time per step is captured.
#'
#' @param test_ids `character()` identifiers of the tests to run, matching
#'   subdirectories of `output_dir`.
#' @param models `data.frame` with columns `provider` and `model`, one row
#'   per provider/model pair to benchmark.
#' @param judge_provider,judge_model `character(1)` the provider/model to
#'   use for grading via [bench_judge()].
#' @param output_dir `character(1)` as in [bench_llm()].
#' @param prompt_version `character(1)` as in [bench_llm()]/[bench_judge()].
#' @param results_file `character(1)` file name (within `output_dir`) the
#'   aggregated results table is written to as CSV. Defaults to
#'   `"leaderboard.csv"`.
#' @param ... additional arguments forwarded to [bench_llm()].
#'
#' @return `data.frame` of results (also written to `results_file`), with
#'   columns `test_id`, `model`, `source` (`"answer"`, `"judge"`, or
#'   `"verify"`), `score`, `verdict`, `elapsed_seconds`, `error`. Also
#'   printed for convenience.
#'
#' @export
bench_run_suite <- function(
    test_ids, models, judge_provider, judge_model, output_dir = getwd(),
    prompt_version = c("", "_v2"), results_file = "leaderboard.csv", ...
) {
    prompt_version <- match.arg(prompt_version)
    if (!all(c("provider", "model") %in% names(models)))
        stop("'models' must be a data.frame with 'provider' and 'model' columns.")

    .timed <- function(expr) {
        start <- Sys.time()
        value <- tryCatch(list(value = expr, error = NULL),
                           error = function(e) list(value = NULL, error = conditionMessage(e)))
        value$elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
        value
    }

    rows <- list()
    .add_row <- function(test_id, model, source, score, verdict, elapsed, error) {
        rows[[length(rows) + 1]] <<- data.frame(
            test_id = test_id, model = model, source = source,
            score = as.numeric(score), verdict = as.character(verdict),
            elapsed_seconds = elapsed,
            error = if (is.null(error)) NA_character_ else error,
            stringsAsFactors = FALSE
        )
    }

    for (test_id in test_ids) {
        test_dir <- file.path(output_dir, test_id)
        for (i in seq_len(nrow(models))) {
            provider <- models$provider[i]
            model <- models$model[i]

            answer_run <- .timed(
                bench_llm(
                    test_id = test_id, provider = provider, model = model,
                    output_dir = output_dir, prompt_version = prompt_version, ...
                )
            )
            .add_row(
                test_id, model, "answer", NA_real_,
                if (is.null(answer_run$error)) "OK" else "ERROR",
                answer_run$elapsed, answer_run$error
            )
            if (!is.null(answer_run$error)) next

            judge_run <- .timed(
                bench_judge(
                    test_id = test_id, provider = judge_provider, model = judge_model,
                    candidate_model = model, output_dir = output_dir,
                    prompt_version = prompt_version
                )
            )
            judge_summary <- if (is.null(judge_run$error)) {
                .read_judge_result(test_dir, model)
            } else {
                list(score = NA_real_, verdict = "ERROR")
            }
            .add_row(
                test_id, model, "judge", judge_summary$score, judge_summary$verdict,
                judge_run$elapsed, judge_run$error
            )

            eval_v2_path <- file.path(test_dir, "eval_v2.json")
            if (file.exists(eval_v2_path)) {
                verify_run <- .timed(bench_verify(test_dir))
                verify_summary <- if (is.null(verify_run$error)) {
                    .summarize_verify_for_model(verify_run$value, model)
                } else {
                    list(score = NA_real_, verdict = "ERROR")
                }
                .add_row(
                    test_id, model, "verify", verify_summary$score, verify_summary$verdict,
                    verify_run$elapsed, verify_run$error
                )
            }
        }
    }

    results <- do.call(rbind, rows)
    write.csv(results, file.path(output_dir, results_file), row.names = FALSE)
    print(results, row.names = FALSE)
    results
}

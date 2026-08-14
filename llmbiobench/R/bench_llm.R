#' @importFrom jsonlite fromJSON
NULL

# Supported ellmer chat constructors, keyed by provider name. Each entry is
# the name of an `ellmer::chat_*()` function that accepts at least `model`
# as an argument. Extend this list as ellmer adds/renames providers.
.ellmer_providers <- c(
    openai = "chat_openai",
    anthropic = "chat_anthropic",
    google = "chat_google_gemini",
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
        full <- normalizePath(file.path(test_dir, path), mustWork = FALSE)
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
#' bench_folders("bioc-1-a", output_dir = tempdir())
#' bench_task("bioc-1-a", output_dir = tempdir(), question = "...", output_description = "...")
#' add_prompts("bioc-1-a", output_dir = tempdir())
#' bench_llm(
#'     "bioc-1-a",
#'     provider = "anthropic",
#'     model = "claude-opus-4-5",
#'     output_dir = tempdir()
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

# Read PromptBio-Bench data from Hugging Face

repo_id <- "promptbio-ai/promptbio-bench-data"
repo_url <- paste0("https://huggingface.co/datasets/", repo_id, "/resolve/main")
repo_api_url <- paste0("https://huggingface.co/api/datasets/", repo_id)

promptbio_task_url <- function(task_id, path) {
  file.path(repo_url, "tasks", task_id, path)
}

list_promptbio_task_ids <- function(track = c("all", "a", "b")) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Install jsonlite to list PromptBio-Bench task IDs.", call. = FALSE)
  }

  track <- match.arg(track)
  task_tree_url <- paste0(repo_api_url, "/tree/main/tasks?recursive=false")
  task_tree <- jsonlite::fromJSON(task_tree_url, simplifyVector = FALSE)

  task_ids <- vapply(
    task_tree,
    function(entry) basename(entry$path),
    character(1)
  )
  task_ids <- sort(task_ids)

  if (track != "all") {
    task_ids <- task_ids[startsWith(task_ids, paste0(track, "-"))]
  }

  task_ids
}

download_promptbio_file <- function(task_id, path, destdir = "data/promptbio-bench") {
  destination <- file.path(destdir, "tasks", task_id, path)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)

  download.file(
    url = promptbio_task_url(task_id, path),
    destfile = destination,
    mode = "wb"
  )

  destination
}

download_promptbio_task_metadata <- function(task_id, destdir = "data/promptbio-bench") {
  files <- c("task.json", "eval.json")
  paths <- vapply(
    files,
    function(path) download_promptbio_file(task_id, path, destdir),
    character(1)
  )

  invisible(paths)
}

download_promptbio_task_files <- function(task_id, destdir = "data/promptbio-bench") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Install jsonlite to read PromptBio-Bench JSON files.", call. = FALSE)
  }

  task_path <- file.path(destdir, "tasks", task_id, "task.json")
  eval_path <- file.path(destdir, "tasks", task_id, "eval.json")

  if (!file.exists(task_path) || !file.exists(eval_path)) {
    download_promptbio_task_metadata(task_id, destdir)
  }

  task <- jsonlite::fromJSON(task_path, simplifyVector = FALSE)
  eval <- jsonlite::fromJSON(eval_path, simplifyVector = FALSE)

  # task$input_files / eval$ref_answer / eval$ref_script are each a list of
  # path strings (or an empty list, e.g. a-1-1 has no input files at all).
  paths <- unique(c(
    vapply(task$input_files, identity, character(1)),
    vapply(eval$ref_answer, identity, character(1)),
    vapply(eval$ref_script, identity, character(1))
  ))
  paths <- paths[!file.exists(file.path(destdir, "tasks", task_id, paths))]

  downloaded <- vapply(
    paths,
    function(path) download_promptbio_file(task_id, path, destdir),
    character(1)
  )
  invisible(downloaded)
}

download_promptbio_all_metadata <- function(
  task_ids = list_promptbio_task_ids(),
  destdir = "data/promptbio-bench"
) {
  paths <- lapply(
    task_ids,
    function(task_id) download_promptbio_task_metadata(task_id, destdir)
  )
  names(paths) <- task_ids

  invisible(paths)
}

read_promptbio_json <- function(task_id, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Install jsonlite to read PromptBio-Bench JSON files.", call. = FALSE)
  }

  jsonlite::fromJSON(promptbio_task_url(task_id, path), simplifyVector = FALSE)
}

read_promptbio_task <- function(task_id) {
  list(
    task = read_promptbio_json(task_id, "task.json"),
    eval = read_promptbio_json(task_id, "eval.json")
  )
}

# Examples:
# task_ids <- list_promptbio_task_ids()
# length(task_ids)
# head(task_ids)
#
# track_a <- list_promptbio_task_ids("a")
# track_b <- list_promptbio_task_ids("b")
#
# task <- read_promptbio_task("a-1-1")
# task$task$question
# task$task$expected_output
# task$eval$ref_answer
# task$eval$ref_script
#
# Download task.json and eval.json for every task.
# download_promptbio_all_metadata(task_ids)
#
# Download the actual data/ref_answer/ref_script files a specific task's
# task.json/eval.json reference (fetches task.json/eval.json first if not
# already present locally).
# download_promptbio_task_files("a-1-1")

# To download the full Hugging Face dataset, prefer the Hugging Face CLI.
# The full dataset is large, so task-level downloads are usually better.
#
# system2(
#   "hf",
#   args = c(
#     "download",
#     repo_id,
#     "--repo-type", "dataset",
#     "--local-dir", "data/promptbio-bench"
#   )
# )

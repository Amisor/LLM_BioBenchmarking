# Reading task b-3-1

if (!requireNamespace("googledrive", quietly = TRUE)) {
  stop("Install googledrive with install.packages('googledrive').", call. = FALSE)
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install jsonlite with install.packages('jsonlite').", call. = FALSE)
}

folder_id <- "1yyXzjhPK04wwzXIAvjKuIQsNCQbADmXT"
drive_folder_mime_type <- "application/vnd.google-apps.folder"
drive_shortcut_mime_type <- "application/vnd.google-apps.shortcut"

googledrive::drive_auth(
  scopes = "https://www.googleapis.com/auth/drive.readonly"
)

task_folder <- googledrive::as_id(folder_id)
task_files <- googledrive::drive_ls(task_folder)

is_drive_folder <- function(file) {
  identical(file$drive_resource[[1]]$mimeType, drive_folder_mime_type)
}

is_drive_shortcut <- function(file) {
  identical(file$drive_resource[[1]]$mimeType, drive_shortcut_mime_type)
}

resolve_drive_shortcut <- function(file) {
  if (!is_drive_shortcut(file)) {
    return(file)
  }

  target_id <- file$drive_resource[[1]]$shortcutDetails$targetId
  googledrive::drive_get(googledrive::as_id(target_id))
}

list_drive_tree <- function(folder, prefix = "") {
  children <- googledrive::drive_ls(folder)
  rows <- list()

  for (i in seq_len(nrow(children))) {
    child <- children[i, ]
    child_path <- file.path(prefix, child$name)
    child <- resolve_drive_shortcut(child)
    child$relative_path <- child_path
    rows[[length(rows) + 1]] <- child

    if (is_drive_folder(child)) {
      rows <- c(
        rows,
        list_drive_tree(googledrive::as_id(child$id), child_path)
      )
    }
  }

  rows
}

task_tree <- do.call(rbind, list_drive_tree(task_folder))

read_drive_json <- function(files, file_name) {
  matches <- files[files$name == file_name, ]

  if (nrow(matches) == 0) {
    stop("Could not find ", file_name, " in the Drive folder.", call. = FALSE)
  }

  if (nrow(matches) > 1) {
    stop("Found more than one ", file_name, " in the Drive folder.", call. = FALSE)
  }

  json_text <- googledrive::drive_read_string(matches)
  jsonlite::fromJSON(json_text, simplifyVector = FALSE)
}

find_drive_file <- function(files, relative_path) {
  matches <- files[files$relative_path == relative_path, ]

  if (nrow(matches) == 0) {
    basename_matches <- files[files$name == basename(relative_path), ]

    if (nrow(basename_matches) == 1) {
      return(basename_matches)
    }

    available <- paste(files$relative_path, collapse = "\n  - ")
    stop(
      "Could not find ", relative_path, " in the Drive folder.\n\n",
      "Available files:\n  - ", available,
      call. = FALSE
    )
  }

  if (nrow(matches) > 1) {
    stop("Found more than one ", relative_path, " in the Drive folder.", call. = FALSE)
  }

  matches
}

read_drive_text_path <- function(files, relative_path) {
  file <- find_drive_file(files, relative_path)
  googledrive::drive_read_string(file)
}

read_drive_raw_path <- function(files, relative_path) {
  file <- find_drive_file(files, relative_path)
  googledrive::drive_read_raw(file)
}

read_drive_csv_path <- function(files, relative_path, ...) {
  csv_text <- read_drive_text_path(files, relative_path)
  read.csv(text = csv_text, ...)
}

read_drive_tsv_path <- function(files, relative_path, ...) {
  tsv_text <- read_drive_text_path(files, relative_path)
  read.delim(text = tsv_text, ...)
}

read_drive_png_path <- function(files, relative_path) {
  if (!requireNamespace("png", quietly = TRUE)) {
    stop("Install png with install.packages('png') to read PNG files.", call. = FALSE)
  }

  png_raw <- read_drive_raw_path(files, relative_path)
  png_signature <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))

  if (length(png_raw) < 8 || !identical(png_raw[1:8], png_signature)) {
    preview <- rawToChar(png_raw[seq_len(min(length(png_raw), 200))])
    stop(
      relative_path, " was found, but its contents are not PNG bytes.\n\n",
      "First bytes as text:\n", preview,
      call. = FALSE
    )
  }

  png::readPNG(png_raw)
}

display_png <- function(image) {
  grid::grid.newpage()
  grid::grid.raster(image)
  invisible(image)
}

read_drive_file_path <- function(files, relative_path, ...) {
  extension <- tolower(tools::file_ext(relative_path))

  switch(
    extension,
    csv = read_drive_csv_path(files, relative_path, ...),
    tsv = read_drive_tsv_path(files, relative_path, ...),
    txt = read_drive_text_path(files, relative_path),
    r = read_drive_text_path(files, relative_path),
    py = read_drive_text_path(files, relative_path),
    sh = read_drive_text_path(files, relative_path),
    json = {
      json_text <- read_drive_text_path(files, relative_path)
      jsonlite::fromJSON(json_text, simplifyVector = FALSE)
    },
    png = read_drive_png_path(files, relative_path),
    read_drive_raw_path(files, relative_path)
  )
}

task <- read_drive_json(task_files, "task.json")
eval <- read_drive_json(task_files, "eval.json")
input_data <- lapply(task$input_files, read_drive_file_path, files = task_tree)
names(input_data) <- task$input_files
ref_script_text <- lapply(eval$ref_script, read_drive_file_path, files = task_tree)
names(ref_script_text) <- eval$ref_script
ref_answer <- lapply(eval$ref_answer, read_drive_file_path, files = task_tree)
names(ref_answer) <- eval$ref_answer

task$question
task$expected_output
input_data
eval$ref_answer
eval$ref_script
ref_script_text
ref_answer

# Display the reference PNG for this task.
display_png(ref_answer[[1]])

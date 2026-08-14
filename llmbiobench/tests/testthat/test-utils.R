# No withr dependency in this package: each test creates its own tempdir
# and cleans it up via its own on.exit(unlink(...)) call.
local_test_dir <- function() {
    tmp <- tempfile("llmbiobench-test-")
    dir.create(tmp)
    tmp
}

test_that("bench_folders() creates the standard subfolder layout", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

    result <- bench_folders("t-1", output_dir = tmp)
    expect_equal(result, "t-1")

    test_dir <- file.path(tmp, "t-1")
    expect_true(dir.exists(test_dir))
    for (folder in c("data", "prompt", "ref_answer", "ref_script", "answer")) {
        expect_true(dir.exists(file.path(test_dir, folder)), info = folder)
    }
})

test_that("bench_folders() rejects a test_id containing whitespace", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

    expect_error(bench_folders("bad id", output_dir = tmp), "should not contain spaces")
})

test_that("bench_folders() is idempotent (safe to call twice)", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

    bench_folders("t-1", output_dir = tmp)
    expect_no_error(bench_folders("t-1", output_dir = tmp))
})

test_that("bench_task() writes a task.json matching its return value", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    task <- bench_task(
        "t-1", output_dir = tmp,
        question = "Compute the mean of each column.",
        output_file = "column_means.csv",
        output_description = "A CSV file with one row per column mean."
    )

    expect_equal(task$id, "t-1")
    expect_equal(task$question, "Compute the mean of each column.")
    expect_equal(task$expected_output[[1]]$file, "column_means.csv")
    expect_equal(task$expected_output[[1]]$type, "csv")
    expect_equal(task$timeout_seconds, 3600)

    written <- jsonlite::fromJSON(file.path(tmp, "t-1", "task.json"), simplifyVector = FALSE)
    expect_equal(written$id, "t-1")
    expect_equal(written$expected_output[[1]]$file, "column_means.csv")
})

test_that("bench_task() errors if the test directory doesn't exist yet", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

    expect_error(
        bench_task(
            "missing-task", output_dir = tmp, question = "q",
            output_file = "out.csv", output_description = "d"
        ),
        "Run bench_folders"
    )
})

test_that("bench_eval() writes an eval.json with the reference file lists", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    writeLines("a,b\n1,2", file.path(tmp, "t-1", "ref_answer", "column_means.csv"))
    writeLines("# reference script", file.path(tmp, "t-1", "ref_script", "solution.R"))

    # bench_eval()'s expected_output loop always calls readline() with no way
    # to supply entries programmatically; readline() returns "" immediately
    # in a non-interactive session (confirmed: no hang), so expected_output
    # is always empty here. This test covers everything bench_eval() can
    # produce non-interactively: id/question/ref_answer/ref_script.
    eval <- bench_eval(
        "t-1", output_dir = tmp,
        question = "Compute the mean of each column.",
        guidelines = "Values must match within 1e-3."
    )

    expect_equal(eval$id, "t-1")
    expect_true("ref_answer/column_means.csv" %in% unlist(eval$ref_answer))
    expect_true("ref_script/solution.R" %in% unlist(eval$ref_script))
    expect_true(file.exists(file.path(tmp, "t-1", "eval.json")))
})

test_that("bench_eval() warns when ref_answer/ref_script are empty", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    expect_warning(
        expect_warning(
            bench_eval("t-1", output_dir = tmp, question = "q", guidelines = "g"),
            "No files found in 'ref_answer'"
        ),
        "No files found in 'ref_script'"
    )
})

test_that("add_data() writes csv and rds files into the data folder", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    csv_path <- add_data(mtcars, "t-1", type = "csv", output_dir = tmp)
    expect_true(file.exists(csv_path))
    expect_equal(basename(csv_path), "mtcars.csv")

    rds_path <- add_data(mtcars, "t-1", type = "rds", output_dir = tmp, file_name = "mtcars_copy")
    expect_true(file.exists(rds_path))
    expect_equal(basename(rds_path), "mtcars_copy.rds")
    expect_equal(readRDS(rds_path), mtcars)
})

test_that("add_data() errors if the data folder doesn't exist yet", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

    expect_error(
        add_data(mtcars, "missing-task", output_dir = tmp),
        "Run bench_folders"
    )
})

test_that("add_prompts() copies the original ('') prompt set", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    dest <- add_prompts("t-1", output_dir = tmp, version = "")
    expect_true(length(dest) > 0)
    expect_false(any(grepl("_v2\\.", basename(dest))))
    expect_true(all(file.exists(dest)))
})

test_that("add_prompts() copies the '_v2' prompt set", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    dest <- add_prompts("t-1", output_dir = tmp, version = "_v2")
    expect_true(length(dest) > 0)
    expect_true(all(grepl("_v2\\.", basename(dest))))
    expect_true(all(file.exists(dest)))
})

test_that("add_prompts() substitutes the {test_id} placeholder", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("my-task-42", output_dir = tmp)

    dest <- add_prompts("my-task-42", output_dir = tmp, version = "_v2")
    contents <- unlist(lapply(dest, readLines, warn = FALSE))
    expect_false(any(grepl("\\{test_id\\}", contents)))
})

test_that("add_prompts() rejects an invalid version argument", {
    tmp <- local_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    expect_error(add_prompts("t-1", output_dir = tmp, version = "v3"), "must be")
})

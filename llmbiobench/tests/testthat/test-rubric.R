test_that("mechanical_rubric_criteria() returns the expected base criteria", {
    criteria <- mechanical_rubric_criteria()
    ids <- vapply(criteria, function(x) x$id, character(1))

    expect_equal(
        ids,
        c(
            "required_output_present", "output_is_parseable",
            "output_matches_reference_values", "script_present",
            "uses_relative_paths", "avoids_reference_leakage"
        )
    )

    weights <- vapply(criteria, function(x) x$weight, numeric(1))
    expect_equal(weights, c(1, 2, 5, 1, 2, 5))
})

test_that("mechanical_rubric_criteria(has_row_names = TRUE) adds the row-name criterion", {
    criteria <- mechanical_rubric_criteria(has_row_names = TRUE)
    ids <- vapply(criteria, function(x) x$id, character(1))

    expect_length(criteria, 7)
    expect_equal(ids[7], "row_names_follow_required_format")
    expect_equal(criteria[[7]]$weight, 2)
})

test_that("every mechanical criterion has the required fields", {
    for (has_row_names in c(FALSE, TRUE)) {
        criteria <- mechanical_rubric_criteria(has_row_names = has_row_names)
        for (criterion in criteria) {
            expect_true(all(c("id", "criterion", "weight", "score_type", "evidence") %in% names(criterion)))
            expect_equal(criterion$score_type, "binary")
        }
    }
})

test_that("bench_rubric() merges mechanical and custom criteria", {
    tmp <- tempfile("llmbiobench-test-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)
    writeLines("a,b\n1,2", file.path(tmp, "t-1", "ref_answer", "out.csv"))
    writeLines("# ref", file.path(tmp, "t-1", "ref_script", "solution.R"))

    custom <- list(list(
        id = "uses_correct_input_file",
        criterion = "The submitted script reads the provided input file.",
        weight = 3, score_type = "binary",
        evidence = "Inspect the submitted script."
    ))

    eval_v2 <- bench_rubric(
        "t-1", output_dir = tmp,
        question = "q", guidelines = "g",
        custom_criteria = custom
    )

    ids <- vapply(eval_v2$scoring$rubric, function(x) x$id, character(1))
    expect_true("uses_correct_input_file" %in% ids)
    expect_true("required_output_present" %in% ids)
    expect_length(eval_v2$scoring$rubric, length(mechanical_rubric_criteria()) + 1)

    expect_equal(eval_v2$scoring$rubric_scoring$score_type, "weighted_binary")
    expect_true(file.exists(file.path(tmp, "t-1", "eval_v2.json")))
})

test_that("bench_rubric() doesn't leave its throwaway temp file behind", {
    tmp <- tempfile("llmbiobench-test-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)
    # Populate ref_answer/ref_script so bench_eval()'s "no files found"
    # warnings (unrelated to what this test checks) don't fire.
    writeLines("a,b\n1,2", file.path(tmp, "t-1", "ref_answer", "out.csv"))
    writeLines("# ref", file.path(tmp, "t-1", "ref_script", "solution.R"))

    bench_rubric("t-1", output_dir = tmp, question = "q", guidelines = "g")

    expect_false(file.exists(file.path(tmp, "t-1", "__bench_rubric_tmp.json")))
})

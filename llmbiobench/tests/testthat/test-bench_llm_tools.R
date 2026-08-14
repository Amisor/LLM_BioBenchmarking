# Security-relevant sandboxing logic in bench_llm_tools()/bench_judge_tools()
# had zero test coverage before this file. ellmer::tool() wraps a plain
# function (confirmed: `is.function(ellmer::tool(...))` is TRUE, and calling
# it directly invokes the wrapped function with no live chat/API call
# needed), so these tools can be exercised directly without any credentials.

skip_if_not_installed("ellmer")

local_llm_tools_test_dir <- function() {
    tmp <- tempfile("llmbiobench-tools-test-")
    dir.create(tmp)
    for (d in c("data", "prompt", "ref_answer", "ref_script", "answer")) {
        dir.create(file.path(tmp, d), recursive = TRUE)
    }
    writeLines("{}", file.path(tmp, "task.json"))
    writeLines("{}", file.path(tmp, "eval.json"))
    writeLines("{}", file.path(tmp, "eval_v2.json"))
    writeLines("input data", file.path(tmp, "data", "input.csv"))
    writeLines("the reference answer", file.path(tmp, "ref_answer", "out.csv"))
    writeLines("the reference script", file.path(tmp, "ref_script", "solution.R"))
    tmp
}

# ---- bench_llm_tools(): the answering model must NOT see reference material -

test_that("bench_llm_tools()$read_file allows task/data files", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    expect_equal(tools$read_file("task.json"), "{}")
    expect_equal(tools$read_file("data/input.csv"), "input data")
})

test_that("bench_llm_tools()$read_file blocks reference materials", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    expect_error(tools$read_file("ref_answer/out.csv"), "not permitted")
    expect_error(tools$read_file("ref_script/solution.R"), "not permitted")
    expect_error(tools$read_file("eval.json"), "not permitted")
    expect_error(tools$read_file("eval_v2.json"), "not permitted")
})

test_that("bench_llm_tools()$read_file rejects a path-escape attempt", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    expect_error(tools$read_file("../../../../../../etc/passwd"), "escapes the test directory")
})

test_that("bench_llm_tools()$write_file allows writes under answer/", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    tools$write_file("answer/gpt-5/result.csv", "1,2,3")
    expect_equal(readLines(file.path(tmp, "answer", "gpt-5", "result.csv")), "1,2,3")
})

test_that("bench_llm_tools()$write_file rejects writes outside answer/", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    expect_error(tools$write_file("ref_answer/out.csv", "tampered"), "only permitted under")
    expect_error(tools$write_file("data/input.csv", "tampered"), "only permitted under")
})

test_that("bench_llm_tools()$write_file rejects a path-escape attempt disguised under answer/", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    tools <- bench_llm_tools(tmp)

    # Passes the literal-prefix check (the path string starts with "answer"),
    # so this specifically exercises .resolve()'s escape detection, not the
    # allow_write_prefix check.
    expect_error(
        tools$write_file("answer/../../../../../../tmp/escaped.txt", "x"),
        "escapes the test directory"
    )
})

# ---- bench_judge_tools(): the judge MUST see reference material, but only --
# ---- its one candidate's answer folder, and can only write the verdict ----

test_that("bench_judge_tools()$read_file allows reference materials and the candidate's own answer", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    writeLines("candidate output", file.path(tmp, "answer", "gpt-5", "result.csv"))

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")

    expect_equal(tools$read_file("ref_answer/out.csv"), "the reference answer")
    expect_equal(tools$read_file("ref_script/solution.R"), "the reference script")
    expect_equal(tools$read_file("eval.json"), "{}")
    expect_equal(tools$read_file("answer/gpt-5/result.csv"), "candidate output")
})

test_that("bench_judge_tools()$read_file blocks other candidates' answer folders", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    dir.create(file.path(tmp, "answer", "claude-opus"), recursive = TRUE)
    writeLines("other candidate's output", file.path(tmp, "answer", "claude-opus", "result.csv"))

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")

    expect_error(tools$read_file("answer/claude-opus/result.csv"), "not permitted")
})

test_that("bench_judge_tools()$write_file allows only the exact judge output path", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    writeLines("candidate output", file.path(tmp, "answer", "gpt-5", "result.csv"))

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")

    tools$write_file("answer/gpt-5/judge_result.json", '{"score": 1}')
    expect_equal(
        readLines(file.path(tmp, "answer", "gpt-5", "judge_result.json")),
        '{"score": 1}'
    )
})

test_that("bench_judge_tools()$write_file rejects writing to the candidate's own submitted output", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    writeLines("candidate output", file.path(tmp, "answer", "gpt-5", "result.csv"))

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")

    expect_error(tools$write_file("answer/gpt-5/result.csv", "tampered"), "only permitted")
    expect_equal(readLines(file.path(tmp, "answer", "gpt-5", "result.csv")), "candidate output")
})

test_that("bench_judge_tools()$write_file rejects writing to another candidate's folder", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    dir.create(file.path(tmp, "answer", "claude-opus"), recursive = TRUE)

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")

    expect_error(
        tools$write_file("answer/claude-opus/judge_result.json", '{"score": 1}'),
        "only permitted"
    )
})

test_that("bench_judge_tools()$list_files hides other candidates' answer folders", {
    tmp <- local_llm_tools_test_dir()
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    dir.create(file.path(tmp, "answer", "gpt-5"), recursive = TRUE)
    dir.create(file.path(tmp, "answer", "claude-opus"), recursive = TRUE)
    writeLines("x", file.path(tmp, "answer", "gpt-5", "result.csv"))
    writeLines("y", file.path(tmp, "answer", "claude-opus", "result.csv"))

    tools <- bench_judge_tools(tmp, candidate_model = "gpt-5")
    listing <- tools$list_files(".")

    expect_true(grepl("answer/gpt-5/result.csv", listing, fixed = TRUE))
    expect_false(grepl("claude-opus", listing, fixed = TRUE))
})

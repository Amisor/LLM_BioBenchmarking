ns <- asNamespace("llmbiobench")
get_internal <- function(name) get(name, envir = ns)

# ---- .extract_tolerance() --------------------------------------------------

test_that(".extract_tolerance() parses 'within X' and '+/- X' guideline text", {
    extract_tolerance <- get_internal(".extract_tolerance")

    expect_equal(extract_tolerance("Values must match within 1e-3."), 1e-3)
    expect_equal(extract_tolerance("Allowed +/- 0.5 of the reference."), 0.5)
    expect_equal(extract_tolerance("No tolerance phrase here."), 1e-3)
    expect_equal(extract_tolerance("No tolerance phrase here.", default = 0.01), 0.01)
})

# ---- .read_numeric_matrix() -------------------------------------------------

test_that(".read_numeric_matrix() reads a labeled csv with row names", {
    read_numeric_matrix <- get_internal(".read_numeric_matrix")
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp))
    writeLines(c("id,a,b", "r1,1,2", "r2,3,4"), tmp)

    m <- read_numeric_matrix(tmp)
    expect_equal(dim(m), c(2, 2))
    expect_equal(rownames(m), c("r1", "r2"))
    expect_equal(unname(m["r1", "a"]), 1)
})

test_that(".read_numeric_matrix() returns NULL for non-numeric content", {
    read_numeric_matrix <- get_internal(".read_numeric_matrix")
    tmp <- tempfile(fileext = ".csv")
    on.exit(unlink(tmp))
    writeLines(c("id,label", "r1,hello", "r2,world"), tmp)

    expect_null(read_numeric_matrix(tmp))
})

# ---- .check_reference_leakage() / .check_relative_paths() ------------------

test_that(".check_reference_leakage() flags scripts that read reference files", {
    check_reference_leakage <- get_internal(".check_reference_leakage")
    tmp_ok <- tempfile(fileext = ".R")
    tmp_bad <- tempfile(fileext = ".R")
    on.exit(unlink(c(tmp_ok, tmp_bad)))

    writeLines("x <- read.csv('data/input.csv')", tmp_ok)
    writeLines("x <- read.csv('ref_answer/out.csv')", tmp_bad)

    expect_true(check_reference_leakage(tmp_ok))
    expect_false(check_reference_leakage(tmp_bad))
    expect_true(is.na(check_reference_leakage(character(0))))
})

test_that(".check_relative_paths() flags hardcoded absolute paths", {
    check_relative_paths <- get_internal(".check_relative_paths")
    tmp_ok <- tempfile(fileext = ".R")
    tmp_bad <- tempfile(fileext = ".R")
    on.exit(unlink(c(tmp_ok, tmp_bad)))

    writeLines("x <- read.csv('data/input.csv')", tmp_ok)
    writeLines("x <- read.csv('/Users/someone/data/input.csv')", tmp_bad)

    expect_true(check_relative_paths(tmp_ok))
    expect_false(check_relative_paths(tmp_bad))
})

# ---- .compare_fasta() -------------------------------------------------------

test_that(".compare_fasta() passes when sequence sets match regardless of header text", {
    compare_fasta <- get_internal(".compare_fasta")
    ref <- c(seq1 = "ACGT", seq2 = "TTTT")
    cand_same <- c(other_name = "acgt", another = "tttt")
    cand_diff <- c(seq1 = "ACGT", seq2 = "AAAA")

    expect_equal(compare_fasta(ref, cand_same)$verdict, "PASS")
    expect_equal(compare_fasta(ref, cand_diff)$verdict, "FAIL")
    expect_equal(compare_fasta(ref, NULL)$verdict, "UNPARSEABLE")
})

test_that(".read_fasta() strips line-wrapping and whitespace, upper-cases sequence", {
    read_fasta <- get_internal(".read_fasta")
    tmp <- tempfile(fileext = ".fasta")
    on.exit(unlink(tmp))
    writeLines(c(">seq1", "acgt", "tttt", ">seq2", "gggg"), tmp)

    parsed <- read_fasta(tmp)
    expect_equal(unname(parsed["seq1"]), "ACGTTTTT")
    expect_equal(unname(parsed["seq2"]), "GGGG")
})

test_that(".read_fasta() returns NULL for a file with no header line", {
    read_fasta <- get_internal(".read_fasta")
    tmp <- tempfile(fileext = ".fasta")
    on.exit(unlink(tmp))
    writeLines("ACGTACGT", tmp)

    expect_null(read_fasta(tmp))
})

# ---- .read_generic_table() / .compare_tables() ------------------------------

test_that(".compare_tables() matches rows by key column, numeric tolerance for numeric columns", {
    read_generic_table <- get_internal(".read_generic_table")
    compare_tables <- get_internal(".compare_tables")

    tmp_ref <- tempfile(fileext = ".tsv")
    tmp_cand_ok <- tempfile(fileext = ".tsv")
    tmp_cand_bad <- tempfile(fileext = ".tsv")
    on.exit(unlink(c(tmp_ref, tmp_cand_ok, tmp_cand_bad)))

    writeLines(c("Sequence_ID\tGC_percent", "seq2\t60.0", "seq1\t50.0"), tmp_ref)
    writeLines(c("Sequence_ID\tGC_percent", "seq1\t50.0005", "seq2\t60.0"), tmp_cand_ok)
    writeLines(c("Sequence_ID\tGC_percent", "seq1\t50.0", "seq2\t99.0"), tmp_cand_bad)

    ref <- read_generic_table(tmp_ref)
    expect_equal(compare_tables(ref, read_generic_table(tmp_cand_ok), tol = 1e-3)$verdict, "PASS")
    expect_equal(compare_tables(ref, read_generic_table(tmp_cand_bad), tol = 1e-3)$verdict, "FAIL")
})

test_that(".compare_tables() fails on mismatched row keys", {
    read_generic_table <- get_internal(".read_generic_table")
    compare_tables <- get_internal(".compare_tables")

    tmp_ref <- tempfile(fileext = ".tsv")
    tmp_cand <- tempfile(fileext = ".tsv")
    on.exit(unlink(c(tmp_ref, tmp_cand)))

    writeLines(c("id\tval", "a\t1", "b\t2"), tmp_ref)
    writeLines(c("id\tval", "a\t1", "c\t2"), tmp_cand)

    ref <- read_generic_table(tmp_ref)
    expect_equal(compare_tables(ref, read_generic_table(tmp_cand), tol = 1e-3)$verdict, "FAIL")
})

# ---- .compare_txt() ---------------------------------------------------------

test_that(".compare_txt() applies numeric tolerance to a scalar reference", {
    compare_txt <- get_internal(".compare_txt")
    tmp_ref <- tempfile(fileext = ".txt")
    tmp_cand_ok <- tempfile(fileext = ".txt")
    tmp_cand_bad <- tempfile(fileext = ".txt")
    on.exit(unlink(c(tmp_ref, tmp_cand_ok, tmp_cand_bad)))

    writeLines("42.0", tmp_ref)
    writeLines("42.0005", tmp_cand_ok)
    writeLines("99.0", tmp_cand_bad)

    expect_equal(compare_txt(tmp_ref, tmp_cand_ok, tol = 1e-3)$verdict, "PASS")
    expect_equal(compare_txt(tmp_ref, tmp_cand_bad, tol = 1e-3)$verdict, "FAIL")
})

test_that(".compare_txt() flags free text as needing a judge", {
    compare_txt <- get_internal(".compare_txt")
    tmp_ref <- tempfile(fileext = ".txt")
    tmp_cand <- tempfile(fileext = ".txt")
    on.exit(unlink(c(tmp_ref, tmp_cand)))

    writeLines("total length: 100bp; part1 1-50; part2 51-100", tmp_ref)
    writeLines("total length: 100bp; part1 1-50; part2 51-100", tmp_cand)

    expect_equal(compare_txt(tmp_ref, tmp_cand, tol = 1e-3)$verdict, "NEEDS_JUDGE")
})

# ---- bench_verify() end-to-end on a synthetic test directory ---------------

test_that("bench_verify() reports PASS/FAIL correctly on a synthetic task", {
    tmp <- tempfile("llmbiobench-test-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    writeLines(c("id,x", "r1,1.0", "r2,2.0"), file.path(tmp, "t-1", "ref_answer", "out.csv"))

    eval <- list(
        id = "t-1", question = "q",
        ref_answer = list("ref_answer/out.csv"), ref_script = list(),
        scoring = list(expected_output = list(list(
            file = "out.csv", guidelines = "within 1e-3"
        )))
    )
    jsonlite::write_json(eval, file.path(tmp, "t-1", "eval.json"), auto_unbox = TRUE, pretty = TRUE)

    dir.create(file.path(tmp, "t-1", "answer", "good-model"), recursive = TRUE)
    writeLines(c("id,x", "r1,1.0", "r2,2.0"), file.path(tmp, "t-1", "answer", "good-model", "out.csv"))
    dir.create(file.path(tmp, "t-1", "answer", "bad-model"), recursive = TRUE)
    writeLines(c("id,x", "r1,1.0", "r2,99.0"), file.path(tmp, "t-1", "answer", "bad-model", "out.csv"))

    result <- bench_verify(file.path(tmp, "t-1"))

    good_row <- result$numeric[result$numeric$model == "good-model", ]
    bad_row <- result$numeric[result$numeric$model == "bad-model", ]
    expect_equal(good_row$verdict, "PASS")
    expect_equal(bad_row$verdict, "FAIL")
})

test_that("bench_verify() flags an unhandled extension as NEEDS_JUDGE instead of skipping it", {
    tmp <- tempfile("llmbiobench-test-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    bench_folders("t-1", output_dir = tmp)

    writeLines("fake png bytes", file.path(tmp, "t-1", "ref_answer", "plot.png"))
    eval <- list(
        id = "t-1", question = "q",
        ref_answer = list("ref_answer/plot.png"), ref_script = list(),
        scoring = list(expected_output = list(list(
            file = "plot.png", guidelines = "must show a scatter plot"
        )))
    )
    jsonlite::write_json(eval, file.path(tmp, "t-1", "eval.json"), auto_unbox = TRUE, pretty = TRUE)

    dir.create(file.path(tmp, "t-1", "answer", "model-a"), recursive = TRUE)
    writeLines("fake png bytes", file.path(tmp, "t-1", "answer", "model-a", "plot.png"))

    result <- bench_verify(file.path(tmp, "t-1"))
    expect_equal(result$numeric$verdict[result$numeric$model == "model-a"], "NEEDS_JUDGE")
})

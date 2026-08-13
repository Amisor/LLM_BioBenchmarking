library(processx)
library(jsonlite)
library(dplyr)
library(tibble)

# ==========================================
# 1. START BIOMNI PYTHON BRIDGE
# ==========================================

cat("[+] Starting Biomni Python bridge...\n")

biomni <- process$new(
  command = "python",
  args = "code/biomni_query_troubleshoot.py",
  stdin = "|",
  stdout = "|",
  stderr = "|"
)

#Troubleshoot bridge
Sys.sleep(2)

cat("Python stderr:\n")
cat(biomni$read_error_lines(), sep = "\n")

cat("\nPython stdout:\n")
cat(biomni$read_output_lines(), sep = "\n")

cat("\nProcess alive:", biomni$is_alive(), "\n")

# Wait for Biomni to finish initialization
ready <- biomni$read_output_lines(n = 1)

ready <- jsonlite::fromJSON(ready)

if (ready$status != "ready") {
  stop("Biomni failed to initialize.")
}

cat("[+] Biomni initialized.\n\n")


# ==========================================
# 2. DEFINE BENCHMARK TASKS
# ==========================================

benchmark_tasks <- list(
  
  list(
    task_id = "task_001_reverse_transcription",
    category = "Genomics",
    difficulty = "Easy",
    input_rna = "AUGGCAUUCGAAUGA",
    ground_truth = "TCATTCGAATGCCAT",
    prompt = paste0(
      "Provide ONLY the resulting cDNA sequence (in 5' to 3' direction) ",
      "for reverse transcription of the following RNA sequence: ",
      "AUGGCAUUCGAAUGA. ",
      "Do not include commentary, explanations, or extra formatting. ",
      "Return raw sequence only."
    )
  ),
  
  list(
    task_id = "task_002_reverse_transcription",
    category = "Genomics",
    difficulty = "Easy",
    input_rna = "AUGCCGAU",
    ground_truth = "ATCGGCAT",
    prompt = paste0(
      "Provide ONLY the resulting cDNA sequence (in 5' to 3' direction) ",
      "for reverse transcription of the following RNA sequence: ",
      "AUGCCGAU. ",
      "Do not include commentary, explanations, or extra formatting. ",
      "Return raw sequence only."
    )
  )
  
  # Add additional benchmark tasks here
)


# ==========================================
# 3. FUNCTION TO QUERY BIOMNI
# ==========================================

query_biomni <- function(task) {
  
  # Send task to Python
  json_task <- jsonlite::toJSON(
    list(
      task_id = task$task_id,
      prompt = task$prompt
    ),
    auto_unbox = TRUE
  )
  
  biomni$write_input(paste0(json_task, "\n"))
  
  # Wait for response from Biomni
  response_line <- biomni$read_output_lines(n = 1)
  
  # Convert JSON response back into R
  jsonlite::fromJSON(response_line)
}


# ==========================================
# 4. RUN ALL BENCHMARKS
# ==========================================

results <- vector("list", length(benchmark_tasks))

for (i in seq_along(benchmark_tasks)) {
  
  task <- benchmark_tasks[[i]]
  
  cat(
    "[",
    i,
    "/",
    length(benchmark_tasks),
    "] Running ",
    task$task_id,
    "...\n",
    sep = ""
  )
  
  # Start timer immediately before Biomni call
  start_time <- Sys.time()
  
  result <- query_biomni(task)
  
  # Stop timer immediately after Biomni responds
  end_time <- Sys.time()
  
  response_time_sec <- as.numeric(
    difftime(
      end_time,
      start_time,
      units = "secs"
    )
  )
  
  # Extract response
  raw_answer <- result$response
  
  # Clean response for sequence comparison
  cleaned_answer <- gsub(
    "[^A-Za-z]",
    "",
    raw_answer
  )
  
  cleaned_answer <- toupper(cleaned_answer)
  
  # Compare against ground truth
  exact_match <- (
    cleaned_answer == toupper(task$ground_truth)
  )
  
  # Store everything
  results[[i]] <- tibble(
    task_id = task$task_id,
    category = task$category,
    difficulty = task$difficulty,
    input_rna = task$input_rna,
    ground_truth = task$ground_truth,
    agent_answer = cleaned_answer,
    raw_response = raw_answer,
    exact_match = exact_match,
    accuracy = ifelse(exact_match, 1, 0),
    response_time_sec = round(response_time_sec, 3),
    error = result$error
  )
  
  cat(
    "    Response:",
    cleaned_answer,
    "\n"
  )
  
  cat(
    "    Time:",
    round(response_time_sec, 3),
    "seconds\n"
  )
  
  cat(
    "    Correct:",
    exact_match,
    "\n\n"
  )
}


# ==========================================
# 5. COMBINE RESULTS
# ==========================================

benchmark_results <- bind_rows(results)

print(benchmark_results)


# ==========================================
# 6. SAVE RESULTS
# ==========================================

write.csv(
  benchmark_results,
  "biomni_benchmark_results.csv",
  row.names = FALSE
)

cat("\n[+] Results saved to biomni_benchmark_results.csv\n")


# ==========================================
# 7. SHUT DOWN PYTHON
# ==========================================

biomni$kill()
biomni$wait()

cat("[+] Biomni Python bridge closed.\n")
library(httr2)
library(jsonlite)
library(Biostrings) # For rigorous string cleaning & sequence operations

# ==========================================
# 1. DEFINE BENCHMARK TASK (JSON WORKFLOW)
# ==========================================

# Define input RNA and pre-computed cDNA ground truth
input_rna    <- "AUGGCAUUCGAAUGA"
ground_truth <- "TCATTCGAATGCCAT"

# Package into structured task payload
benchmark_task <- list(
  task_id = "task_001_reverse_transcription",
  category = "Genomics",
  difficulty = "Easy",
  input = list(
    rna_sequence = input_rna,
    direction = "5'-to-3'"
  ),
  ground_truth = ground_truth,
  prompt = paste0(
    "Provide ONLY the resulting cDNA sequence (in 5' to 3' direction) ",
    "for reverse transcription of the following RNA sequence: ", input_rna, ". ",
    "Do not include any commentary, explanations, or extra formatting. Return raw sequence only."
  )
)

# Convert task to JSON format for storage/logging
task_json <- jsonlite::toJSON(benchmark_task, auto_unbox = TRUE, pretty = TRUE)
cat("--- Benchmarking Task JSON ---\n")
cat(task_json, "\n\n")

# ==========================================
# 2. BIOMNI AUTHENTICATION & LOGIN
# ==========================================

# Replace with your actual Biomni API host and account credentials
BIOMNI_BASE_URL <- "https://biomni.phylo.bio/" # Or your organization's endpoint
BIOMNI_EMAIL    <- "leah.vandenbosch@seattlechildrens.org"
## BIOMNI doesn't use a password structure. We need to figure out an alternative for logging in. Currently, this is broken!

cat("[+] Logging in to Biomni...\n")

# Step A: Request Authentication Bearer Token
auth_response <- tryCatch({
  request(paste0(BIOMNI_BASE_URL, "/v1/auth/login")) %>%
    req_body_json(list(
      email = BIOMNI_EMAIL,
      #password = BIOMNI_PASSWORD
    )) %>%
    req_perform()
}, error = function(e) {
  stop("Login failed! Please check credentials or API endpoint URL.")
})

# Extract token
token_data <- resp_body_json(auth_response)
auth_token <- token_data$access_token # Adjust key according to your Biomni tenant response format
cat("[+] Login successful! Token acquired.\n\n")

# ==========================================
# 3. RUN BENCHMARK & MEASURE SPEED
# ==========================================

cat("[+] Sending benchmark task to Biomni agent...\n")

start_time <- Sys.time()

# Execute inference call
agent_response <- request(paste0(BIOMNI_BASE_URL, "/v1/agent/run")) %>%
  req_headers(
    "Authorization" = paste("Bearer", auth_token),
    "Content-Type" = "application/json"
  ) %>%
  req_body_json(list(
    prompt = benchmark_task$prompt,
    temperature = 0.0 # Force deterministic output for evaluation
  )) %>%
  req_perform()

end_time <- Sys.time()

# Calculate execution speed in seconds
response_time_sec <- as.numeric(difftime(end_time, start_time, units = "secs"))

# Parse agent output
res_json <- resp_body_json(agent_response)
raw_agent_answer <- res_json$response # Adjust key if agent output key differs

# Clean output string (strip whitespace, newlines, quotes)
cleaned_agent_answer <- gsub("[^A-Za-z]", "", raw_agent_answer)
cleaned_agent_answer <- toupper(cleaned_agent_answer)

# ==========================================
# 4. EVALUATE ACCURACY & COMPILE RESULTS
# ==========================================

is_exact_match <- (cleaned_agent_answer == ground_truth)
accuracy_score <- if (is_exact_match) 1.0 else 0.0

# Generate final benchmark report
benchmark_report <- tibble::tibble(
  task_id = benchmark_task$task_id,
  difficulty = benchmark_task$difficulty,
  input_rna = input_rna,
  ground_truth = ground_truth,
  agent_answer = cleaned_agent_answer,
  raw_response = raw_agent_answer,
  exact_match = is_exact_match,
  accuracy = accuracy_score,
  response_time_sec = round(response_time_sec, 3)
)

cat("\n================ BENCHMARK REPORT ================\n")
print(benchmark_report)
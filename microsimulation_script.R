# =====================================================================
# 1. SETUP: Health Economics Parameters
# =====================================================================
utility_PF <- 0.85   # High quality of life before progression
utility_PD <- 0.50   # Lower quality of life after progression
cost_PF_per_mo <- 5000 
cost_PD_per_mo <- 8000 

# Assume 'result$data' is the output from our previous Simulated Annealing script
paired_data <- result$data 

# Create the "Naive" uncorrelated data by randomly shuffling the OS column
uncorrelated_data <- paired_data
uncorrelated_data$os_time <- sample(uncorrelated_data$os_time)

# =====================================================================
# 2. MICROSIMULATION FUNCTION
# =====================================================================
run_microsim <- function(data, is_naive = FALSE) {
  
  n_patients <- nrow(data)
  total_qalys <- numeric(n_patients)
  total_costs <- numeric(n_patients)
  
  for(i in 1:n_patients) {
    pfs <- data$pfs_time[i]
    os <- data$os_time[i]
    
    # THE LAZY FIX: If naive assumption creates a logical paradox, cap PFS
    if(pfs > os) {
      pfs <- os 
    }
    
    time_in_PF <- pfs
    time_in_PD <- os - pfs
    
    # Calculate patient-level outcomes
    total_qalys[i] <- (time_in_PF * utility_PF) + (time_in_PD * utility_PD)
    total_costs[i] <- (time_in_PF * cost_PF_per_mo) + (time_in_PD * cost_PD_per_mo)
  }
  
  return(data.frame(
    Mean_QALYs = mean(total_qalys),
    Variance_QALYs = var(total_qalys),
    Mean_Costs = mean(total_costs),
    Mean_PFS_Realized = mean(data$pfs_time),
    Mean_PFS_After_Cap = mean(ifelse(data$pfs_time > data$os_time, data$os_time, data$pfs_time))
  ))
}

# =====================================================================
# 3. RUN AND COMPARE
# =====================================================================
results_correlated <- run_microsim(paired_data, is_naive = FALSE)
results_uncorrelated <- run_microsim(uncorrelated_data, is_naive = TRUE)

cat("--- CORRELATED MODEL (Your Method) ---\n")
print(results_correlated)

cat("\n--- UNCORRELATED MODEL (Naive Method) ---\n")
print(results_uncorrelated)

# Calculate the bias introduced by ignoring correlation
bias_pfs <- results_correlated$Mean_PFS_After_Cap - results_uncorrelated$Mean_PFS_After_Cap
cat("\nBias in Average PFS introduced by ignoring correlation:", bias_pfs, "months\n")

# =====================================================================
# 1. SETUP: Health Economics Parameters
# =====================================================================
utility_PF <- 0.85   
utility_PD <- 0.50   
cost_PF_per_mo <- 5000 
cost_PD_per_mo <- 8000 

# --- MODEL 1: THE CORRELATED REALITY ---
# This is the optimized output from your Simulated Annealing loop
paired_data <- result$data 

# --- MODEL 2: THE NAIVE ASSUMPTION ---
# Take the raw, original pseudo-data straight from the QP method.
# Because they were extracted independently, pairing them row-by-row 
# assumes zero inherent clinical correlation.
uncorrelated_data <- data.frame(
  pfs_time = pfs_df$pfs_time,
  pfs_status = pfs_df$pfs_status,
  os_time = os_df$os_time,
  os_status = os_df$os_status
)

# =====================================================================
# 2. RUN AND COMPARE
# (Using the same run_microsim function from the previous step)
# =====================================================================

results_correlated <- run_microsim(paired_data, is_naive = FALSE)
results_uncorrelated <- run_microsim(uncorrelated_data, is_naive = TRUE)

cat("--- CORRELATED MODEL (Your Optimization Engine) ---\n")
print(results_correlated)

cat("\n--- UNCORRELATED MODEL (Raw QP Pseudo-Data) ---\n")
print(results_uncorrelated)

# Calculate the precise bias in months
bias_pfs <- results_correlated$Mean_PFS_After_Cap - results_uncorrelated$Mean_PFS_After_Cap
cat("\nBias in Average PFS introduced by ignoring correlation:", bias_pfs, "months\n")

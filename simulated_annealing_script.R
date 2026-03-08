# Load required library
library(survival)

# =====================================================================
# 1. MOCK DATA GENERATION (The QP Marginals)
# In practice, you would generate these using the CIFresolve package 
# (or similar QP method) from your digitized Kaplan-Meier curves.
# =====================================================================
set.seed(42)
n_patients <- 200

# Generating dummy marginals that are logically consistent 
pfs_time <- rexp(n_patients, rate = 0.1)
os_time <- pfs_time + rexp(n_patients, rate = 0.05) # OS is strictly >= PFS
pfs_status <- sample(c(0, 1), n_patients, replace = TRUE, prob = c(0.2, 0.8))
os_status <- sample(c(0, 1), n_patients, replace = TRUE, prob = c(0.3, 0.7))

pfs_df <- data.frame(pfs_time = pfs_time, pfs_status = pfs_status)
os_df <- data.frame(os_time = os_time, os_status = os_status)


# =====================================================================
# 2. THE LOSS FUNCTION
# Calculates absolute distance between current C-index and target
# =====================================================================
calc_loss <- function(pfs_times, os_times, os_statuses, target_c) {
  # survival::concordance measures how well PFS time predicts OS time
  # accounting for right-censoring in the OS data.
  c_stat <- concordance(Surv(os_times, os_statuses) ~ pfs_times)$concordance
  return(abs(c_stat - target_c))
}


# =====================================================================
# 3. SIMULATED ANNEALING OPTIMIZATION ENGINE
# =====================================================================
optimize_pairing <- function(pfs_df, os_df, target_c, max_iter = 5000, init_temp = 0.1, cooling_rate = 0.995) {
  
  # Step A: Initialize with a guaranteed logical pairing
  # Sorting both by time gives the highest possible initial correlation 
  # while strictly maintaining the QP constraints.
  pfs_curr <- pfs_df[order(pfs_df$pfs_time), ]
  os_curr <- os_df[order(os_df$os_time), ]
  
  n <- nrow(pfs_curr)
  
  # Calculate baseline error
  curr_loss <- calc_loss(pfs_curr$pfs_time, os_curr$os_time, os_curr$os_status, target_c)
  
  best_os <- os_curr
  best_loss <- curr_loss
  temp <- init_temp
  
  cat("Initial Loss:", curr_loss, "\n")
  
  # Step B: The Optimization Loop
  for(i in 1:max_iter) {
    
    # 1. Propose a tiny change: randomly pick two patients and swap their OS data
    idx <- sample(1:n, 2)
    os_prop <- os_curr
    
    temp_row <- os_prop[idx[1], ]
    os_prop[idx[1], ] <- os_prop[idx[2], ]
    os_prop[idx[2], ] <- temp_row
    
    # 2. Hard Clinical Constraint Check
    # If the swap forces any patient to die before they progress, reject instantly!
    if(any(pfs_curr$pfs_time > os_prop$os_time)) {
      next 
    }
    
    # 3. Score the newly proposed dataset
    prop_loss <- calc_loss(pfs_curr$pfs_time, os_prop$os_time, os_prop$os_status, target_c)
    
    # 4. Simulated Annealing Acceptance Logic
    accept <- FALSE
    if(prop_loss < curr_loss) {
      accept <- TRUE # Always accept improvements
    } else {
      # Sometimes accept slightly worse states to escape local minimums
      prob_accept <- exp(-(prop_loss - curr_loss) / temp)
      if(runif(1) < prob_accept) {
        accept <- TRUE
      }
    }
    
    # 5. Update State
    if(accept) {
      os_curr <- os_prop
      curr_loss <- prop_loss
      
      # Keep track of the absolute best pairing we've ever seen
      if(curr_loss < best_loss) {
        best_loss <- curr_loss
        best_os <- os_curr
      }
    }
    
    # 6. Cool the temperature
    temp <- temp * cooling_rate
  }
  
  cat("Final Loss:", best_loss, "\n")
  
  # Bind the perfectly matched data together
  final_paired_data <- cbind(pfs_curr, best_os)
  return(list(data = final_paired_data, final_loss = best_loss))
}

# =====================================================================
# 4. RUN THE ALGORITHM
# Let's say your true IPD "Teacher" trial showed a C-index of 0.65
# =====================================================================
target_c_index <- 0.65

result <- optimize_pairing(
  pfs_df = pfs_df, 
  os_df = os_df, 
  target_c = target_c_index, 
  max_iter = 10000,     # The more iterations, the closer you get to target
  init_temp = 0.05,     # Keep temperature relatively low for C-index scale
  cooling_rate = 0.999
)

# View the first few rows of your newly correlated, clinically logical pseudo-IPD!
head(result$data)

# Verify the final correlation
final_c_stat <- concordance(Surv(result$data$os_time, result$data$os_status) ~ result$data$pfs_time)$concordance
cat("Final Simulated C-index:", final_c_stat, "\n")

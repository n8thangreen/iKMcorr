# iKMcorr: Correlated Pseudo-IPD Optimizer for Partitioned Survival Models

[![R](https://img.shields.io/badge/R-4.2+-blue.svg)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Correlated-Pseudo-IPD** is an R-based optimization engine designed for Health Technology Assessment (HTA) and advanced survival modeling. It generates perfectly paired, correlated individual patient data (pseudo-IPD) from independent Progression-Free Survival (PFS) and Overall Survival (OS) marginals extracted from published Kaplan-Meier curves.

## ⚠️ The Problem
When digitizing published survival curves (PFS and OS) using standard algorithms (like Guyot/iKM), the resulting datasets are completely independent. This creates two massive problems for multi-state models and microsimulations:
1. **Logical Contradictions:** Simulated patients may mathematically "die" in the OS dataset before they "progress" in the PFS dataset.
2. **Ignored Correlation:** In reality, time-to-progression is highly correlated with time-to-death. Ignoring this correlation artificially skews the time spent in the "Progressed Disease" state, heavily biasing Quality-Adjusted Life Years (QALYs) and cost-effectiveness estimates.

## 💡 The Solution
This pipeline solves the problem using a three-step hybrid approach:

1. **Extraction (Quadratic Programming):** We assume the baseline marginals are generated using the Quadratic Programming (QP) method (Titman, 2026) to guarantee the aggregate data is logically consistent (e.g., PFS at-risk $\le$ OS at-risk).
2. **Pairing (Simulated Annealing):** This package uses a custom stochastic optimization loop to pair PFS and OS patient rows. It enforces strict clinical logic (`PFS <= OS`) while dynamically matching a target rank correlation (Harrell's C-index) derived from external real-world data or true IPD.
3. **Validation (Microsimulation):** The paired data is run through a built-in health economic microsimulation to quantify the bias eliminated by accounting for correlation.

---

## ⚙️ Installation

*Note: This package relies on the `survival` package for C-index calculations. You will also need a method for generating your initial QP marginals (such as the `CIFresolve` package).*

```R
# Clone the repository and source the functions
git clone [https://github.com/yourusername/Correlated-Pseudo-IPD.git](https://github.com/yourusername/Correlated-Pseudo-IPD.git)

# Inside R:
source("R/optimize_pairing.R")
source("R/run_microsim.R")
library(survival)
```

---

## 🚀 Quick Start

### 1. Load your QP Marginals
Load the logically consistent, independent marginal datasets extracted from your published Kaplan-Meier curves.

```R
# pfs_df and os_df should contain 'time' and 'status' columns
head(pfs_df)
head(os_df)
```

### 2. Run the Simulated Annealing Optimizer
Feed the marginals and your target external correlation (C-index) into the engine. The algorithm will iteratively swap patient pairings to minimize the loss function.

```R
target_c_index <- 0.65

# Run the optimizer
optimized_results <- optimize_pairing(
  pfs_df = pfs_df, 
  os_df = os_df, 
  target_c = target_c_index, 
  max_iter = 10000, 
  init_temp = 0.05, 
  cooling_rate = 0.999
)

# Extract the correlated, clinically logical pseudo-IPD
paired_ipd <- optimized_results$data
```

### 3. Validate the Economic Impact
Run the provided microsimulation to compare your newly correlated data against the naive assumption (raw, uncorrelated marginals).

```R
# Uncorrelated baseline (raw QP data)
uncorrelated_ipd <- data.frame(
  pfs_time = pfs_df$time, pfs_status = pfs_df$status,
  os_time = os_df$time, os_status = os_df$status
)

# Run simulations
sim_correlated <- run_microsim(paired_ipd, is_naive = FALSE)
sim_naive <- run_microsim(uncorrelated_ipd, is_naive = TRUE)

# Compare QALYs, Costs, and PFS bias
print(sim_correlated)
print(sim_naive)
```

---

## 🧠 Methodology Deep Dive

### The Custom Loss Function
Standard rank correlation (Spearman's) fails on survival data due to right-censoring. This optimizer evaluates pairing fitness using **Harrell's Concordance Index (C-index)**, ensuring censored patients are handled correctly without introducing assumption bias. 

The loss function dynamically scores:
$$Loss = | \text{Simulated C-Index} - \text{Target C-Index} |$$

*Note: Any proposed pairing that results in a patient progressing after death (`PFS > OS`) is assigned an infinite penalty and instantly rejected.*

### Why Simulated Annealing?
Because the `PFS <= OS` constraint creates a highly non-linear, fragmented optimization landscape, standard gradient descent gets trapped in local minima. Simulated Annealing introduces controlled randomness, allowing the algorithm to temporarily accept "worse" correlations early in the run to escape local minima and find the globally optimal patient pairings.

---

## 📖 References
* Titman, A. C. (2026). "Using Quadratic Programming to Reconstruct Data From Published Survival and Competing Risks Analyses." *Statistics in Medicine*.
* Harrell, F. E., et al. (1982). "Evaluating the yield of medical tests." *JAMA*.

## 🤝 Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change. 

## 📝 License
[MIT](https://choosealicense.com/licenses/mit/)

#create paper-style analysis dataset
#treatment summaries
#Wilcoxon tests
#Figure 4 replication
# ============================================================
# 03_replication.R
# Replicate treatment-level results from the four-player
# linear public-goods experiment
# ============================================================

# This script assumes that 01_import.R and
# 02_derive_variables.R have been run first.

stopifnot(exists("group_round"))
stopifnot(nrow(group_round) == 3120)
group_session <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment + Session + GroupID,
  data = group_round,
  FUN = mean
)
dim(group_session)
head(group_session)
treatment_mean <-aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = mean
)
head(treatment_mean)

treatment_median <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = median
)
treatment_sd <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = sd
)
treatment_iqr <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = IQR
)
identical(
  treatment_mean$Treatment,
  treatment_median$Treatment
)

identical(
  treatment_mean$Treatment,
  treatment_sd$Treatment
)

identical(
  treatment_mean$Treatment,
  treatment_iqr$Treatment
)
treatment_summary <- data.frame(
  Treatment = treatment_mean$Treatment,
  
  MeanContribution =
    treatment_mean$GroupRelativeContribution,
  
  MedianContribution =
    treatment_median$GroupRelativeContribution,
  
  SDContribution =
    treatment_sd$GroupRelativeContribution,
  
  IQRContribution =
    treatment_iqr$GroupRelativeContribution,
  
  MeanSurplus =
    treatment_mean$Surplus,
  
  MedianSurplus =
    treatment_median$Surplus,
  
  SDSurplus =
    treatment_sd$Surplus,
  
  IQRSurplus =
    treatment_iqr$Surplus
)
treatment_summary


# ============================================================
# Method Choice Audit
# Why might the paper use Wilcoxon rank-sum tests?
# ============================================================


# ------------------------------------------------------------
# A. Are the outcomes bounded?
# ------------------------------------------------------------

# GroupRelativeContribution is theoretically bounded between 0 and 1.

range(group_session$GroupRelativeContribution)

# Surplus is also bounded in this experimental design.
# Its theoretical maximum differs across treatments because
# productivity-endowment alignment differs across FE, AI, and MI.

aggregate(
  Surplus ~ Treatment,
  data = group_session,
  FUN = range
)

# Interpretation:
# GroupRelativeContribution is bounded in [0, 1].
# Surplus is also bounded, and its feasible upper bound differs by treatment.
# This makes a normal-distribution approximation less natural,
# although boundedness alone does not require using Wilcoxon.


# ------------------------------------------------------------
# B. Are the distributions skewed?
# ------------------------------------------------------------

boxplot(
  GroupRelativeContribution ~ Treatment,
  data = group_session,
  main = "Group Relative Contribution by Treatment"
)

boxplot(
  Surplus ~ Treatment,
  data = group_session,
  main = "Surplus by Treatment"
)

aggregate(
  GroupRelativeContribution ~ Treatment,
  data = group_session,
  FUN = quantile
)

aggregate(
  Surplus ~ Treatment,
  data = group_session,
  FUN = quantile
)

# Interpretation:
# AI GroupRelativeContribution shows some evidence of left-skewness:
# its median is above its mean and the lower half of the distribution
# is more spread out than the upper half.
#
# FE and MI contributions appear less strongly skewed.
# Surplus distributions also show some asymmetry.
#
# Therefore, skewness provides some support for using a rank-based
# nonparametric test, but it is not by itself proof that Wilcoxon is required.


# ------------------------------------------------------------
# C. Are there extreme values / boxplot-defined outliers?
# ------------------------------------------------------------

boxplot.stats(
  group_session$GroupRelativeContribution[
    group_session$Treatment == "AI"
  ]
)$out

boxplot.stats(
  group_session$GroupRelativeContribution[
    group_session$Treatment == "FE"
  ]
)$out

boxplot.stats(
  group_session$GroupRelativeContribution[
    group_session$Treatment == "MI"
  ]
)$out


boxplot.stats(
  group_session$Surplus[
    group_session$Treatment == "AI"
  ]
)$out

boxplot.stats(
  group_session$Surplus[
    group_session$Treatment == "FE"
  ]
)$out

boxplot.stats(
  group_session$Surplus[
    group_session$Treatment == "MI"
  ]
)$out

# Interpretation:
# numeric(0) means no observations are classified as outliers
# under the standard Tukey boxplot rule (1.5 * IQR).
#
# Based on the current contribution data, no treatment shows
# boxplot-defined outliers.
#
# If the same is true for Surplus, then extreme values are not
# a strong explanation for choosing Wilcoxon.


# ------------------------------------------------------------
# D. Is the independent-group sample size small?
# ------------------------------------------------------------

table(group_session$Treatment)

# Expected approximately:
# AI = 52
# FE = 50
# MI = 54

# Interpretation:
# The independent statistical unit is the interacting group-session,
# not the 12,480 player-round observations.
#
# Each treatment therefore has about 50 independent group-session units.
# This is better described as a moderate sample size rather than
# an extremely small sample.
#
# A moderate sample size can make a nonparametric test attractive,
# especially with bounded or asymmetric outcomes, but sample size alone
# does not explain the choice of Wilcoxon.


# ------------------------------------------------------------
# E. Are dispersions / variances different across treatments?
# ------------------------------------------------------------

treatment_sd <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = sd
)

treatment_iqr <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = IQR
)

treatment_sd
treatment_iqr

# Interpretation:
# Contribution SDs are fairly similar across treatments.
# Surplus dispersion differs more clearly, especially because
# MI has a smaller SD and IQR than AI and FE.
#
# Unequal variance alone is not a strong reason to prefer Wilcoxon,
# because Welch's t-test directly allows unequal variances.
#
# Therefore, "the authors used Wilcoxon because SDs were unequal"
# is not strongly supported by these descriptive results.


# ============================================================
# Robustness check:
# Welch's t-test versus Wilcoxon rank-sum
# ============================================================


# ------------------------------------------------------------
# GroupRelativeContribution
# ------------------------------------------------------------

# AI vs FE

t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  var.equal = FALSE
)

wilcox.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  exact = FALSE
)


# MI vs FE

t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  var.equal = FALSE
)

wilcox.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  exact = FALSE
)


# AI vs MI

t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  var.equal = FALSE
)

wilcox.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  exact = FALSE
)


# ------------------------------------------------------------
# Surplus
# ------------------------------------------------------------

# AI vs FE

t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  var.equal = FALSE
)

wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  exact = FALSE
)


# MI vs FE

t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  var.equal = FALSE
)

wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  exact = FALSE
)


# AI vs MI

t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  var.equal = FALSE
)

wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  exact = FALSE
)
# ------------------------------------------------------------
# Method Choice Audit: preliminary conclusion
# ------------------------------------------------------------

# A. Bounded outcomes:
# Supported.
#
# B. Skewness:
# Partially supported, especially for AI relative contribution.
#
# C. Extreme values / outliers:
# Not strongly supported if boxplot.stats() returns numeric(0).
#
# D. Small sample size:
# Only partially supported. Independent group-level sample sizes are
# moderate (~50 per treatment), not extremely small.
#
# E. Unequal dispersion:
# Some evidence exists, especially for Surplus, but unequal variance
# alone would not require Wilcoxon because Welch's t-test can handle it.
#
# Overall:
# The data provide some methodological reasons why a rank-based
# nonparametric test is reasonable, especially boundedness and
# distributional asymmetry.
#
# However, the main paper does not establish whether Wilcoxon was
# pre-specified or selected after inspecting the data.
#
# Comparing Welch's t-test and Wilcoxon should therefore be treated
# as a robustness / method-sensitivity analysis, not as evidence
# about the authors' motives.
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
stopifnot(nrow(group_session) == 156)

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
# Is the use of Wilcoxon rank-sum tests methodologically reasonable?
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
# Bounded outcomes may generate asymmetric distributions or
# ceiling/floor constraints, so distributional shape should be inspected.
# Boundedness alone does not require using Wilcoxon.


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
# No boxplot-defined outliers are detected for either
# GroupRelativeContribution or Surplus in any treatment,
# using the standard Tukey 1.5 * IQR rule.
#
# Therefore, extreme values are not supported as a strong explanation
# for preferring Wilcoxon in these outcomes.


# ------------------------------------------------------------
# D. Is the independent-group sample size small?
# ------------------------------------------------------------

table(group_session$Treatment)



# The paper treats interacting groups as the statistical units,
# rather than the 12,480 player-round observations.
#
# Each treatment contains about 50 group-session statistical units.
# Because participants take part in two sessions with different partners,
# strict independence across all group-session observations should not
# be assumed without further justification.


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

welch_contribution_ai_fe <- t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  var.equal = FALSE
)

wilcox_contribution_ai_fe <- wilcox.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  exact = FALSE
)


# MI vs FE

welch_contribution_mi_fe <- t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  var.equal = FALSE
)

wilcox_contribution_mi_fe <- wilcox.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  exact = FALSE
)


# AI vs MI

welch_contribution_ai_mi <- t.test(
  GroupRelativeContribution ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  var.equal = FALSE
)

wilcox_contribution_ai_mi <- wilcox.test(
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

welch_surplus_ai_fe <- t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  var.equal = FALSE
)

wilcox_surplus_ai_fe <- wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "FE")
  ),
  exact = FALSE
)


# MI vs FE

welch_surplus_mi_fe <- t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  var.equal = FALSE
)

wilcox_surplus_mi_fe <- wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("MI", "FE")
  ),
  exact = FALSE
)


# AI vs MI

welch_surplus_ai_mi <- t.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  var.equal = FALSE
)

wilcox_surplus_ai_mi <- wilcox.test(
  Surplus ~ Treatment,
  data = subset(
    group_session,
    Treatment %in% c("AI", "MI")
  ),
  exact = FALSE
)


# ------------------------------------------------------------
# Extract p-values for comparison
# ------------------------------------------------------------

robustness_summary <- data.frame(
  Outcome = c(
    "Contribution",
    "Contribution",
    "Contribution",
    "Surplus",
    "Surplus",
    "Surplus"
  ),
  Comparison = c(
    "AI vs FE",
    "MI vs FE",
    "AI vs MI",
    "AI vs FE",
    "MI vs FE",
    "AI vs MI"
  ),
  Welch_p = c(
    welch_contribution_ai_fe$p.value,
    welch_contribution_mi_fe$p.value,
    welch_contribution_ai_mi$p.value,
    welch_surplus_ai_fe$p.value,
    welch_surplus_mi_fe$p.value,
    welch_surplus_ai_mi$p.value
  ),
  Wilcoxon_p = c(
    wilcox_contribution_ai_fe$p.value,
    wilcox_contribution_mi_fe$p.value,
    wilcox_contribution_ai_mi$p.value,
    wilcox_surplus_ai_fe$p.value,
    wilcox_surplus_mi_fe$p.value,
    wilcox_surplus_ai_mi$p.value
  )
)

robustness_summary
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
# Not supported for these outcomes under the Tukey 1.5 * IQR rule.
#
# D. Small sample size:
# Not strongly supported. There are about 50 group-session statistical
# units per treatment, which is a moderate sample size.
# Strict independence across all group-session observations is not assumed.
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

# ============================================================
# Figure 4A and 4C replication
# ============================================================

library(ggplot2)

stopifnot(exists("group_round"))
stopifnot(nrow(group_round) == 3120)

stopifnot(nrow(group_session) == 156)

group_session$Treatment <- factor(
  group_session$Treatment,
  levels = c("FE", "AI", "MI")
)

figure_mean <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = mean
)

names(figure_mean)[
  names(figure_mean) == "GroupRelativeContribution"
] <- "MeanContribution"

names(figure_mean)[
  names(figure_mean) == "Surplus"
] <- "MeanSurplus"

figure_sd <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  ) ~ Treatment,
  data = group_session,
  FUN = sd
)

names(figure_sd)[
  names(figure_sd) == "GroupRelativeContribution"
] <- "SDContribution"

names(figure_sd)[
  names(figure_sd) == "Surplus"
] <- "SDSurplus"

figure_n <- aggregate(
  GroupID ~ Treatment,
  data = group_session,
  FUN = length
)

names(figure_n)[
  names(figure_n) == "GroupID"
] <- "N"

stopifnot(
  identical(
    as.character(figure_mean$Treatment),
    as.character(figure_sd$Treatment)
  )
)

stopifnot(
  identical(
    as.character(figure_mean$Treatment),
    as.character(figure_n$Treatment)
  )
)

figure_summary <- data.frame(
  Treatment = figure_mean$Treatment,
  MeanContribution = figure_mean$MeanContribution,
  SDContribution = figure_sd$SDContribution,
  MeanSurplus = figure_mean$MeanSurplus,
  SDSurplus = figure_sd$SDSurplus,
  N = figure_n$N
)

figure_summary$SEContribution <-
  figure_summary$SDContribution /
  sqrt(figure_summary$N)

figure_summary$SESurplus <-
  figure_summary$SDSurplus /
  sqrt(figure_summary$N)

figure_summary$TCritical <-
  qt(
    0.975,
    df = figure_summary$N - 1
  )

figure_summary$ContributionCILower <-
  figure_summary$MeanContribution -
  figure_summary$TCritical *
  figure_summary$SEContribution

figure_summary$ContributionCIUpper <-
  figure_summary$MeanContribution +
  figure_summary$TCritical *
  figure_summary$SEContribution

figure_summary$SurplusCILower <-
  figure_summary$MeanSurplus -
  figure_summary$TCritical *
  figure_summary$SESurplus

figure_summary$SurplusCIUpper <-
  figure_summary$MeanSurplus +
  figure_summary$TCritical *
  figure_summary$SESurplus

figure_summary

figure_4a <- ggplot(
  group_session,
  aes(
    x = Treatment,
    y = GroupRelativeContribution,
    color = Treatment
  )
) +
  geom_jitter(
    width = 0.12,
    height = 0,
    size = 1.6,
    alpha = 0.65
  ) +
  geom_col(
    data = figure_summary,
    aes(
      x = Treatment,
      y = MeanContribution,
      color = Treatment
    ),
    inherit.aes = FALSE,
    fill = NA,
    width = 0.5,
    linewidth = 1
  ) +
  geom_errorbar(
    data = figure_summary,
    aes(
      x = Treatment,
      ymin = ContributionCILower,
      ymax = ContributionCIUpper
    ),
    inherit.aes = FALSE,
    width = 0.16,
    linewidth = 0.8,
    color = "black"
  ) +
  scale_x_discrete(
    labels = c(
      FE = "Full\nequality",
      AI = "Aligned\ninequality",
      MI = "Misaligned\ninequality"
    )
  ) +
  coord_cartesian(
    ylim = c(0, 1.05)
  ) +
  labs(
    title = "Average contributions",
    x = NULL,
    y = "Group relative contributions"
  ) +
  guides(
    color = "none"
  ) +
  theme_classic()

figure_4a

figure_4c <- ggplot(
  group_session,
  aes(
    x = Treatment,
    y = Surplus,
    color = Treatment
  )
) +
  geom_jitter(
    width = 0.12,
    height = 0,
    size = 1.6,
    alpha = 0.65
  ) +
  geom_col(
    data = figure_summary,
    aes(
      x = Treatment,
      y = MeanSurplus,
      color = Treatment
    ),
    inherit.aes = FALSE,
    fill = NA,
    width = 0.5,
    linewidth = 1
  ) +
  geom_errorbar(
    data = figure_summary,
    aes(
      x = Treatment,
      ymin = SurplusCILower,
      ymax = SurplusCIUpper
    ),
    inherit.aes = FALSE,
    width = 0.16,
    linewidth = 0.8,
    color = "black"
  ) +
  scale_x_discrete(
    labels = c(
      FE = "Full\nequality",
      AI = "Aligned\ninequality",
      MI = "Misaligned\ninequality"
    )
  ) +
  coord_cartesian(
    ylim = c(0, 2.6)
  ) +
  labs(
    title = "Overall surplus",
    x = NULL,
    y = "Surplus"
  ) +
  guides(
    color = "none"
  ) +
  theme_classic()

figure_4c

ggsave(
  "figures/figure_4a_replication.png",
  figure_4a,
  width = 5,
  height = 5,
  dpi = 300
)

ggsave(
  "figures/figure_4c_replication.png",
  figure_4c,
  width = 5,
  height = 5,
  dpi = 300
)

# ============================================================
# Figure 4B replication
# ============================================================
round_summary <- aggregate(
  cbind(
    GroupRelativeContribution,
    Surplus
  )  ~ Treatment + Round,
  data = group_round,
  FUN = mean
)

dim(round_summary)
head(round_summary)
figure_4b <- ggplot(
  round_summary,
  aes(
    x = Round,
    y = GroupRelativeContribution,
    color = Treatment,
    group = Treatment
  )
) +
  geom_line() +
  geom_point() +
  scale_x_continuous(
    breaks = c(1, 5, 10, 15, 20)
  ) +
  labs(
    title = "Contributions across time",
    x = "Round",
    y = "Group relative contributions"
  ) +
  theme_classic()

figure_4b

figure_4b_surplus <- ggplot(
  round_summary,
  aes(
    x = Round,
    y = Surplus,
    color = Treatment,
    group = Treatment
  )
) +
  geom_line() +
  geom_point() +
  labs(
    title = "surplus across time",
    x = "Round",
    y = "Surplus"
  ) +
  theme_classic()

figure_4b_surplus
# ------------------------------------------------------------
# Construct individual monetary payoff
# ------------------------------------------------------------

# Linear-game payoff:
# pi_i = e_i - c_i + C / 4
#
# where C is the group effective contribution in the same
# treatment-session-group-round context.


# ------------------------------------------------------------
# Pre-join validation
# ------------------------------------------------------------

group_round_key <- group_round[
  ,
  c(
    "Treatment",
    "Session",
    "GroupID",
    "Round"
  )
]

stopifnot(
  !any(duplicated(group_round_key))
)

rows_before_join <- nrow(pgg_analysis)


# ------------------------------------------------------------
# Join group-round effective contribution to player-round data
# ------------------------------------------------------------

player_round_payoff <- merge(
  pgg_analysis,
  group_round[
    ,
    c(
      "Treatment",
      "Session",
      "GroupID",
      "Round",
      "GroupEffectiveContribution"
    )
  ],
  by = c(
    "Treatment",
    "Session",
    "GroupID",
    "Round"
  ),
  all.x = TRUE
)


# ------------------------------------------------------------
# Post-join validation
# ------------------------------------------------------------

rows_after_join <- nrow(player_round_payoff)

stopifnot(
  rows_after_join == rows_before_join
)

stopifnot(
  sum(
    is.na(
      player_round_payoff$GroupEffectiveContribution
    )
  ) == 0
)


# ------------------------------------------------------------
# Construct reward and monetary payoff
# ------------------------------------------------------------

player_round_payoff$Reward <-
  player_round_payoff$GroupEffectiveContribution / 4

player_round_payoff$Payoff <-
  player_round_payoff$Endowment -
  player_round_payoff$Contribution +
  player_round_payoff$Reward

summary(player_round_payoff$Payoff)
range(player_round_payoff$Payoff)

# Gini coefficient:
# G = sum_i sum_j |x_i - x_j| / (2 * n^2 * mean(x))
#
# Here x_i is the monetary payoff of player i within a
# four-player group-round.

gini_coefficient <- function(x) {
  n <- length(x)
  mean_x <- mean(x)
  
  stopifnot(n == 4)
  stopifnot(mean_x > 0)
  
  sum(abs(outer(x, x, "-"))) /
    (2 * n^2 * mean_x)
}

# Perfect equality sanity check
stopifnot(
  gini_coefficient(c(10, 10, 10, 10)) == 0
)
# ------------------------------------------------------------
# Compute group-round payoff inequality
# ------------------------------------------------------------

group_round_gini <- aggregate(
  Payoff ~ Treatment + Session + GroupID + Round,
  data = player_round_payoff,
  FUN = gini_coefficient
)

names(group_round_gini)[
  names(group_round_gini) == "Payoff"
] <- "Gini"

dim(group_round_gini)

range(group_round_gini$Gini)

summary(group_round_gini$Gini)

sum(is.na(group_round_gini$Gini))

# ------------------------------------------------------------
# Average payoff inequality over 20 rounds
# ------------------------------------------------------------

group_session_gini <- aggregate(
  Gini ~ Treatment + Session + GroupID,
  data = group_round_gini,
  FUN = mean
)

stopifnot(
  nrow(group_session_gini) == 156
)

head(group_session_gini)

# ------------------------------------------------------------
# Treatment-level payoff inequality summary
# ------------------------------------------------------------

gini_mean <- aggregate(
  Gini ~ Treatment,
  data = group_session_gini,
  FUN = mean
)

gini_sd <- aggregate(
  Gini ~ Treatment,
  data = group_session_gini,
  FUN = sd
)

gini_n <- aggregate(
  GroupID ~ Treatment,
  data = group_session_gini,
  FUN = length
)

names(gini_mean)[
  names(gini_mean) == "Gini"
] <- "MeanGini"

names(gini_sd)[
  names(gini_sd) == "Gini"
] <- "SDGini"

names(gini_n)[
  names(gini_n) == "GroupID"
] <- "N"

stopifnot(
  identical(
    gini_mean$Treatment,
    gini_sd$Treatment
  )
)

stopifnot(
  identical(
    gini_mean$Treatment,
    gini_n$Treatment
  )
)

gini_summary <- data.frame(
  Treatment = gini_mean$Treatment,
  MeanGini = gini_mean$MeanGini,
  SDGini = gini_sd$SDGini,
  N = gini_n$N
)

gini_summary$SEGini <-
  gini_summary$SDGini /
  sqrt(gini_summary$N)

gini_summary$TCritical <-
  qt(
    0.975,
    df = gini_summary$N - 1
  )


gini_summary$GiniCILower <-
  gini_summary$MeanGini -
  gini_summary$TCritical *
  gini_summary$SEGini

gini_summary$GiniCIUpper <-
  gini_summary$MeanGini +
  gini_summary$TCritical *
  gini_summary$SEGini

gini_summary

group_session_gini$Treatment <- factor(
  group_session_gini$Treatment,
  levels = c("FE", "AI", "MI")
)

gini_summary$Treatment <- factor(
  gini_summary$Treatment,
  levels = c("FE", "AI", "MI")
)

figure_4d <- ggplot(
  group_session_gini,
  aes(
    x = Treatment,
    y = Gini,
    color = Treatment
  )
) +
  geom_jitter(
    width = 0.12,
    height = 0,
    size = 1.6,
    alpha = 0.65
  ) +
  geom_col(
    data = gini_summary,
    aes(
      x = Treatment,
      y = MeanGini,
      color = Treatment
    ),
    inherit.aes = FALSE,
    fill = NA,
    width = 0.5,
    linewidth = 1
  ) +
  geom_errorbar(
    data = gini_summary,
    aes(
      x = Treatment,
      ymin = GiniCILower,
      ymax = GiniCIUpper
    ),
    inherit.aes = FALSE,
    width = 0.16,
    linewidth = 0.8,
    color = "black"
  ) +
  scale_x_discrete(
    labels = c(
      FE = "Full\nequality",
      AI = "Aligned\ninequality",
      MI = "Misaligned\ninequality"
    )
  ) +
  labs(
    title = "Payoff inequality",
    x = NULL,
    y = "Gini coefficient"
  ) +
  guides(
    color = "none"
  ) +
  theme_classic()

figure_4d

ggsave(
  "figures/figure_4d_replication.png",
  figure_4d,
  width = 5,
  height = 5,
  dpi = 300
)
ggsave(
  "figures/figure_4b_replication.png",
  figure_4b,
  width = 5,
  height = 5,
  dpi = 300
)
ggsave(
  "figures/figure_4b_surplus_extension.png",
  figure_4b_surplus,
  width = 5,
  height = 5,
  dpi = 300
)
# ============================================================
# 02_derive_variables.R
# Create analysis variables for the four-player linear PGG data
# ============================================================
#construct player-round / group-round variables

# This script assumes that 01_import.R has been run first.

stopifnot(exists("pgg_analysis"))
stopifnot(nrow(pgg_analysis) == 12480)
stopifnot(ncol(pgg_analysis) == 7)
pgg_analysis$Endowment <- ifelse(
  pgg_analysis$Treatment == "FE",
  24,
  ifelse(
    pgg_analysis$PlayerID %in% c(1, 2),
    36,
    12
  )
)
table(
  pgg_analysis$Treatment,
  pgg_analysis$Endowment
)
sum(
  pgg_analysis$Contribution >
    pgg_analysis$Endowment
)
pgg_analysis$Productivity <- ifelse(
  pgg_analysis$Treatment =="FE",
  1.6,
  ifelse(
    pgg_analysis$Treatment =="AI",
    ifelse(
      pgg_analysis$PlayerID %in% c(1, 2),
      1.9,
      1.3
    ),
    ifelse(
      pgg_analysis$PlayerID %in% c(1, 2),
      1.3,
      1.9
    )
  )
)
table(pgg_analysis$Treatment,
      pgg_analysis$Productivity)
unique(pgg_analysis[ ,c("Treatment","Productivity","Endowment","PlayerID")
                    ])
pgg_analysis$RelativeContribution <-
  pgg_analysis$Contribution / pgg_analysis$Endowment
range(pgg_analysis$RelativeContribution)
summary(pgg_analysis$RelativeContribution)


pgg_analysis$EffectiveContribution <-
  pgg_analysis$Productivity * pgg_analysis$Contribution

range(pgg_analysis$EffectiveContribution)
summary(pgg_analysis$EffectiveContribution)

group_round <- aggregate(
  cbind(
    Contribution,
    Endowment,
    EffectiveContribution
  ) ~ Treatment + Session + GroupID + Round,
  data = pgg_analysis,
  FUN = sum
)
names(group_round)[
  names(group_round) == "Contribution"
] <- "GroupContribution"

names(group_round)[
  names(group_round) == "Endowment"
] <- "GroupEndowment"

names(group_round)[
  names(group_round) == "EffectiveContribution"
] <- "GroupEffectiveContribution"

group_round$GroupRelativeContribution <-
  group_round$GroupContribution /
  group_round$GroupEndowment

dim(group_round)

unique(group_round$GroupEndowment)

range(group_round$GroupRelativeContribution)

###surplus
group_round$Surplus <-
  (
    group_round$GroupEffectiveContribution -
      group_round$GroupContribution
  ) /
  group_round$GroupEndowment

range(group_round$Surplus)
summary(group_round$Surplus)
sum(is.na(group_round$Surplus))
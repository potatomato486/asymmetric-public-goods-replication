# ============================================================
# 01_import.R
# Import and validate the four-player linear PGG data
# ============================================================


# ------------------------------------------------------------
# 1. Import raw data
# ------------------------------------------------------------

pgg_raw <- read.csv("data/LinearPGG_4P_ExperimentalData.csv")


# ------------------------------------------------------------
# 2. Basic structure audit
# ------------------------------------------------------------

dim(pgg_raw)
names(pgg_raw)
str(pgg_raw)
summary(pgg_raw)

# Raw data should contain exactly 7 variables
stopifnot(nrow(pgg_raw) == 12480)
stopifnot(ncol(pgg_raw) == 7)

stopifnot(
  setequal(
    names(pgg_raw),
    c(
      "Treatment",
      "Session",
      "GroupID",
      "PlayerID",
      "GlobalPlayerID",
      "Round",
      "Contribution"
    )
  )
)


# Inspect key variable values
unique(pgg_raw$Treatment)
unique(pgg_raw$Session)
unique(pgg_raw$PlayerID)

range(pgg_raw$Round)
table(pgg_raw$Round)

length(unique(pgg_raw$GroupID))
length(unique(pgg_raw$GlobalPlayerID))


# ------------------------------------------------------------
# 3. Missingness audit
# ------------------------------------------------------------

colSums(is.na(pgg_raw))

# Expected:
# no missing values in any raw variable


# ------------------------------------------------------------
# 4. Round completeness audit
# ------------------------------------------------------------

round_check <- aggregate(
  Round ~ Treatment + Session + GroupID + PlayerID,
  data = pgg_raw,
  FUN = length
)

unique_round_check <- aggregate(
  Round ~ Treatment + Session + GroupID + PlayerID,
  data = pgg_raw,
  FUN = function(x) length(unique(x))
)

complete_round_check <- aggregate(
  Round ~ Treatment + Session + GroupID + PlayerID,
  data = pgg_raw,
  FUN = function(x) setequal(x, 1:20)
)

table(round_check$Round)
table(unique_round_check$Round)
table(complete_round_check$Round)

# Expected:
# 20   -> 624
# 20   -> 624
# TRUE -> 624


# ------------------------------------------------------------
# 5. Duplicate observation-key audit
# ------------------------------------------------------------

# Unit of observation:
# one player × one round contribution decision

observation_key <- pgg_raw[
  ,
  c(
    "Treatment",
    "Session",
    "GroupID",
    "PlayerID",
    "Round"
  )
]

sum(duplicated(observation_key))

# Expected:
# 0


# ------------------------------------------------------------
# 6. Group ID scope audit
# ------------------------------------------------------------

group_contexts <- unique(
  pgg_raw[
    ,
    c(
      "Treatment",
      "Session",
      "GroupID"
    )
  ]
)

nrow(group_contexts)

any(duplicated(group_contexts$GroupID))

any(
  duplicated(
    group_contexts[
      ,
      c("Treatment", "GroupID")
    ]
  )
)

# Validation note:
# GroupID is not globally unique in the raw data.
# The same GroupID value can appear across treatments.
# Therefore, group contexts are identified using
# Treatment + Session + GroupID in subsequent analyses.


# ------------------------------------------------------------
# 7. Group size audit
# ------------------------------------------------------------

group_size_check <- aggregate(
  PlayerID ~ Treatment + Session + GroupID,
  data = pgg_raw,
  FUN = function(x) length(unique(x))
)

table(group_size_check$PlayerID)

# Expected:
# 4 -> 156


# ------------------------------------------------------------
# 8. Player roster audit
# ------------------------------------------------------------

player_roster_check <- aggregate(
  PlayerID ~ Treatment + Session + GroupID,
  data = pgg_raw,
  FUN = function(x) setequal(x, 1:4)
)

table(player_roster_check$PlayerID)

# Expected:
# TRUE -> 156


# ------------------------------------------------------------

participant_session_ids <- unique(
  pgg_raw[
    ,
    c(
      "Treatment",
      "GlobalPlayerID"
    )
  ]
)

nrow(participant_session_ids)


global_id_context <- unique(
  pgg_raw[
    ,
    c(
      "Treatment",
      "GlobalPlayerID",
      "Session",
      "GroupID",
      "PlayerID"
    )
  ]
)

nrow(global_id_context)

any(
  duplicated(
    global_id_context[
      ,
      c(
        "Treatment",
        "GlobalPlayerID"
      )
    ]
  )
)


# ------------------------------------------------------------

table(
  pgg_raw$Treatment,
  pgg_raw$Session
)



table(
  group_contexts$Treatment,
  group_contexts$Session
)

# ------------------------------------------------------------

range(pgg_raw$Contribution)

sum(pgg_raw$Contribution < 0)


contribution_max <- aggregate(
  Contribution ~ Treatment + PlayerID,
  data = pgg_raw,
  FUN = max
)

contribution_max


expected_endowment_check <- ifelse(
  pgg_raw$Treatment == "FE",
  24,
  ifelse(
    pgg_raw$PlayerID %in% c(1, 2),
    36,
    12
  )
)

sum(
  pgg_raw$Contribution >
    expected_endowment_check
)

# ------------------------------------------------------------
# 12. Final raw-data integrity check
# ------------------------------------------------------------

dim(pgg_raw)
names(pgg_raw)

stopifnot(nrow(pgg_raw) == 12480)
stopifnot(ncol(pgg_raw) == 7)

pgg_analysis <- pgg_raw

dim(pgg_analysis)

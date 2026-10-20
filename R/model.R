library(tidyverse)
library(xgboost)

# The seven inputs (PREREG.md section 3). No pitch type, count or location
INPUTS <- c("release_speed", "ivb", "hb", "release_ht", "release_side",
            "velo_gap", "same_side")

# Fixed before fitting (section 4). Nothing here is tuned
PARAMS <- list(objective = "reg:squarederror", max_depth = 4, learning_rate = 0.05,
               min_child_weight = 100, subsample = 0.8, colsample_bytree = 1.0)
N_ROUNDS <- 400

# Changeup fallback inputs (PREREG 7a, amendment 6). Never used unless gate 3
# fails with CH among the misses
INPUTS_CH <- c(INPUTS, "ivb_gap", "hb_gap")

# A dense matrix keeps memory flat on 2M+ rows. NA in velo_gap stays NA,
# which XGBoost sends down a learned default branch
to_matrix <- function(df, inputs = INPUTS) as.matrix(df[, inputs])

fit_model <- function(train, depth = PARAMS$max_depth, inputs = INPUTS) {
  set.seed(3)
  dtrain <- xgb.DMatrix(to_matrix(train, inputs), label = train$rv)
  xgb.train(params = modifyList(PARAMS, list(max_depth = depth)),
            data = dtrain, nrounds = N_ROUNDS, verbose = 0)
}

# Every pitch scored as if thrown to a same-side and an opposite-side hitter.
# The overall grade is the 50/50 average, so it does not reward the hitters a
# pitcher happened to face (section 5)
score_both_sides <- function(model, df, inputs = INPUTS) {
  same <- df |> mutate(same_side = 1L)
  opp  <- df |> mutate(same_side = 0L)
  df |>
    mutate(pred_same = predict(model, xgb.DMatrix(to_matrix(same, inputs))),
           pred_opp  = predict(model, xgb.DMatrix(to_matrix(opp, inputs))),
           pred      = (pred_same + pred_opp) / 2)
}

# Three family models (v2 experiment 3b). The Statcast label only ROUTES a
# pitch to its family's model; inside each model it is still shape only. Each
# family learns its own rules, e.g. low spin good for offspeed, high for FB
FAMILY_OF <- function(pitch_type) case_when(
  pitch_type %in% c("FF", "SI", "FC")             ~ "FB",
  pitch_type %in% c("SL", "ST", "SV", "CU", "KC") ~ "BB",
  TRUE                                            ~ "OS")

fit_family <- function(train, inputs) {
  split(train, FAMILY_OF(train$pitch_type)) |> map(\(d) fit_model(d, inputs = inputs))
}

score_family <- function(models, df, inputs) {
  df |> mutate(.fam = FAMILY_OF(pitch_type)) |>
    group_split(.fam) |>
    map(\(d) score_both_sides(models[[d$.fam[1]]], d, inputs)) |>
    list_rbind() |> select(-.fam)
}

# ---- v2: the whiff model ------------------------------------------------------
# Trained on SWINGS only: given that the hitter swung, did this shape miss the
# bat? Label 1 = whiff, 0 = contact. The output is a probability, so the
# objective is logistic. Same inputs and settings as v1. Note min_child_weight
# now counts p(1 - p) per pitch (~0.2), so 100 means roughly 500 swings a leaf
SWING_DESC <- c("swinging_strike", "swinging_strike_blocked", "foul_tip", "foul", "hit_into_play")
WHIFF_DESC_ <- c("swinging_strike", "swinging_strike_blocked", "foul_tip")

fit_whiff <- function(train, inputs = INPUTS) {
  set.seed(3)
  sw <- train |> filter(description %in% SWING_DESC)
  dtrain <- xgb.DMatrix(to_matrix(sw, inputs), label = as.integer(sw$description %in% WHIFF_DESC_))
  xgb.train(params = modifyList(PARAMS, list(objective = "binary:logistic")),
            data = dtrain, nrounds = N_ROUNDS, verbose = 0)
}

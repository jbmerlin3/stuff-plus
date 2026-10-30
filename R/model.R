# model.R
# XGBoost fits and scoring. Settings are fixed in advance; nothing here is tuned.

library(tidyverse)
library(xgboost)

# ---- Inputs and settings ----
# No pitch type, count or location. v2 adds axis_diff to these.
INPUTS <- c("release_speed", "ivb", "hb", "release_ht", "release_side",
            "velo_gap", "same_side")

PARAMS <- list(objective = "reg:squarederror", max_depth = 4, learning_rate = 0.05,
               min_child_weight = 100, subsample = 0.8, colsample_bytree = 1.0)
N_ROUNDS <- 400

# v1's pre-registered changeup fallback; it never ran
INPUTS_CH <- c(INPUTS, "ivb_gap", "hb_gap")

to_matrix <- function(df, inputs = INPUTS) as.matrix(df[, inputs])

# ---- v1: run-value target ----
fit_model <- function(train, depth = PARAMS$max_depth, inputs = INPUTS) {
  set.seed(3)
  dtrain <- xgb.DMatrix(to_matrix(train, inputs), label = train$rv)
  xgb.train(params = modifyList(PARAMS, list(max_depth = depth)),
            data = dtrain, nrounds = N_ROUNDS, verbose = 0)
}

# Every pitch scored against a same-side and an opposite-side hitter. The overall
# grade is the 50/50 average, so it doesn't reward the hitters a pitcher happened to face.
score_both_sides <- function(model, df, inputs = INPUTS) {
  same <- df |> mutate(same_side = 1L)
  opp  <- df |> mutate(same_side = 0L)
  df |>
    mutate(pred_same = predict(model, xgb.DMatrix(to_matrix(same, inputs))),
           pred_opp  = predict(model, xgb.DMatrix(to_matrix(opp, inputs))),
           pred      = (pred_same + pred_opp) / 2)
}

# ---- Family models, a rejected development experiment ----
# The label only routes a pitch to a model; each model still sees shape only
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

# ---- v2: whiff target ----
# Swings only, label 1 = whiff. min_child_weight counts p(1 - p) under logistic
# loss (~0.2 per pitch), so 100 means roughly 500 swings a leaf.
fit_whiff <- function(train, inputs = INPUTS) {
  set.seed(3)
  sw <- train |> filter(description %in% SWING_DESC)
  dtrain <- xgb.DMatrix(to_matrix(sw, inputs), label = as.integer(sw$description %in% WHIFF_DESC))
  xgb.train(params = modifyList(PARAMS, list(objective = "binary:logistic")),
            data = dtrain, nrounds = N_ROUNDS, verbose = 0)
}

# cv.R
# Model-ready pitches and the out-of-fold loop.

library(tidyverse)
source("R/features.R")
source("R/target.R")
source("R/model.R")

KEEP <- c("pitcher", "player_name", "game_year", "game_date", "pitch_type", "p_throws", "stand",
          "balls", "strikes", "outcome", "fold", "zone", "description", INPUTS, "ivb_gap", "hb_gap", "release_spin_rate", "axis_diff")

# Pitch-level or pitcher-season steps; none needs a fold
prep_pitches <- function(path = "data/pitches_clean.rds") {
  p <- readRDS(path) |>
    add_shape() |>
    add_velo_gap() |>
    add_axis_diff() |>
    mutate(outcome = outcome(events, description)) |>
    filter(!is.na(outcome))
  p |> left_join(assign_folds(p), by = "pitcher") |>
    select(all_of(KEEP), delta_run_exp)
}

# Train on four folds, score the fifth. The run-value table is rebuilt inside the loop.
run_cv <- function(p, fit = fit_model, score = score_both_sides) {
  map(1:5, function(k) {
    train <- p |> filter(fold != k)
    held  <- p |> filter(fold == k)
    tab   <- rv_table(train)
    value <- function(d) left_join(d, tab, by = c("outcome", "balls", "strikes"))
    model <- fit(value(train))
    message("fold ", k, " fit on ", format(nrow(train), big.mark = ","), " pitches")
    score(model, value(held)) |> select(-delta_run_exp)
  }) |>
    list_rbind()
}

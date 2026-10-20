library(tidyverse)
source("R/features.R")
source("R/target.R")
source("R/model.R")

KEEP <- c("pitcher", "player_name", "game_year", "pitch_type", "p_throws", "stand",
          "balls", "strikes", "outcome", "fold", "zone", INPUTS, "ivb_gap", "hb_gap")

# Clean pitches to model-ready rows. Every step is pitch-level or uses the
# pitcher's own season, so nothing here needs a fold
prep_pitches <- function(path = "data/pitches_clean.rds") {
  p <- readRDS(path) |>
    add_shape() |>
    add_velo_gap() |>
    mutate(outcome = outcome(events, description)) |>
    filter(!is.na(outcome))
  p |> left_join(assign_folds(p), by = "pitcher") |>
    select(all_of(KEEP), delta_run_exp)
}

# Train on four folds, score the fifth, five times. The run-value table is
# rebuilt from training pitchers inside the loop, and the held-out pitches are
# valued with THAT table, so neither the model nor the answer key ever saw them
# `fit` and `score` default to the pre-registered model; the linear baseline
# and the depth-6 check pass their own, so all three share one fold loop
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

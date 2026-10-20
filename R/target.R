library(tidyverse)

OUT_EVENTS  <- c("field_out", "force_out", "grounded_into_double_play",
                 "double_play", "triple_play", "fielders_choice",
                 "fielders_choice_out", "sac_fly", "sac_fly_double_play",
                 "field_error")   # an error is contact a fielder should turn into an out
DROP_EVENTS <- c("sac_bunt", "catcher_interf", "truncated_pa")
WHIFF_DESC  <- c("swinging_strike", "swinging_strike_blocked", "foul_tip")
BALL_DESC   <- c("ball", "blocked_ball")

# What the pitch did. Terminal events first: a whiff on strike three is a
# strikeout, worth more than strike one. NA means "not a pitch outcome" and the
# row is dropped
outcome <- function(events, description) {
  case_when(
    events %in% DROP_EVENTS                                ~ NA_character_,
    events %in% c("strikeout", "strikeout_double_play")    ~ "strikeout",
    events %in% c("walk", "hit_by_pitch")                  ~ events,
    events %in% c("single", "double", "triple", "home_run") ~ events,
    events %in% OUT_EVENTS                                 ~ "field_out",
    description %in% WHIFF_DESC                            ~ "whiff",
    description == "foul"                                  ~ "foul",
    description == "called_strike"                         ~ "called_strike",
    description %in% BALL_DESC                             ~ "ball",
    TRUE                                                   ~ NA_character_
  )
}

# League value of each outcome in each count, from TRAINING pitchers only.
# Thin cells (under 50) fall back to the outcome's value across all counts.
# Sign flipped so a good pitch for the pitcher is positive
rv_table <- function(train, min_cell = 50) {
  by_outcome <- train |> summarise(rv_all = mean(delta_run_exp), .by = outcome)
  train |>
    summarise(rv_cell = mean(delta_run_exp), n_cell = n(),
              .by = c(outcome, balls, strikes)) |>
    left_join(by_outcome, by = "outcome") |>
    transmute(outcome, balls, strikes,
              rv = -if_else(n_cell >= min_cell, rv_cell, rv_all))
}

# Every pitcher in exactly one fold, across all his seasons
assign_folds <- function(df, k = 5, seed = 3) {
  set.seed(seed)
  ids <- sort(unique(df$pitcher))
  tibble(pitcher = ids, fold = sample(rep_len(1:k, length(ids))))
}

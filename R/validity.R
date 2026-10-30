# validity.R
# v2's main validity test: within pitch type, does the grade track whiff per swing?

library(tidyverse)
source("R/target.R")

GRADED_TYPES <- c("FF", "SI", "FC", "SL", "ST", "CU", "CH", "FS")

# One row per pitcher, season and pitch type with min_n+ pitches
pitch_outcomes <- function(oof, min_n = 250) {
  oof |>
    summarise(n = n(), grade = mean(pred), swings = sum(description %in% SWING_DESC),
              whiff = sum(description %in% WHIFF_DESC) / swings,
              rv_swing = mean(rv[description %in% SWING_DESC]),
              .by = c(pitcher, player_name, game_year, pitch_type)) |>
    filter(n >= min_n)
}

# Both columns centered within pitch type and season, so neither "sweepers whiff
# more" nor a high-whiff league year counts
within_r <- function(d, x, y) {
  d |> filter(!is.na({{ x }}), !is.na({{ y }})) |>
    mutate(across(c({{ x }}, {{ y }}), \(v) v - mean(v)), .by = c(pitch_type, game_year)) |>
    summarise(r = cor({{ x }}, {{ y }})) |> pull(r)
}

# Pooled within-type r, plus each pitch type on its own (not centered by season)
validity <- function(po, score = grade) {
  po <- po |> filter(pitch_type %in% GRADED_TYPES)
  list(whiff    = within_r(po, {{ score }}, whiff),
       rv_swing = within_r(po, {{ score }}, rv_swing),
       by_type  = po |> filter(!is.na({{ score }})) |>
         summarise(r_whiff = cor({{ score }}, whiff), rows = n(), .by = pitch_type))
}

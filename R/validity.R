library(tidyverse)

# v2's descriptive bars (DECISIONS.md 2026-10-20). Whiff per swing is the main
# validity outcome: once a hitter swings, missing the bat is mostly shape
SWING <- c("swinging_strike", "swinging_strike_blocked", "foul_tip", "foul", "hit_into_play")
WHIFF <- c("swinging_strike", "swinging_strike_blocked", "foul_tip")
VALID_TYPES <- c("FF", "SI", "FC", "SL", "ST", "CU", "CH", "FS")

# One row per pitcher x season x pitch type with 250+ pitches
pitch_outcomes <- function(oof, min_n = 250) {
  oof |>
    summarise(n = n(), grade = mean(pred), swings = sum(description %in% SWING),
              whiff = sum(description %in% WHIFF) / swings,
              rv_swing = mean(rv[description %in% SWING]),
              .by = c(pitcher, player_name, game_year, pitch_type)) |>
    filter(n >= min_n)
}

# Correlation after centering both columns within pitch type AND season, so
# neither "sweepers whiff more" nor a high-whiff league year counts
within_r <- function(d, x, y) {
  d |> filter(!is.na({{ x }}), !is.na({{ y }})) |>
    mutate(across(c({{ x }}, {{ y }}), \(v) v - mean(v)), .by = c(pitch_type, game_year)) |>
    summarise(r = cor({{ x }}, {{ y }})) |> pull(r)
}

# Pooled within-type validity, plus each type on its own
validity <- function(po, score = grade) {
  po <- po |> filter(pitch_type %in% VALID_TYPES)
  list(whiff    = within_r(po, {{ score }}, whiff),
       rv_swing = within_r(po, {{ score }}, rv_swing),
       by_type  = po |> filter(!is.na({{ score }})) |>
         summarise(r_whiff = cor({{ score }}, whiff), rows = n(), .by = pitch_type))
}

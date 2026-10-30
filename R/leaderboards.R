# leaderboards.R
# The board the exam wrote (one league-wide scale, as it ran) and the FanGraphs comparison.

library(tidyverse)

# FanGraphs exports aren't redistributed; comparisons skip when these are absent
FG_2025 <- "data/external/fg_stuff_2025-03-18_2025-09-30.csv"
FG_2026 <- "data/external/fg_stuff_2026-03-26_2026-08-17.csv"

season_board <- function(oof, mu, sigma, year, min_n = 250) {
  to100 <- \(x) round(100 + 10 * (x - mu) / sigma)
  oof |>
    filter(game_year == year) |>
    summarise(n = n(), grade = mean(pred),
              vs_rhh = mean(if (first(p_throws) == "R") pred_same else pred_opp),
              vs_lhh = mean(if (first(p_throws) == "L") pred_same else pred_opp),
              velo = mean(release_speed), ivb = mean(ivb), hb = mean(hb),
              rel_ht = mean(release_ht), rel_side = mean(release_side),
              velo_gap = mean(velo_gap),
              .by = c(pitcher, player_name, p_throws, pitch_type)) |>
    filter(n >= min_n) |>
    mutate(stuff_plus = to100(grade), vs_rhh = to100(vs_rhh), vs_lhh = to100(vs_lhh),
           across(c(velo, ivb, hb, velo_gap), \(x) round(x, 1)),
           across(c(rel_ht, rel_side), \(x) round(x, 2))) |>
    select(pitcher, player_name, p_throws, pitch_type, stuff_plus, vs_rhh, vs_lhh, n,
           velo, ivb, hb, rel_ht, rel_side, velo_gap) |>
    arrange(pitch_type, -stuff_plus)
}

# FanGraphs has no sweeper column: its SL covers SL and ST, so both compare to it. FA = FF.
add_fangraphs <- function(board, fg_path) {
  fg <- read_csv(fg_path, show_col_types = FALSE) |>
    select(pitcher = MLBAMID, starts_with("Stf+ ")) |>
    pivot_longer(-pitcher, names_to = "fg_type", values_to = "fg_stuff",
                 names_prefix = "Stf\\+ ", values_drop_na = TRUE) |>
    mutate(fg_type = if_else(fg_type == "FA", "FF", fg_type))
  board |>
    mutate(fg_type = if_else(pitch_type == "ST", "SL", pitch_type)) |>
    left_join(fg, by = c("pitcher", "fg_type")) |>
    mutate(fg_rank  = min_rank(-fg_stuff),
           our_rank = if ("stuff_plus" %in% names(board)) min_rank(-stuff_plus) else NA_integer_,
           .by = pitch_type)
}

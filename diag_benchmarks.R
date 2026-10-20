# Dev-only diagnostic: how do ours, FanGraphs and tjStuff+ describe whiff per
# swing in the same season and in an adjacent season? Never reads 2026
suppressMessages({ library(tidyverse); source("R/validity.R"); source("R/leaderboards.R") })
fg_path <- "/Users/jonathanmerlin/Desktop/Baseball Questionnaires/06_Data/savant_leaderboards/fg_stuff_2025-03-18_2025-09-30.csv"
tj_path <- "/Users/jonathanmerlin/Desktop/Baseball Questionnaires/06_Data/savant_leaderboards/tjstuff_2024_grades.csv"

whiffs <- readRDS("data/pitches_clean.rds") |>
  summarise(n = n(), swings = sum(description %in% SWING),
            whiff = sum(description %in% WHIFF) / swings, .by = c(pitcher, game_year, pitch_type)) |>
  filter(n >= 250)
ours <- readRDS("outputs/shot/oof.rds") |>
  summarise(n_g = n(), grade = mean(pred), .by = c(pitcher, game_year, pitch_type)) |> filter(n_g >= 250)
tj <- read_csv(tj_path, show_col_types = FALSE) |> filter(pitch_type != "All") |>
  transmute(pitcher = pitcher_id, pitch_type, tj = tj_stuff_plus)
fg <- read_csv(fg_path, show_col_types = FALSE) |> select(pitcher = MLBAMID, starts_with("Stf+ ")) |>
  pivot_longer(-pitcher, names_to = "fg_type", values_to = "fg", names_prefix = "Stf\\+ ", values_drop_na = TRUE) |>
  mutate(fg_type = if_else(fg_type == "FA", "FF", fg_type))

# Grade year g, whiff year w, ours against the public model for that year
compare <- function(g, w, label) {
  d <- ours |> filter(game_year == g) |> select(pitcher, pitch_type, grade) |>
    inner_join(whiffs |> filter(game_year == w), by = c("pitcher", "pitch_type")) |>
    filter(pitch_type %in% VALID_TYPES)
  if (g == 2024) d <- d |> inner_join(tj, by = c("pitcher", "pitch_type"))
  if (g == 2025) d <- d |> mutate(fg_type = if_else(pitch_type == "ST", "SL", pitch_type)) |>
    inner_join(fg, by = c("pitcher", "fg_type"))
  other <- if (g == 2024) "tj" else "fg"
  cat(sprintf("%-42s rows %4d   ours %.3f   %s %.3f\n", label, nrow(d),
              within_r(d, grade, whiff), if (g == 2024) "tjStuff+ " else "FanGraphs",
              within_r(d, .data[[other]], whiff)))
}
compare(2025, 2025, "2025 grades vs 2025 whiffs (same season)")
compare(2025, 2024, "2025 grades vs 2024 whiffs (out of time)")
compare(2024, 2024, "2024 grades vs 2024 whiffs (same season)")
compare(2024, 2025, "2024 grades vs 2025 whiffs (out of time)")

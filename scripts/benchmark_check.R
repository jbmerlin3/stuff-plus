# benchmark_check.R
# Development only, never reads 2026: ours against two public Stuff+ models on the same
# pitches, in the same and an adjacent season. Needs data/external/ and outputs/v1_full/oof.rds.
#   Rscript scripts/benchmark_check.R

suppressMessages({ library(tidyverse); source("R/validity.R"); source("R/leaderboards.R") })
benchmark_path <- "data/external/public_benchmark_2024.csv"

whiffs <- readRDS("data/pitches_clean.rds") |>
  summarise(n = n(), swings = sum(description %in% SWING_DESC),
            whiff = sum(description %in% WHIFF_DESC) / swings, .by = c(pitcher, game_year, pitch_type)) |>
  filter(n >= 250)
ours <- readRDS("outputs/v1_full/oof.rds") |>
  summarise(n_g = n(), grade = mean(pred), .by = c(pitcher, game_year, pitch_type)) |> filter(n_g >= 250)
pub <- read_csv(benchmark_path, show_col_types = FALSE) |> filter(pitch_type != "All") |>
  transmute(pitcher = pitcher_id, pitch_type, pub = tj_stuff_plus)
fg <- read_csv(FG_2025, show_col_types = FALSE) |> select(pitcher = MLBAMID, starts_with("Stf+ ")) |>
  pivot_longer(-pitcher, names_to = "fg_type", values_to = "fg", names_prefix = "Stf\\+ ", values_drop_na = TRUE) |>
  mutate(fg_type = if_else(fg_type == "FA", "FF", fg_type))

# Grade year g against whiff year w, ours and the public model for that year
compare <- function(g, w, label) {
  d <- ours |> filter(game_year == g) |> select(pitcher, pitch_type, grade) |>
    inner_join(whiffs |> filter(game_year == w), by = c("pitcher", "pitch_type")) |>
    filter(pitch_type %in% GRADED_TYPES)
  if (g == 2024) d <- d |> inner_join(pub, by = c("pitcher", "pitch_type"))
  if (g == 2025) d <- d |> mutate(fg_type = if_else(pitch_type == "ST", "SL", pitch_type)) |>
    inner_join(fg, by = c("pitcher", "fg_type"))
  other <- if (g == 2024) "pub" else "fg"
  cat(sprintf("%-42s rows %4d   ours %.3f   %s %.3f\n", label, nrow(d),
              within_r(d, grade, whiff), if (g == 2024) "benchmark" else "FanGraphs",
              within_r(d, .data[[other]], whiff)))
}
compare(2025, 2025, "2025 grades vs 2025 whiffs (same season)")
compare(2025, 2024, "2025 grades vs 2024 whiffs (out of time)")
compare(2024, 2024, "2024 grades vs 2024 whiffs (same season)")
compare(2024, 2025, "2024 grades vs 2025 whiffs (out of time)")

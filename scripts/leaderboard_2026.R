# leaderboard_2026.R
# 2026 grades on the group scale, as the app shows them, with the inputs and actual whiffs.
# Run after export_v2.R.
#   Rscript scripts/leaderboard_2026.R

suppressMessages({ library(tidyverse); source("R/scale.R"); source("R/target.R") })
sc    <- readRDS("outputs/scored_2026.rds")
scale <- read_csv("models/stuff_v2_scale.csv", show_col_types = FALSE)

board <- sc |>
  summarise(n = n(), g = mean(pred),
            gR = mean(if (first(p_throws) == "R") pred_same else pred_opp),
            gL = mean(if (first(p_throws) == "L") pred_same else pred_opp),
            whiff_pct = 100 * sum(description %in% WHIFF_DESC) / sum(description %in% SWING_DESC),
            velo = mean(release_speed), ivb = mean(ivb), hb = mean(hb),
            release_ht = mean(release_ht), velo_gap = mean(velo_gap),
            axis_diff = mean(axis_diff, na.rm = TRUE),
            .by = c(pitcher, player_name, p_throws, pitch_type)) |>
  filter(n >= 50) |>
  mutate(group = stuff_group(pitch_type)) |>
  inner_join(scale |> select(group, mu, sigma), by = "group") |>
  mutate(stuff_plus = to_stuff_plus(g, mu, sigma), vs_rhh = to_stuff_plus(gR, mu, sigma),
         vs_lhh = to_stuff_plus(gL, mu, sigma),
         across(c(whiff_pct, velo, ivb, hb, velo_gap), \(x) round(x, 1)),
         release_ht = round(release_ht, 2), axis_diff = round(axis_diff)) |>
  select(pitcher, player_name, p_throws, pitch_type, group, stuff_plus, vs_rhh, vs_lhh, n,
         whiff_pct, velo, ivb, hb, release_ht, velo_gap, axis_diff) |>
  arrange(group, -stuff_plus)

write_csv(board, "results/leaderboard_2026.csv")
cat(nrow(board), "rows\n")
print(as.data.frame(board |> filter(n >= 250) |> slice_max(stuff_plus, n = 3, with_ties = FALSE, by = pitch_type) |>
                      select(pitch_type, player_name, stuff_plus, n, whiff_pct, velo)))
